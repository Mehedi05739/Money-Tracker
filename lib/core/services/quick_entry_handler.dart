import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/local/daos/account_dao.dart';
import '../../data/local/daos/settings_dao.dart';
import '../../data/local/daos/transaction_dao.dart';
import '../../domain/entities/money_transaction.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';
import '../enums/transaction_type.dart';
import '../utils/logger.dart';
import 'daily_reminder.dart';
import 'notification_service.dart';

/// Records an expense typed into the daily reminder's reply box.
///
/// Runs in a **background isolate**, spawned by the notification plugin when
/// the app is not in the foreground. Nothing from the running app is reachable
/// here — no GetX bindings, no open database — so this opens its own connection
/// and closes it again. Everything it needs is read from the database rather
/// than passed in.
///
/// It still goes through [TransactionDao], not raw SQL: the account balance
/// must move by exactly the same rule as every other write, and duplicating
/// that here is how the two would drift apart.
class QuickEntryHandler {
  const QuickEntryHandler._();

  /// Notification shown after a reply, replacing the reminder.
  static const int _confirmationId = 901;

  /// Handles one reply. Returns whether an expense was recorded.
  ///
  /// Never throws: this runs where there is no UI to report a failure to, and
  /// an uncaught error in a background isolate is invisible to the user.
  static Future<bool> record(NotificationResponse response) async {
    if (response.actionId != NotificationService.logExpenseActionId) {
      return false;
    }

    final amount = QuickAmount.parse(response.input ?? response.payload);

    final plugin = FlutterLocalNotificationsPlugin();
    if (amount == null) {
      await _notify(
        plugin,
        'That amount was not clear',
        'Open Money Tracker to add it — nothing was recorded.',
      );
      return false;
    }

    AppDatabase? database;
    try {
      // Plugins are not registered in a fresh isolate until this is called.
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();

      database = AppDatabase(fileName: AppConstants.databaseFile);
      await database.open();

      final settings = SettingsDao(database.db);
      final accounts = AccountDao(database.db);

      final accountId = await _resolveAccount(settings, accounts);
      if (accountId == null) {
        await _notify(
          plugin,
          'No account to record against',
          'Open Money Tracker and add an account first.',
        );
        return false;
      }

      final categoryId = int.tryParse(
        await settings.find(SettingKeys.defaultCategoryId) ?? '',
      );

      final now = DateTime.now();
      await TransactionDao(database.db).insert(
        MoneyTransaction(
          id: 0,
          accountId: accountId,
          type: TransactionType.expense,
          amount: amount,
          categoryId: categoryId,
          title: 'Quick entry',
          transactionDate: now,
          note: 'Added from the daily reminder',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Confirms without printing the figure: this lands on a lock screen.
      await _notify(
        plugin,
        'Expense recorded',
        'Open Money Tracker to add a category or edit it.',
      );
      return true;
    } catch (error) {
      // Log the shape only — never the amount.
      AppLogger.w(
        'Quick entry failed: ${error.runtimeType}',
        name: 'QUICKENTRY',
      );
      await _notify(
        plugin,
        'That could not be saved',
        'Open Money Tracker to add it.',
      );
      return false;
    } finally {
      await database?.close();
    }
  }

  /// The account to record against: the user's chosen default, or the first
  /// account they have. A quick entry should not fail because no default was
  /// ever set.
  static Future<int?> _resolveAccount(
    SettingsDao settings,
    AccountDao accounts,
  ) async {
    final preferred = int.tryParse(
      await settings.find(SettingKeys.defaultAccountId) ?? '',
    );
    if (preferred != null && await accounts.findById(preferred) != null) {
      return preferred;
    }

    final all = await accounts.findAll();
    return all.isEmpty ? null : all.first.id;
  }

  static Future<void> _notify(
    FlutterLocalNotificationsPlugin plugin,
    String title,
    String body,
  ) async {
    try {
      await plugin.show(
        _confirmationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'money_tracker_daily',
            'Daily reminder',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // A confirmation that cannot be shown must not undo a saved expense.
    }
  }
}

/// The entry point the notification plugin calls in the background isolate.
///
/// Must be top-level and marked as an entry point, or tree-shaking removes it
/// from a release build and replies silently do nothing.
@pragma('vm:entry-point')
Future<void> onNotificationReplyBackground(NotificationResponse response) =>
    QuickEntryHandler.record(response);

/// The same handling for a reply that arrives while the app is running.
///
/// The plugin routes to the foreground callback when the process is alive, so
/// without this a reply typed with the app open would do nothing at all.
@pragma('vm:entry-point')
Future<void> onNotificationReplyForeground(NotificationResponse response) =>
    QuickEntryHandler.record(response);
