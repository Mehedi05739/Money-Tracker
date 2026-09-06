import '../../core/errors/failures.dart';
import '../../core/utils/result.dart';
import '../../core/utils/validators.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../domain/repositories/recurring_repository.dart';
import '../local/daos/recurring_dao.dart';
import 'repository_guard.dart';

class RecurringRepositoryImpl implements RecurringRepository {
  const RecurringRepositoryImpl(this._dao);

  final RecurringDao _dao;

  @override
  Future<Result<List<RecurringTransaction>>> getAll({
    bool activeOnly = false,
  }) => guard(() => _dao.find(activeOnly: activeOnly), context: 'getRecurring');

  @override
  Future<Result<RecurringTransaction>> getById(int id) => guardFound(
    () => _dao.findById(id),
    notFoundMessage: 'Recurring transaction not found',
  );

  @override
  Future<Result<RecurringTransaction>> create(RecurringTransaction rule) async {
    final invalid = _validate(rule);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      final id = await _dao.insert(rule);
      final created = await _dao.findById(id);
      if (created == null) throw StateError('Rule $id missing after insert');
      return created;
    }, context: 'createRecurring');
  }

  @override
  Future<Result<RecurringTransaction>> update(RecurringTransaction rule) async {
    final invalid = _validate(rule);
    if (invalid != null) return Result.error(invalid);

    return guard(() async {
      await _dao.update(rule);
      final updated = await _dao.findById(rule.id);
      if (updated == null) throw StateError('Rule ${rule.id} missing');
      return updated;
    }, context: 'updateRecurring');
  }

  @override
  Future<Result<void>> delete(int id) =>
      guard(() => _dao.delete(id), context: 'deleteRecurring');

  @override
  Future<Result<void>> setActive(int id, bool active) =>
      guard(() => _dao.setActive(id, active), context: 'toggleRecurring');

  @override
  Future<Result<List<RecurringTransaction>>> getDue() =>
      guard(_dao.findDue, context: 'dueRecurring');

  @override
  Future<Result<int>> postDueOccurrences(RecurringTransaction rule) =>
      guard(() => _dao.postDueOccurrences(rule), context: 'postRecurring');

  @override
  Future<Result<bool>> isOccurrenceProcessed(int ruleId, DateTime date) =>
      guard(
        () => _dao.isOccurrenceProcessed(ruleId, date),
        context: 'isOccurrenceProcessed',
      );

  @override
  Future<Result<List<RecurringOccurrence>>> getOccurrences(
    int ruleId, {
    int limit = 50,
  }) => guard(
    () => _dao.findOccurrences(ruleId, limit: limit),
    context: 'recurringOccurrences',
  );

  @override
  Future<Result<List<UpcomingOccurrence>>> getUpcoming({
    int perRule = 3,
    int limit = 12,
  }) => guard(() async {
    final rules = await _dao.find(activeOnly: true);

    final upcoming = [
      for (final rule in rules)
        for (final date in rule.upcomingDates(count: perRule))
          UpcomingOccurrence(rule: rule, date: date),
    ]..sort((a, b) => a.date.compareTo(b.date));

    return upcoming.take(limit).toList();
  }, context: 'recurringUpcoming');

  Failure? _validate(RecurringTransaction rule) {
    final errors = <String, String>{};

    if (rule.title.trim().isEmpty) errors['title'] = 'Add a short title';

    if (rule.amount <= 0) {
      errors['amount'] = 'Amount must be greater than zero';
    } else if (rule.amount > Validators.maxAmount) {
      errors['amount'] = 'Amount is too large';
    }

    if (rule.accountId <= 0) errors['account'] = 'Choose an account';
    if (rule.categoryId == null) errors['category'] = 'Choose a category';
    if (rule.intervalCount < 1) {
      errors['interval'] = 'Interval must be at least 1';
    }

    if (rule.type.isTransfer) {
      errors['type'] = 'Transfers cannot be scheduled';
    }

    final end = rule.endDate;
    if (end != null && end.isBefore(rule.startDate)) {
      errors['endDate'] = 'End date must be after the start date';
    }

    if (errors.isEmpty) return null;
    return ValidationFailure(
      'Please fix the highlighted fields',
      fieldErrors: errors,
    );
  }
}
