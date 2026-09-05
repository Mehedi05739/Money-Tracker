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

  /// The most recent plan that ended before [before], if any.
  ///
  /// Used to offer last month's plan as a starting point.
  Future<Result<SpendingPlan?>> getPreviousPlan(DateTime before);

  /// Creates [plan] and copies every category allocation from [sourcePlanId].
  ///
  /// The plan and its items are written in one SQL transaction: a plan that
  /// half-copied would silently under-report what the user had allocated.
  Future<Result<SpendingPlan>> createFromTemplate({
    required SpendingPlan plan,
    required int sourcePlanId,
  });
}
