import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app.dart';
import 'core/events/app_events.dart';
import 'core/utils/logger.dart';
import 'core/widgets/app_snackbar.dart';
import 'di/dependency_injection.dart';
import 'domain/services/recurring_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DependencyInjection.init();
  runApp(const MoneyTrackerApp());

  // Catch up on recurring transactions after the first frame, so startup is
  // not blocked by a schedule that has a lot of occurrences to post.
  WidgetsBinding.instance.addPostFrameCallback((_) => _postRecurringDue());
}

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
      error: error,
      stackTrace: stackTrace,
    );
  }
}
