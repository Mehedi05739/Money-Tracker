import 'package:get/get.dart';

import '../features/accounts/presentation/pages/account_form_page.dart';
import '../features/accounts/presentation/pages/accounts_page.dart';
import '../features/budgets/presentation/pages/budget_form_page.dart';
import '../features/budgets/presentation/pages/budgets_page.dart';
import '../features/categories/presentation/pages/categories_page.dart';
import '../features/categories/presentation/pages/category_form_page.dart';
import '../features/goals/presentation/pages/goal_detail_page.dart';
import '../features/goals/presentation/pages/goal_form_page.dart';
import '../features/goals/presentation/pages/goals_page.dart';
import '../features/plans/presentation/pages/plan_detail_page.dart';
import '../features/plans/presentation/pages/plan_form_page.dart';
import '../features/recurring/presentation/pages/recurring_form_page.dart';
import '../features/recurring/presentation/pages/recurring_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/shell/presentation/pages/shell_page.dart';
import '../features/transactions/presentation/pages/transaction_detail_page.dart';
import '../features/transactions/presentation/pages/transaction_form_page.dart';
import '../features/accounts/presentation/bindings/accounts_binding.dart';
import '../features/budgets/presentation/bindings/budgets_binding.dart';
import '../features/categories/presentation/bindings/categories_binding.dart';
import '../features/goals/presentation/bindings/goals_binding.dart';
import '../features/plans/presentation/bindings/plans_binding.dart';
import '../features/recurring/presentation/bindings/recurring_binding.dart';
import '../features/shell/presentation/bindings/shell_binding.dart';
import '../features/transactions/presentation/bindings/transaction_form_binding.dart';
import 'app_routes.dart';

/// Route table. Each page declares its binding so a feature's controllers are
/// created on navigation and released when the route is popped.
class AppPages {
  const AppPages._();

  static const String initial = AppRoutes.shell;

  static final List<GetPage<dynamic>> routes = [
    GetPage(
      name: AppRoutes.shell,
      page: () => const ShellPage(),
      binding: ShellBinding(),
    ),
    GetPage(
      name: AppRoutes.transactionDetail,
      page: () => const TransactionDetailPage(),
    ),
    GetPage(
      name: AppRoutes.transactionForm,
      page: () => const TransactionFormPage(),
      binding: TransactionFormBinding(),
      transition: Transition.downToUp,
    ),
    GetPage(
      name: AppRoutes.accounts,
      page: () => const AccountsPage(),
      binding: AccountsBinding(),
    ),
    GetPage(
      name: AppRoutes.accountForm,
      page: () => const AccountFormPage(),
      binding: AccountFormBinding(),
    ),
    GetPage(
      name: AppRoutes.categories,
      page: () => const CategoriesPage(),
      binding: CategoriesBinding(),
    ),
    GetPage(
      name: AppRoutes.categoryForm,
      page: () => const CategoryFormPage(),
      binding: CategoryFormBinding(),
    ),
    GetPage(
      name: AppRoutes.budgets,
      page: () => const BudgetsPage(),
      binding: BudgetsBinding(),
    ),
    GetPage(
      name: AppRoutes.budgetForm,
      page: () => const BudgetFormPage(),
      binding: BudgetFormBinding(),
    ),
    GetPage(
      name: AppRoutes.spendingPlanForm,
      page: () => const PlanFormPage(),
      binding: PlanFormBinding(),
    ),
    GetPage(
      name: AppRoutes.spendingPlanDetail,
      page: () => const PlanDetailPage(),
      binding: PlanDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.goals,
      page: () => const GoalsPage(),
      binding: GoalsBinding(),
    ),
    GetPage(
      name: AppRoutes.goalForm,
      page: () => const GoalFormPage(),
      binding: GoalFormBinding(),
    ),
    GetPage(
      name: AppRoutes.goalDetail,
      page: () => const GoalDetailPage(),
      binding: GoalDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.recurring,
      page: () => const RecurringPage(),
      binding: RecurringBinding(),
    ),
    GetPage(
      name: AppRoutes.recurringForm,
      page: () => const RecurringFormPage(),
      binding: RecurringFormBinding(),
    ),
    GetPage(name: AppRoutes.settings, page: () => const SettingsPage()),
  ];

  /// Unknown deep links land back on the shell rather than a dead end.
  static final GetPage<dynamic> unknownRoute = GetPage(
    name: '/not-found',
    page: () => const ShellPage(),
    binding: ShellBinding(),
  );
}
