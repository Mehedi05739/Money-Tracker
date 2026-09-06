import '../../core/utils/result.dart';
import '../entities/recurring_transaction.dart';

abstract class RecurringRepository {
  Future<Result<List<RecurringTransaction>>> getAll({bool activeOnly = false});
  Future<Result<RecurringTransaction>> getById(int id);
  Future<Result<RecurringTransaction>> create(RecurringTransaction rule);
  Future<Result<RecurringTransaction>> update(RecurringTransaction rule);
  Future<Result<void>> delete(int id);
  Future<Result<void>> setActive(int id, bool active);

  /// Rules whose next run date has arrived.
  Future<Result<List<RecurringTransaction>>> getDue();

  /// Writes every missed occurrence for [rule] up to today and advances its
  /// schedule, in one SQL transaction. Returns how many rows were posted.
  ///
  /// Safe to call twice: each occurrence is claimed in the ledger before it is
  /// written, and the ledger's unique index rejects a repeat.
  Future<Result<int>> postDueOccurrences(RecurringTransaction rule);

  /// Whether the occurrence of [ruleId] falling on [date] has already been
  /// processed.
  Future<Result<bool>> isOccurrenceProcessed(int ruleId, DateTime date);

  /// The occurrences [ruleId] has produced, most recent first.
  Future<Result<List<RecurringOccurrence>>> getOccurrences(
    int ruleId, {
    int limit = 50,
  });

  /// The next occurrences across every active rule, soonest first.
  ///
  /// Projected from the rules rather than read from a table: nothing is written
  /// ahead of time, so this cannot fall out of step with an edited schedule.
  Future<Result<List<UpcomingOccurrence>>> getUpcoming({
    int perRule = 3,
    int limit = 12,
  });
}
