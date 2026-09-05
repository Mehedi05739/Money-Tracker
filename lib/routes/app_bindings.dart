import 'package:get/get.dart';

import '../core/events/app_events.dart';
import '../domain/repositories/account_repository.dart';
import '../domain/repositories/analytics_repository.dart';
import '../domain/repositories/budget_repository.dart';
import '../domain/repositories/category_repository.dart';
import '../domain/repositories/goal_repository.dart';
import '../domain/repositories/recurring_repository.dart';
import '../domain/repositories/spending_plan_repository.dart';
import '../domain/repositories/transaction_repository.dart';
import '../domain/services/recurring_service.dart';
import '../features/accounts/presentation/controllers/account_form_controller.dart';
import '../features/accounts/presentation/controllers/accounts_controller.dart';
import '../features/budgets/presentation/controllers/budget_form_controller.dart';
import '../features/budgets/presentation/controllers/budgets_controller.dart';
import '../features/categories/presentation/controllers/categories_controller.dart';
import '../features/categories/presentation/controllers/category_form_controller.dart';
import '../features/dashboard/presentation/controllers/dashboard_controller.dart';
import '../features/goals/presentation/controllers/goal_detail_controller.dart';
import '../features/goals/presentation/controllers/goal_form_controller.dart';
import '../features/goals/presentation/controllers/goals_controller.dart';
import '../features/plans/presentation/controllers/plan_detail_controller.dart';
import '../features/plans/presentation/controllers/plan_form_controller.dart';
import '../features/plans/presentation/controllers/plans_controller.dart';
import '../features/recurring/presentation/controllers/recurring_controller.dart';
import '../features/recurring/presentation/controllers/recurring_form_controller.dart';
import '../features/reports/presentation/controllers/reports_controller.dart';
import '../features/settings/presentation/controllers/settings_controller.dart';
import '../features/shell/presentation/controllers/shell_controller.dart';
import '../features/transactions/presentation/controllers/transaction_form_controller.dart';
import '../features/transactions/presentation/controllers/transactions_controller.dart';

/// Feature bindings.
///
/// Repositories are already registered globally, so a binding only wires the
/// controllers a route needs. `lazyPut` keeps a controller from being built
/// until its page actually requests it, and `fenix` lets a tab's controller be
/// recreated after Get disposes it on a deep back-navigation.
class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellController.new);

    // The five tab controllers. `fenix` matters here: the shell keeps tab
    // bodies alive, so a controller disposed during navigation must be able to
    // come back.
    Get.lazyPut(
      () => DashboardController(
        Get.find<AnalyticsRepository>(),
        Get.find<TransactionRepository>(),
        Get.find<BudgetRepository>(),
        Get.find<SpendingPlanRepository>(),
        Get.find<GoalRepository>(),
        Get.find<AppEvents>(),
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

class TransactionFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => TransactionFormController(
        Get.find<TransactionRepository>(),
        Get.find<AccountRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<SettingsController>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class AccountsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AccountsController(
        Get.find<AccountRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class AccountFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => AccountFormController(
        Get.find<AccountRepository>(),
        Get.find<SettingsController>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class CategoriesBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CategoriesController(
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class CategoryFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => CategoryFormController(
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class BudgetsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => BudgetsController(
        Get.find<BudgetRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class BudgetFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => BudgetFormController(
        Get.find<BudgetRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class PlanFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => PlanFormController(
        Get.find<SpendingPlanRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class PlanDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => PlanDetailController(
        Get.find<SpendingPlanRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class GoalsBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => GoalsController(Get.find<GoalRepository>(), Get.find<AppEvents>()),
    );
  }
}

class GoalFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () =>
          GoalFormController(Get.find<GoalRepository>(), Get.find<AppEvents>()),
    );
  }
}

class GoalDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => GoalDetailController(
        Get.find<GoalRepository>(),
        Get.find<AccountRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class RecurringBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => RecurringController(
        Get.find<RecurringRepository>(),
        Get.find<RecurringService>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}

class RecurringFormBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(
      () => RecurringFormController(
        Get.find<RecurringRepository>(),
        Get.find<AccountRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<AppEvents>(),
      ),
    );
  }
}
