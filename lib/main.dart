import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app.dart';
import 'core/errors/exceptions.dart';
import 'core/events/app_events.dart';
import 'core/utils/logger.dart';
import 'core/widgets/app_snackbar.dart';
import 'di/dependency_injection.dart';
import 'domain/services/recurring_service.dart';
import 'features/startup/presentation/pages/startup_failure_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _startApp();
}

/// Boots the app, or shows a recoverable failure screen.
///
/// Everything depends on the database opening, so a failure here used to leave
/// a blank window with the reason only in the logs. Now the user is told what
/// happened and can retry — a transient I/O error should not need a reinstall.
Future<bool> _startApp() async {
  try {
    await DependencyInjection.init();
  } catch (error, stackTrace) {
    // Log the shape of the failure, never the data behind it.
    AppLogger.e(
      'Startup failed',
      error: error is AppException ? error.toString() : error.runtimeType,
      stackTrace: stackTrace,
    );
    runApp(StartupFailureApp(message: _messageFor(error), onRetry: _startApp));
    return false;
  }

  runApp(const MoneyTrackerApp());

  // Catch up on recurring transactions after the first frame, so startup is
  // not blocked by a schedule with a lot of occurrences to post.
  WidgetsBinding.instance.addPostFrameCallback((_) => _postRecurringDue());
  return true;
}

String _messageFor(Object error) => switch (error) {
  DatabaseDowngradeException(:final message) => message,
  AppException(:final message) => message,
  _ => 'Something went wrong while opening the app.',
};

Future<void> _postRecurringDue() async {
  try {
    final report = await Get.find<RecurringService>().runDue();
    if (!report.hasChanges) return;

    // Screens built during startup are already showing pre-catch-up figures.
    Get.find<AppEvents>().emit(DataChange.transactions);
    AppSnackbar.info(report.summary);
  } catch (error, stackTrace) {
    // Never let a scheduling problem stop the app from being usable.
    AppLogger.e(
      'Recurring catch-up failed',
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }
}
