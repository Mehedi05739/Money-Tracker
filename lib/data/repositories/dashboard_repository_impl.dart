import '../../core/constants/app_constants.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/analytics.dart';
import '../../domain/entities/budget_status.dart';
import '../../domain/entities/financial_goal.dart';
import '../../domain/entities/money_transaction.dart';
import '../../domain/entities/spending_plan_progress.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../domain/repositories/budget_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/repositories/spending_plan_repository.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Composes the feature repositories the dashboard reads from.
///
/// It owns no SQL of its own — each section still comes from the repository
/// that owns that data.
class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl({
    required this.analytics,
    required this.transactions,
    required this.budgets,
    required this.plans,
    required this.goals,
    required this.accountsRepository,
  });

  final AnalyticsRepository analytics;
  final TransactionRepository transactions;
  final BudgetRepository budgets;
  final SpendingPlanRepository plans;
  final GoalRepository goals;
  final AccountRepository accountsRepository;

  @override
  Future<Result<DashboardSummary>> getSummary(
    DateRange range, {
    int? accountId,
  }) => analytics.getDashboardSummary(range, accountId: accountId);

  @override
  Future<Result<List<MoneyTransaction>>> getRecent({
    int limit = AppConstants.recentTransactionCount,
    int? accountId,
  }) => accountId == null
      ? transactions.getRecent(limit: limit)
      : transactions.getByAccount(accountId, limit: limit);

  @override
  Future<Result<List<Account>>> getAccounts() =>
      accountsRepository.getAccounts();

  @override
  Future<Result<List<BudgetStatus>>> getBudgetStatuses() =>
      budgets.getStatuses();

  @override
  Future<Result<SpendingPlanProgress?>> getCurrentPlan() =>
      plans.getCurrentProgress();

  @override
  Future<Result<List<FinancialGoal>>> getActiveGoals() =>
      goals.getGoals(activeOnly: true);

  /// Starts every read together and awaits them in order, so a full load costs
  /// one round trip of wall time rather than five.
  @override
  Future<Result<DashboardData>> load(DateRange range, {int? accountId}) async {
    final summaryFuture = getSummary(range, accountId: accountId);
    final recentFuture = getRecent(accountId: accountId);
    final accountsFuture = getAccounts();
    final budgetFuture = getBudgetStatuses();
    final planFuture = getCurrentPlan();
    final goalFuture = getActiveGoals();

    final summaryResult = await summaryFuture;
    final recentResult = await recentFuture;
    final budgetResult = await budgetFuture;
    final planResult = await planFuture;
    final goalResult = await goalFuture;
    final accountsResult = await accountsFuture;

    // The summary is the screen. The rest are supporting cards, so a single
    // failing card degrades to empty instead of blanking the dashboard.
    return summaryResult.fold(
      onSuccess: (summary) => Result.success(
        DashboardData(
          summary: summary,
          recent: recentResult.dataOrNull ?? const [],
          budgets: budgetResult.dataOrNull ?? const [],
          currentPlan: planResult.dataOrNull,
          goals: goalResult.dataOrNull ?? const [],
          accounts: accountsResult.dataOrNull ?? const [],
        ),
      ),
      onError: Result<DashboardData>.error,
    );
  }
}
