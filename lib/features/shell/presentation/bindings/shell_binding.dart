import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/dashboard_repository.dart';
import '../../../../domain/repositories/spending_plan_repository.dart';
import '../../../../domain/repositories/transaction_repository.dart';
import '../../../dashboard/presentation/controllers/dashboard_controller.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../../../plans/presentation/controllers/plans_controller.dart';
import '../../../reports/presentation/controllers/reports_controller.dart';
import '../../../transactions/presentation/controllers/transactions_controller.dart';
import '../controllers/shell_controller.dart';

/// Wires the shell and its four tab controllers.
///
/// `fenix: true` matters here: the shell keeps tab bodies alive, so a
/// controller GetX disposes during a deep back-navigation has to be able to
/// come back when its tab is shown again.
class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellController.new);

    Get.lazyPut(
      () => DashboardController(
        Get.find<DashboardRepository>(),
        Get.find<AppEvents>(),
        Get.find<SettingsController>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => TransactionsController(
        Get.find<TransactionRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<AccountRepository>(),
        Get.find<AppEvents>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => PlansController(
        Get.find<SpendingPlanRepository>(),
        Get.find<AppEvents>(),
      ),
      fenix: true,
    );
    Get.lazyPut(
      () => ReportsController(
        Get.find<AnalyticsRepository>(),
        Get.find<AppEvents>(),
      ),
      fenix: true,
    );
  }
}
