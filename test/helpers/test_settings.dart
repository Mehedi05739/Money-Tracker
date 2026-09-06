import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/events/app_events.dart';
import 'package:money_tracker/core/services/app_lock_service.dart';
import 'package:money_tracker/core/services/currency_formatter.dart';
import 'package:money_tracker/core/services/notification_service.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/category_dao.dart';
import 'package:money_tracker/data/local/daos/settings_dao.dart';
import 'package:money_tracker/data/repositories/account_repository_impl.dart';
import 'package:money_tracker/data/repositories/category_repository_impl.dart';
import 'package:money_tracker/data/repositories/settings_repository_impl.dart';
import 'package:money_tracker/domain/services/data_transfer_service.dart';
import 'package:money_tracker/features/settings/presentation/controllers/settings_controller.dart';

/// Builds a loaded [SettingsController] against a test database.
///
/// Kept in one place so a constructor change touches a single file rather than
/// every test that needs settings. The lock and notification services are
/// plugin-backed and inert under test — nothing here calls them.
Future<SettingsController> buildSettingsController(AppDatabase database) async {
  final controller = SettingsController(
    SettingsRepositoryImpl(SettingsDao(database.db)),
    AccountRepositoryImpl(AccountDao(database.db)),
    CategoryRepositoryImpl(CategoryDao(database.db)),
    CurrencyFormatter(),
    AppLockService(LocalAuthentication()),
    NotificationService(FlutterLocalNotificationsPlugin()),
    DataTransferService(database),
    AppEvents(),
  );
  await controller.load();
  return controller;
}
