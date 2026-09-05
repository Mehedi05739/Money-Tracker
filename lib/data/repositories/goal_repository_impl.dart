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
    if (contribution.amount == 0) {
      return const Result.error(
        ValidationFailure(
          'Enter an amount',
          fieldErrors: {'amount': 'Amount must not be zero'},
        ),
      );
    }
    if (contribution.amount.abs() > Validators.maxAmount) {
      return const Result.error(
        ValidationFailure(
          'Amount is too large',
          fieldErrors: {'amount': 'Too large'},
        ),
      );
    }

    // A withdrawal cannot take the goal below zero.
    if (contribution.amount < 0) {
      final goal = await getById(contribution.goalId);
      if (goal case Failed(:final failure)) return Result.error(failure);
      if (goal case Success(:final data)
          when data.currentAmount + contribution.amount < 0) {
        return Result.error(
          ValidationFailure(
            'You can withdraw at most ${data.currentAmount.toStringAsFixed(2)}',
            fieldErrors: const {'amount': 'More than the goal holds'},
          ),
        );
      }
    }

    return guardFound(
      () => _dao.addContribution(
        GoalContribution(
          id: contribution.id,
          goalId: contribution.goalId,
          accountId: contribution.accountId,
          amount: Validators.normalizeAmount(contribution.amount),
          contributedAt: contribution.contributedAt,
          note: contribution.note,
          createdAt: contribution.createdAt,
        ),
      ),
      notFoundMessage: 'Goal not found',
      context: 'addContribution',
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
