/// Route names only, so any layer can navigate without importing pages.
abstract class AppRoutes {
  static const String splash = '/';
  static const String shell = '/home';

  static const String transactionForm = '/transactions/form';
  static const String transactionDetail = '/transactions/detail';

  static const String accounts = '/accounts';
  static const String accountForm = '/accounts/form';

  static const String categories = '/categories';
  static const String categoryForm = '/categories/form';

  static const String budgets = '/budgets';
  static const String budgetForm = '/budgets/form';

  static const String spendingPlanForm = '/plans/form';
  static const String spendingPlanDetail = '/plans/detail';

  static const String goals = '/goals';
  static const String goalForm = '/goals/form';
  static const String goalDetail = '/goals/detail';

  static const String recurring = '/recurring';
  static const String recurringForm = '/recurring/form';

  static const String settings = '/settings';
}
