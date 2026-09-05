/// Table and column names, referenced everywhere instead of raw strings so a
/// rename is a compile error rather than a runtime one.
class Tables {
  const Tables._();

  static const String accounts = 'accounts';
  static const String categories = 'categories';
  static const String transactions = 'transactions';
  static const String budgets = 'budgets';
  static const String spendingPlans = 'spending_plans';
  static const String spendingPlanItems = 'spending_plan_items';
  static const String financialGoals = 'financial_goals';
  static const String goalContributions = 'goal_contributions';
  static const String recurringTransactions = 'recurring_transactions';
  static const String appSettings = 'app_settings';
}

class AccountColumns {
  const AccountColumns._();
  static const String id = 'id';
  static const String name = 'name';
  static const String type = 'type';
  static const String openingBalance = 'opening_balance';
  static const String currentBalance = 'current_balance';
  static const String currency = 'currency';
  static const String icon = 'icon';
  static const String color = 'color';
  static const String isArchived = 'is_archived';
  static const String sortOrder = 'sort_order';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class CategoryColumns {
  const CategoryColumns._();
  static const String id = 'id';
  static const String name = 'name';
  static const String type = 'type';
  static const String icon = 'icon';
  static const String color = 'color';
  static const String isDefault = 'is_default';
  static const String isArchived = 'is_archived';
  static const String createdAt = 'created_at';
}

class TransactionColumns {
  const TransactionColumns._();
  static const String id = 'id';
  static const String accountId = 'account_id';
  static const String toAccountId = 'to_account_id';
  static const String type = 'type';
  static const String amount = 'amount';
  static const String categoryId = 'category_id';
  static const String title = 'title';
  static const String description = 'description';
  static const String transactionDate = 'transaction_date';
  static const String paymentMethod = 'payment_method';
  static const String note = 'note';
  static const String recurringId = 'recurring_id';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class BudgetColumns {
  const BudgetColumns._();
  static const String id = 'id';
  static const String categoryId = 'category_id';
  static const String amount = 'amount';
  static const String period = 'period';
  static const String startDate = 'start_date';
  static const String endDate = 'end_date';
  static const String alertPercentage = 'alert_percentage';
  static const String isActive = 'is_active';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class SpendingPlanColumns {
  const SpendingPlanColumns._();
  static const String id = 'id';
  static const String name = 'name';
  static const String totalLimit = 'total_limit';
  static const String startDate = 'start_date';
  static const String endDate = 'end_date';
  static const String status = 'status';
  static const String note = 'note';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class SpendingPlanItemColumns {
  const SpendingPlanItemColumns._();
  static const String id = 'id';
  static const String planId = 'plan_id';
  static const String categoryId = 'category_id';
  static const String plannedAmount = 'planned_amount';
  static const String note = 'note';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class GoalColumns {
  const GoalColumns._();
  static const String id = 'id';
  static const String name = 'name';
  static const String targetAmount = 'target_amount';
  static const String currentAmount = 'current_amount';
  static const String targetDate = 'target_date';
  static const String icon = 'icon';
  static const String color = 'color';
  static const String status = 'status';
  static const String note = 'note';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class GoalContributionColumns {
  const GoalContributionColumns._();
  static const String id = 'id';
  static const String goalId = 'goal_id';
  static const String accountId = 'account_id';
  static const String amount = 'amount';
  static const String contributedAt = 'contributed_at';
  static const String note = 'note';
  static const String createdAt = 'created_at';
}

class RecurringColumns {
  const RecurringColumns._();
  static const String id = 'id';
  static const String accountId = 'account_id';
  static const String categoryId = 'category_id';
  static const String type = 'type';
  static const String amount = 'amount';
  static const String title = 'title';
  static const String note = 'note';
  static const String paymentMethod = 'payment_method';
  static const String frequency = 'frequency';
  static const String intervalCount = 'interval_count';
  static const String startDate = 'start_date';
  static const String endDate = 'end_date';
  static const String nextRunDate = 'next_run_date';
  static const String lastRunDate = 'last_run_date';
  static const String isActive = 'is_active';
  static const String autoPost = 'auto_post';
  static const String createdAt = 'created_at';
  static const String updatedAt = 'updated_at';
}

class SettingsColumns {
  const SettingsColumns._();
  static const String key = 'key';
  static const String value = 'value';
  static const String updatedAt = 'updated_at';
}
