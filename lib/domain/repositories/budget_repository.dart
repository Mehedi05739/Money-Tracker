import '../../core/utils/result.dart';
import '../entities/budget.dart';
import '../entities/budget_status.dart';

abstract class BudgetRepository {
  Future<Result<List<Budget>>> getBudgets({bool activeOnly = false});
  Future<Result<Budget>> getById(int id);
  Future<Result<Budget>> create(Budget budget);
  Future<Result<Budget>> update(Budget budget);
  Future<Result<void>> delete(int id);

  /// Budgets paired with their spend, computed by a grouped aggregate rather
  /// than one query per budget.
  Future<Result<List<BudgetStatus>>> getStatuses({bool currentOnly = true});
  Future<Result<BudgetStatus>> getStatus(int budgetId);
}
