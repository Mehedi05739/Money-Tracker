import 'package:get/get.dart';

import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/financial_goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../local/daos/goal_dao.dart';
import 'repository_guard.dart';

class GoalRepositoryImpl implements GoalRepository {
  const GoalRepositoryImpl(this._dao);

  final GoalDao _dao;

  @override
  Future<Result<List<FinancialGoal>>> getGoals({bool activeOnly = false}) =>
      guard(() => _dao.find(activeOnly: activeOnly), context: 'getGoals');

  @override
  Future<Result<FinancialGoal>> getById(int id) =>
      guardFound(() => _dao.findById(id), notFoundMessage: 'Goal not found');

  @override
  Future<Result<FinancialGoal>> create(FinancialGoal goal) async {
    final invalid = _validate(goal);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      final id = await _dao.insert(goal);
      final created = await _dao.findById(id);
      if (created == null) throw StateError('Goal $id missing after insert');
      return created;
    }, context: 'createGoal');
  }

  @override
  Future<Result<FinancialGoal>> update(FinancialGoal goal) async {
    final invalid = _validate(goal);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      await _dao.update(goal);
      final updated = await _dao.findById(goal.id);
      if (updated == null) throw StateError('Goal ${goal.id} missing');
      return updated;
    }, context: 'updateGoal');
  }

  @override
  Future<Result<void>> delete(int id) =>
      guard(() => _dao.delete(id), context: 'deleteGoal');

  @override
  Future<Result<List<GoalContribution>>> getContributions(int goalId) =>
      guard(() => _dao.findContributions(goalId), context: 'goalContributions');

  @override
  Future<Result<FinancialGoal>> addContribution(
    GoalContribution contribution,
  ) async {
    final invalid = _validateContribution(contribution);
    if (invalid != null) return Result.error(invalid);

    final overdraw = await _checkWithdrawal(contribution);
    if (overdraw != null) return Result.error(overdraw);

    return guardFound(
      () => _dao.addContribution(
        contribution.copyWith(
          amount: Validators.normalizeAmount(contribution.amount),
        ),
      ),
      notFoundMessage: 'Goal not found',
      context: 'addContribution',
    );
  }

  Failure? _validateContribution(GoalContribution contribution) {
    if (contribution.amount == 0) {
      return const ValidationFailure(
        'Enter an amount',
        fieldErrors: {'amount': 'Amount must not be zero'},
      );
    }
    if (contribution.amount.abs() > Validators.maxAmount) {
      return const ValidationFailure(
        'Amount is too large',
        fieldErrors: {'amount': 'Too large'},
      );
    }
    return null;
  }

  /// A withdrawal cannot take a goal below zero.
  ///
  /// When editing, the contribution's own stored amount is removed from the
  /// total first — otherwise changing a withdrawal from -50 to -60 would be
  /// measured against a total that still includes the original -50.
  Future<Failure?> _checkWithdrawal(
    GoalContribution contribution, {
    bool excludeSelf = false,
  }) async {
    if (contribution.amount >= 0) return null;

    final goal = await getById(contribution.goalId);
    if (goal case Failed(:final failure)) return failure;
    if (goal case Success(:final data)) {
      var available = data.currentAmount;

      if (excludeSelf) {
        final existing = await getContributions(contribution.goalId);
        final previous = existing.dataOrNull?.firstWhereOrNull(
          (item) => item.id == contribution.id,
        );
        if (previous != null) available -= previous.amount;
      }

      if (available + contribution.amount < 0) {
        return ValidationFailure(
          'You can withdraw at most ${available.toStringAsFixed(2)}',
          fieldErrors: const {'amount': 'More than the goal holds'},
        );
      }
    }
    return null;
  }

  @override
  Future<Result<FinancialGoal>> updateContribution(
    GoalContribution contribution,
  ) async {
    final invalid = _validateContribution(contribution);
    if (invalid != null) return Result.error(invalid);

    // A withdrawal must not take the goal below zero once re-applied, so the
    // check is against the total excluding this contribution's old value.
    final overdraw = await _checkWithdrawal(contribution, excludeSelf: true);
    if (overdraw != null) return Result.error(overdraw);

    return guardFound(
      () => _dao.updateContribution(
        contribution.copyWith(
          amount: Validators.normalizeAmount(contribution.amount),
        ),
      ),
      notFoundMessage: 'Contribution not found',
      context: 'updateContribution',
    );
  }

  @override
  Future<Result<FinancialGoal>> deleteContribution(int contributionId) =>
      guardFound(
        () => _dao.deleteContribution(contributionId),
        notFoundMessage: 'Contribution not found',
        context: 'deleteContribution',
      );

  Failure? _validate(FinancialGoal goal) {
    final errors = <String, String>{};

    final nameError = Validators.name(goal.name, field: 'Goal name');
    if (nameError != null) errors['name'] = nameError;

    if (goal.targetAmount <= 0) {
      errors['targetAmount'] = 'Target must be greater than zero';
    } else if (goal.targetAmount > Validators.maxAmount) {
      errors['targetAmount'] = 'Target is too large';
    }

    // A target already in the past cannot be met.
    final target = goal.targetDate;
    if (!goal.isPersisted &&
        target != null &&
        target.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
      errors['targetDate'] = 'Target date is already in the past';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure(
      'Please fix the highlighted fields',
      fieldErrors: errors,
    );
  }
}
