import '../../core/utils/result.dart';
import '../entities/spending_plan.dart';
import '../entities/spending_plan_progress.dart';

abstract class SpendingPlanRepository {
  Future<Result<List<SpendingPlan>>> getPlans({bool activeOnly = false});
  Future<Result<SpendingPlan>> getById(int id);
  Future<Result<SpendingPlan>> create(SpendingPlan plan);
  Future<Result<SpendingPlan>> update(SpendingPlan plan);
  Future<Result<void>> delete(int id);

  Future<Result<List<SpendingPlanItem>>> getItems(int planId);
  Future<Result<SpendingPlanItem>> upsertItem(SpendingPlanItem item);
  Future<Result<void>> deleteItem(int itemId);

  /// Plan plus per-category actuals for its window.
  Future<Result<SpendingPlanProgress>> getProgress(int planId);

  /// Progress for the plan covering today, if there is one.
  Future<Result<SpendingPlanProgress?>> getCurrentProgress();
}
