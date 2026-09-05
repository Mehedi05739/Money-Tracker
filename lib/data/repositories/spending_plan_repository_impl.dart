import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/spending_plan.dart';
import '../../domain/entities/spending_plan_progress.dart';
import '../../domain/repositories/spending_plan_repository.dart';
import '../local/daos/spending_plan_dao.dart';
import 'repository_guard.dart';

class SpendingPlanRepositoryImpl implements SpendingPlanRepository {
  const SpendingPlanRepositoryImpl(this._dao);

  final SpendingPlanDao _dao;

  @override
  Future<Result<List<SpendingPlan>>> getPlans({bool activeOnly = false}) =>
      guard(() => _dao.find(activeOnly: activeOnly), context: 'getPlans');

  @override
  Future<Result<SpendingPlan>> getById(int id) =>
      guardFound(() => _dao.findById(id), notFoundMessage: 'Plan not found');

  @override
  Future<Result<SpendingPlan>> create(SpendingPlan plan) async {
    final invalid = _validatePlan(plan);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      final id = await _dao.insert(plan);
      final created = await _dao.findById(id);
      if (created == null) throw StateError('Plan $id missing after insert');
      return created;
    }, context: 'createPlan');
  }

  @override
  Future<Result<SpendingPlan>> update(SpendingPlan plan) async {
    final invalid = _validatePlan(plan);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      await _dao.update(plan);
      final updated = await _dao.findById(plan.id);
      if (updated == null) throw StateError('Plan ${plan.id} missing');
      return updated;
    }, context: 'updatePlan');
  }

  @override
  Future<Result<void>> delete(int id) =>
      guard(() => _dao.delete(id), context: 'deletePlan');

  @override
  Future<Result<SpendingPlan?>> getPreviousPlan(DateTime before) =>
      guard(() => _dao.findPrevious(before), context: 'previousPlan');

  @override
  Future<Result<SpendingPlan>> createFromTemplate({
    required SpendingPlan plan,
    required int sourcePlanId,
  }) async {
    final invalid = _validatePlan(plan);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      final id = await _dao.insertCopy(plan: plan, sourcePlanId: sourcePlanId);
      final created = await _dao.findById(id);
      if (created == null) throw StateError('Plan $id missing after copy');
      return created;
    }, context: 'copyPlan');
  }

  @override
  Future<Result<List<SpendingPlanItem>>> getItems(int planId) =>
      guard(() => _dao.findItems(planId), context: 'planItems');

  @override
  Future<Result<SpendingPlanItem>> upsertItem(SpendingPlanItem item) async {
    if (item.categoryId == null) {
      return const Result.error(
        ValidationFailure(
          'Choose a category',
          fieldErrors: {'category': 'Required'},
        ),
      );
    }
    if (item.plannedAmount < 0) {
      return const Result.error(
        ValidationFailure(
          'Planned amount cannot be negative',
          fieldErrors: {'amount': 'Must be zero or more'},
        ),
      );
    }
    if (item.plannedAmount > Validators.maxAmount) {
      return const Result.error(
        ValidationFailure(
          'Planned amount is too large',
          fieldErrors: {'amount': 'Too large'},
        ),
      );
    }

    return guard(() async {
      final id = await _dao.upsertItem(item);
      final items = await _dao.findItems(item.planId);
      return items.firstWhere(
        (candidate) => candidate.id == id,
        orElse: () => throw StateError('Plan item $id missing after save'),
      );
    }, context: 'upsertPlanItem');
  }

  @override
  Future<Result<void>> deleteItem(int itemId) =>
      guard(() => _dao.deleteItem(itemId), context: 'deletePlanItem');

  @override
  Future<Result<SpendingPlanProgress>> getProgress(int planId) async {
    final plan = await getById(planId);
    return plan.fold(
      onSuccess: (value) =>
          guard(() => _dao.findProgress(value), context: 'planProgress'),
      onError: Result<SpendingPlanProgress>.error,
    );
  }

  @override
  Future<Result<SpendingPlanProgress?>> getCurrentProgress() => guard(() async {
    final plan = await _dao.findCurrent();
    if (plan == null) return null;
    return _dao.findProgress(plan);
  }, context: 'currentPlanProgress');

  Failure? _validatePlan(SpendingPlan plan) {
    final errors = <String, String>{};

    final nameError = Validators.name(plan.name, field: 'Plan name');
    if (nameError != null) errors['name'] = nameError;

    if (plan.expectedIncome <= 0) {
      errors['expectedIncome'] = 'Spending limit must be greater than zero';
    } else if (plan.expectedIncome > Validators.maxAmount) {
      errors['expectedIncome'] = 'Spending limit is too large';
    }

    if (plan.endDate.isBefore(plan.startDate)) {
      errors['endDate'] = 'End date must be after the start date';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure(
      'Please fix the highlighted fields',
      fieldErrors: errors,
    );
  }
}
