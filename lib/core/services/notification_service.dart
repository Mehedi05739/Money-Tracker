import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../utils/logger.dart';

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

  Future<void> init() async {
    try {
      final initialised = await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
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

  /// Asks for permission, returning whether it was granted.
  ///
  /// Called when the user turns a reminder on, not at startup: a permission
  /// prompt before the user has asked for anything is the fastest way to have
  /// it refused.
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        return granted ?? false;
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final granted = await ios.requestPermissions(alert: true, sound: true);
        return granted ?? false;
      }
      return _ready;
    } catch (error) {
      AppLogger.w(
        'Permission request failed: ${error.runtimeType}',
        name: 'NOTIFY',
      );
      return false;
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
