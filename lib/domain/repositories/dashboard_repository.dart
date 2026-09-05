import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
import '../entities/analytics.dart';
import '../entities/budget_status.dart';
import '../entities/financial_goal.dart';
import '../entities/money_transaction.dart';
import '../entities/spending_plan_progress.dart';

/// Everything the dashboard shows, in one place.
///
/// Without this the controller had to hold five repositories and know which of
/// them answered which card. Composing them here keeps the controller down to
/// one dependency and gives each section its own reload, so a change to goals
/// does not re-query transactions.
abstract class DashboardRepository {
  /// Every section at once, for the first load and pull-to-refresh.
  Future<Result<DashboardData>> load(DateRange range);

  Future<Result<DashboardSummary>> getSummary(DateRange range);
  Future<Result<List<MoneyTransaction>>> getRecent({int limit});
  Future<Result<List<BudgetStatus>>> getBudgetStatuses();
  Future<Result<SpendingPlanProgress?>> getCurrentPlan();
  Future<Result<List<FinancialGoal>>> getActiveGoals();
}

/// A complete dashboard snapshot.
class DashboardData {
  const DashboardData({
    required this.summary,
    required this.recent,
    required this.budgets,
    required this.currentPlan,
    required this.goals,
  });

  final DashboardSummary summary;
  final List<MoneyTransaction> recent;
  final List<BudgetStatus> budgets;
  final SpendingPlanProgress? currentPlan;
  final List<FinancialGoal> goals;
}
