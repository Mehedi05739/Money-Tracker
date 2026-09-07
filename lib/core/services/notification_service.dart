import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../utils/logger.dart';
import 'daily_reminder.dart';

/// The reminders the app can raise.
///
/// Each maps to a settings toggle and to a fixed notification id, so
/// re-scheduling replaces the previous one rather than stacking duplicates.
enum ReminderKind {
  budget(id: 100, title: 'Budget check'),
  plan(id: 200, title: 'Spending plan'),
  goal(id: 300, title: 'Savings goal'),
  recurring(id: 400, title: 'Scheduled payment');

  const ReminderKind({required this.id, required this.title});

  final int id;
  final String title;
}

/// Local notifications for budget, plan, goal and recurring reminders.
///
/// Local only, like everything else here: nothing is scheduled on a server and
/// no financial figures leave the device. Notification bodies deliberately
/// carry no amounts — a lock screen is a public surface, and "You are close to
/// your Groceries budget" tells the user what they need without printing their
/// finances to anyone glancing at the phone.
class NotificationService {
  NotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  bool _ready = false;

  /// True once the platform accepted initialisation *and* the user granted
  /// permission. Every scheduling call is a no-op until then, so a refused
  /// permission degrades quietly instead of throwing into the UI.
  bool get isReady => _ready;

  static const AndroidNotificationDetails _android = AndroidNotificationDetails(
    'money_tracker_reminders',
    'Reminders',
    channelDescription: 'Budget, plan, goal and scheduled payment reminders',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  static const NotificationDetails _details = NotificationDetails(
    android: _android,
    iOS: DarwinNotificationDetails(),
  );

  /// Identifiers for the daily reminder and its reply action.
  ///
  /// A fixed id so re-scheduling replaces the pending reminder rather than
  /// leaving yesterday's queued alongside today's.
  static const int dailyReminderId = 900;
  static const String logExpenseActionId = 'log_expense';
  static const String amountInputKey = 'amount';

  Future<void> init({
    DidReceiveBackgroundNotificationResponseCallback? onBackgroundResponse,
    DidReceiveNotificationResponseCallback? onForegroundResponse,
  }) async {
    try {
      // Scheduling needs a real zone, or a "10pm" reminder fires at 10pm UTC.
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(
          tz.getLocation(await FlutterTimezone.getLocalTimezone()),
        );
      } catch (error) {
        // An unknown zone name should degrade to UTC, not stop notifications.
        AppLogger.w(
          'Falling back to UTC: ${error.runtimeType}',
          name: 'NOTIFY',
        );
      }

      final initialised = await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: onForegroundResponse,
        onDidReceiveBackgroundNotificationResponse: onBackgroundResponse,
      );
      _ready = initialised ?? false;
    } catch (error) {
      // A device without notification support must not stop the app opening.
      AppLogger.w(
        'Notifications unavailable: ${error.runtimeType}',
        name: 'NOTIFY',
      );
      _ready = false;
    }
  }

  /// Whether the OS currently lets this app post notifications.
  ///
  /// Read separately from requesting, because asking again once permission is
  /// already held is what broke the settings toggle: the plugin refuses a
  /// second request while one is "in progress" and that state is only cleared
  /// by a result callback, so a request that never resolved left every later
  /// attempt failing until the app restarted.
  Future<bool> hasPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? false;
      }
      // iOS has no equivalent read, so treat initialisation as the signal and
      // let the request itself be the check.
      return true;
    } catch (error) {
      AppLogger.w(
        'Could not read permission state: ${error.runtimeType}',
        name: 'NOTIFY',
      );
      return false;
    }
  }

  /// Makes sure notifications are permitted, asking only if they are not.
  ///
  /// If a request is rejected because one is already in flight, the permission
  /// state is re-read rather than reported as a refusal — the user may well
  /// have granted it, and telling them it failed when it did not is how the
  /// toggle got stuck.
  Future<bool> ensurePermission() async {
    if (!_ready) return false;
    if (await hasPermission()) return true;

    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted ?? false) return true;
        // A `false` here can also mean the dialog was dismissed by a rebuild
        // rather than declined, so confirm against the real state.
        return await hasPermission();
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      return _ready;
    } catch (error) {
      AppLogger.w(
        'Permission request failed: ${error.runtimeType}',
        name: 'NOTIFY',
      );
      // Most likely "another request is already in progress". The state itself
      // is the truth.
      return hasPermission();
    }
  }

  /// Whether the OS will let this app post an alarm at an exact minute.
  Future<bool> canScheduleExactly() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return true; // iOS schedules exactly.
      return await android.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Schedules the daily "record today's spending" reminder.
  ///
  /// Repeats every day at [time] via `DateTimeComponents.time`, so it survives
  /// without the app running. Deliberately **inexact**: an exact alarm needs
  /// `SCHEDULE_EXACT_ALARM`, which Android treats as a high-privilege
  /// permission, and a nudge to log expenses does not need to land on the
  /// second.
  Future<bool> scheduleDailyReminder(ReminderTime time) async {
    if (!_ready) return false;

    final exact = await canScheduleExactly();

    try {
      await _plugin.zonedSchedule(
        dailyReminderId,
        'Record today’s spending',
        'Tap to add an expense, or reply with just the amount.',
        tz.TZDateTime.from(time.nextOccurrence(), tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'money_tracker_daily',
            'Daily reminder',
            channelDescription: 'A daily nudge to record the day’s spending',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            actions: const <AndroidNotificationAction>[
              // Free-form input turns the notification itself into the fastest
              // way to record a figure — no app launch, no form.
              AndroidNotificationAction(
                logExpenseActionId,
                'Add expense',
                allowGeneratedReplies: false,
                inputs: <AndroidNotificationActionInput>[
                  AndroidNotificationActionInput(label: 'Amount'),
                ],
                // The reply is handled without bringing the app forward.
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
            categoryIdentifier: 'daily_reminder',
          ),
        ),
        // Exact when the OS allows it, because a reminder set for 10pm that
        // arrives at 10:40 is not the feature the user asked for. Inexact
        // alarms are batched and deferred by Doze, which is why the reminder
        // appeared minutes late or not at all. Falls back rather than failing:
        // Android 14 withholds exact alarms from most apps, and a late
        // reminder still beats none.
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        // The stored time is a wall clock, so it should mean 10pm wherever the
        // user is, not a fixed instant computed once.
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      return true;
    } catch (error) {
      AppLogger.w(
        'Could not schedule the daily reminder: ${error.runtimeType}',
        name: 'NOTIFY',
      );
      return false;
    }
  }

  Future<void> cancelDailyReminder() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(dailyReminderId);
    } catch (error) {
      AppLogger.w(
        'Could not cancel reminder: ${error.runtimeType}',
        name: 'NOTIFY',
      );
    }
  }

  /// Shows a reminder now.
  ///
  /// [body] must never contain an amount — see the class comment.
  Future<void> show(ReminderKind kind, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(kind.id, kind.title, body, _details);
    } catch (error) {
      AppLogger.w(
        'Could not show reminder: ${error.runtimeType}',
        name: 'NOTIFY',
      );
    }
  }

  /// Withdraws a reminder the user has turned off.
  Future<void> cancel(ReminderKind kind) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(kind.id);
    } catch (error) {
      AppLogger.w(
        'Could not cancel reminder: ${error.runtimeType}',
        name: 'NOTIFY',
      );
    }
  }

  Future<void> cancelAll() async {
    for (final kind in ReminderKind.values) {
      await cancel(kind);
    }
  }
}
