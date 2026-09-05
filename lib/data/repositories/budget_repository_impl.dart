import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/budget.dart';
import '../../domain/entities/budget_status.dart';
import '../../domain/repositories/budget_repository.dart';
import '../local/daos/budget_dao.dart';
import 'repository_guard.dart';

class BudgetRepositoryImpl implements BudgetRepository {
  const BudgetRepositoryImpl(this._dao);

  final BudgetDao _dao;

  @override
  Future<Result<List<Budget>>> getBudgets({bool activeOnly = false}) =>
      guard(() => _dao.find(activeOnly: activeOnly), context: 'getBudgets');

  @override
  Future<Result<Budget>> getById(int id) =>
      guardFound(() => _dao.findById(id), notFoundMessage: 'Budget not found');

  @override
  Future<Result<Budget>> create(Budget budget) async {
    final invalid = _validate(budget);
    if (invalid != null) return Result.error(invalid);

    final overlap = await _checkOverlap(budget);
    if (overlap != null) return Result.error(overlap);

    return guard(() async {
      final id = await _dao.insert(budget);
      final created = await _dao.findById(id);
      if (created == null) throw StateError('Budget $id missing after insert');
      return created;
    }, context: 'createBudget');
  }

  @override
  Future<Result<Budget>> update(Budget budget) async {
    final invalid = _validate(budget);
    if (invalid != null) return Result.error(invalid);

    final overlap = await _checkOverlap(budget);
    if (overlap != null) return Result.error(overlap);

    return guard(() async {
      await _dao.update(budget);
      final updated = await _dao.findById(budget.id);
      if (updated == null) throw StateError('Budget ${budget.id} missing');
      return updated;
    }, context: 'updateBudget');
  }

  @override
  Future<Result<void>> delete(int id) =>
      guard(() => _dao.delete(id), context: 'deleteBudget');

  @override
  Future<Result<void>> setActive(int id, bool active) =>
      guard(() => _dao.setActive(id, active), context: 'toggleBudget');

  @override
  Future<Result<List<BudgetStatus>>> getStatuses({
    bool currentOnly = true,
    bool includePaused = false,
  }) => guard(
    () => _dao.findWithSpend(
      currentOnly: currentOnly,
      includePaused: includePaused,
    ),
    context: 'budgetStatuses',
  );

  @override
  Future<Result<BudgetStatus>> getStatus(int budgetId) => guardFound(
    () => _dao.findStatusById(budgetId),
    notFoundMessage: 'Budget not found',
  );

  Failure? _validate(Budget budget) {
    final errors = <String, String>{};

    if (budget.amount <= 0) {
      errors['amount'] = 'Budget must be greater than zero';
    } else if (budget.amount > Validators.maxAmount) {
      errors['amount'] = 'Budget is too large';
    }

    if (budget.endDate.isBefore(budget.startDate)) {
      errors['endDate'] = 'End date must be after the start date';
    }

    if (budget.alertPercentage < 1 || budget.alertPercentage > 100) {
      errors['alertPercentage'] = 'Alert must be between 1 and 100';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure(
      'Please fix the highlighted fields',
      fieldErrors: errors,
    );
  }

  /// Two active budgets on the same category and overlapping dates would make
  /// "budget usage" ambiguous, so the second one is rejected.
  Future<Failure?> _checkOverlap(Budget budget) async {
    if (!budget.isActive) return null;

    final result = await guard(
      () => _dao.overlapsExisting(budget),
      context: 'budgetOverlap',
    );
    return result.fold(
      onSuccess: (overlaps) => overlaps
          ? ValidationFailure(
              'An active budget for ${budget.displayName} already covers '
              'these dates',
            )
          : null,
      onError: (failure) => failure,
    );
  }
}
