import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/errors/failures.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/data/repositories/transaction_repository_impl.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/repositories/transaction_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late TransactionRepository repository;
  late AccountDao accounts;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    repository = TransactionRepositoryImpl(TransactionDao(database.db));
    accounts = AccountDao(database.db);
  });

  MoneyTransaction draft({
    double amount = 50,
    String title = 'Coffee',
    int accountId = 1,
    int? categoryId = 1,
    TransactionType type = TransactionType.expense,
    int? toAccountId,
    DateTime? date,
  }) {
    final now = DateTime.now();
    return MoneyTransaction(
      id: 0,
      accountId: accountId,
      toAccountId: toAccountId,
      type: type,
      amount: amount,
      categoryId: categoryId,
      title: title,
      transactionDate: date ?? now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, String> errorsOf(Failure? failure) =>
      failure is ValidationFailure ? failure.fieldErrors : const {};

  test('creates a valid expense and updates the balance', () async {
    final result = await repository.create(draft(amount: 12.5));

    expect(result.isSuccess, isTrue);
    expect(result.dataOrNull!.amount, 12.5);
    expect((await accounts.findById(1))!.currentBalance, -12.5);
  });

  test('rejects a zero or negative amount', () async {
    for (final amount in [0.0, -5.0]) {
      final result = await repository.create(draft(amount: amount));
      expect(result.isError, isTrue);
      expect(errorsOf(result.failureOrNull), contains('amount'));
    }
  });

  test('rejects an amount beyond the sane maximum', () async {
    final result = await repository.create(draft(amount: 1e12));
    expect(errorsOf(result.failureOrNull), contains('amount'));
  });

  test('rejects a blank title', () async {
    final result = await repository.create(draft(title: '   '));
    expect(errorsOf(result.failureOrNull), contains('title'));
  });

  test('requires a category for income and expense', () async {
    final result = await repository.create(draft(categoryId: null));
    expect(errorsOf(result.failureOrNull), contains('category'));
  });

  test('requires an account', () async {
    final result = await repository.create(draft(accountId: 0));
    expect(errorsOf(result.failureOrNull), contains('account'));
  });

  test('requires a destination account for a transfer', () async {
    final result = await repository.create(
      draft(type: TransactionType.transfer, categoryId: null),
    );
    expect(errorsOf(result.failureOrNull), contains('toAccount'));
  });

  test('rejects a transfer to the same account', () async {
    final result = await repository.create(
      draft(type: TransactionType.transfer, categoryId: null, toAccountId: 1),
    );
    expect(errorsOf(result.failureOrNull), contains('toAccount'));
  });

  test('rejects a date far in the future', () async {
    final result = await repository.create(
      draft(date: DateTime.now().add(const Duration(days: 365 * 6))),
    );
    expect(errorsOf(result.failureOrNull), contains('date'));
  });

  test('rounds amounts to cents so balances cannot drift', () async {
    final result = await repository.create(draft(amount: 10.005));
    expect(result.dataOrNull!.amount, 10.01);
  });

  test('clears the category when the type becomes a transfer', () async {
    final second = await accounts.findAll();
    expect(second, isNotEmpty);

    final created = await repository.create(draft());
    final stored = created.dataOrNull!;

    // Switching to a transfer must not leave the old category attached.
    final updated = await repository.update(
      stored.copyWith(
        type: TransactionType.transfer,
        toAccountId: await _makeSecondAccount(accounts),
      ),
    );

    expect(updated.isSuccess, isTrue);
    expect(updated.dataOrNull!.categoryId, isNull);
  });

  test('paginates without loading the whole table', () async {
    for (var i = 0; i < 12; i++) {
      await repository.create(draft(amount: i + 1, title: 'tx $i'));
    }

    final page1 = await repository.getTransactions(limit: 5);
    final page2 = await repository.getTransactions(limit: 5, offset: 5);
    final count = await repository.count(const TransactionFilter());

    expect(page1.dataOrNull, hasLength(5));
    expect(page2.dataOrNull, hasLength(5));
    expect(count.dataOrNull, 12);
    expect(
      page1.dataOrNull!
          .map((t) => t.id)
          .toSet()
          .intersection(page2.dataOrNull!.map((t) => t.id).toSet()),
      isEmpty,
    );
  });
}

Future<int> _makeSecondAccount(AccountDao accounts) async {
  final existing = await accounts.findAll();
  if (existing.length > 1) return existing[1].id;

  final now = DateTime.now();
  return accounts.insert(
    existing.first.copyWith(id: 0, name: 'Second', updatedAt: now),
  );
}
