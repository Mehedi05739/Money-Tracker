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
  Future<Result<int>> postDueOccurrences(RecurringTransaction rule);
}
