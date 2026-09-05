import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/errors/failures.dart';
import 'package:money_tracker/core/utils/result.dart';
import 'package:money_tracker/features/transaction/domain/entities/transaction_entity.dart';
import 'package:money_tracker/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:money_tracker/features/transaction/domain/usecases/add_transaction.dart';
import 'package:money_tracker/features/transaction/domain/usecases/get_transactions.dart';

/// Hand-rolled fake — the domain layer depends on an abstraction, so testing a
/// use case needs no mocking package, no HTTP and no Flutter binding.
class _FakeTransactionRepository implements TransactionRepository {
  _FakeTransactionRepository(this.items);

  final List<TransactionEntity> items;
  TransactionEntity? added;

  @override
  Future<Result<List<TransactionEntity>>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async =>
      Result.success(items);

  @override
  Future<Result<TransactionEntity>> addTransaction(
    TransactionEntity transaction,
  ) async {
    added = transaction;
    return Result.success(transaction);
  }

  @override
  Future<Result<TransactionEntity>> getTransactionById(String id) async =>
      Result.success(items.firstWhere((e) => e.id == id));

  @override
  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  ) async =>
      Result.success(transaction);

  @override
  Future<Result<void>> deleteTransaction(String id) async =>
      const Result.success(null);
}

TransactionEntity _tx({
  required String id,
  required DateTime date,
  double amount = 10,
  String title = 'Item',
  TransactionType type = TransactionType.expense,
}) =>
    TransactionEntity(
      id: id,
      title: title,
      amount: amount,
      type: type,
      date: date,
    );

void main() {
  group('GetTransactions', () {
    test('returns transactions sorted newest first', () async {
      final repository = _FakeTransactionRepository([
        _tx(id: 'old', date: DateTime(2026, 1, 1)),
        _tx(id: 'new', date: DateTime(2026, 9, 1)),
        _tx(id: 'mid', date: DateTime(2026, 5, 1)),
      ]);

      final result =
          await GetTransactions(repository)(const GetTransactionsParams());

      expect(result.isSuccess, isTrue);
      expect(
        result.dataOrNull?.map((e) => e.id).toList(),
        ['new', 'mid', 'old'],
      );
    });
  });

  group('AddTransaction', () {
    test('rejects a blank title and a non-positive amount', () async {
      final repository = _FakeTransactionRepository([]);

      final result = await AddTransaction(repository)(
        _tx(id: '', title: '   ', amount: 0, date: DateTime(2026, 9, 1)),
      );

      expect(result.isError, isTrue);
      final failure = result.failureOrNull;
      expect(failure, isA<ValidationFailure>());
      expect(
        (failure! as ValidationFailure).fieldErrors.keys,
        containsAll(['title', 'amount']),
      );
      expect(repository.added, isNull, reason: 'must not reach the repository');
    });

    test('forwards a valid transaction to the repository', () async {
      final repository = _FakeTransactionRepository([]);

      final result = await AddTransaction(repository)(
        _tx(id: '', title: 'Coffee', amount: 4.5, date: DateTime(2026, 9, 1)),
      );

      expect(result.isSuccess, isTrue);
      expect(repository.added?.title, 'Coffee');
    });
  });

  group('TransactionEntity', () {
    test('signs amounts so the balance nets out', () {
      final income = _tx(
        id: '1',
        amount: 100,
        type: TransactionType.income,
        date: DateTime(2026, 9, 1),
      );
      final expense = _tx(id: '2', amount: 40, date: DateTime(2026, 9, 2));

      expect(income.signedAmount + expense.signedAmount, 60);
    });
  });
}
