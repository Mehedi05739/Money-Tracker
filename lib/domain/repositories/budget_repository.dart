import '../../core/utils/result.dart';
import '../entities/budget.dart';
import '../entities/budget_status.dart';

abstract class BudgetRepository {
  Future<Result<List<Budget>>> getBudgets({bool activeOnly = false});
  Future<Result<Budget>> getById(int id);
  Future<Result<Budget>> create(Budget budget);
  Future<Result<Budget>> update(Budget budget);
  Future<Result<void>> delete(int id);

  /// Pauses or resumes a budget, leaving its amount and period untouched.
  ///
  /// A paused budget stops raising alerts and stops counting toward totals,
  /// but keeps its history so resuming picks up where it left off.
  Future<Result<void>> setActive(int id, bool active);

  /// Budgets paired with their spend, computed by a grouped aggregate rather
  /// than one query per budget.
  /// Budgets paired with their spend, computed by a grouped aggregate rather
  /// than one query per budget.
  ///
  /// [includePaused] is for the budgets screen, which has to show paused
  /// budgets so they can be resumed; the dashboard leaves it off so paused
  /// budgets raise no alerts.
  Future<Result<List<BudgetStatus>>> getStatuses({
    bool currentOnly = true,
    bool includePaused = false,
  });
  Future<Result<BudgetStatus>> getStatus(int budgetId);
}
