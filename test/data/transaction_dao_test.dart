import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/domain/entities/account.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/repositories/transaction_repository.dart';
import 'package:money_tracker/core/enums/account_type.dart';

import '../helpers/test_database.dart';

void main() {
  late AccountDao accounts;
  late TransactionDao transactions;

  Future<void> setUpDatabase() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    accounts = AccountDao(database.db);
    transactions = TransactionDao(database.db);
  }

  MoneyTransaction tx({
    required TransactionType type,
    required double amount,
    int accountId = 1,
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
      title: '${type.name} $amount',
      transactionDate: date ?? now,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<double> balanceOf(int id) async =>
      (await accounts.findById(id))!.currentBalance;

  setUp(setUpDatabase);

  test('income increases and expense decreases the account balance', () async {
    await transactions.insert(tx(type: TransactionType.income, amount: 1000));
    expect(await balanceOf(1), 1000);

    await transactions.insert(tx(type: TransactionType.expense, amount: 250));
    expect(await balanceOf(1), 750);
  });

  test('deleting a transaction reverses its balance effect', () async {
    final id =
        await transactions.insert(tx(type: TransactionType.income, amount: 500));
    expect(await balanceOf(1), 500);

    await transactions.delete(id);
    expect(await balanceOf(1), 0);
  });

  test('editing an amount reverses the old value before applying the new',
      () async {
    final id = await transactions.insert(
      tx(type: TransactionType.expense, amount: 100),
    );
    expect(await balanceOf(1), -100);

    final stored = (await transactions.findById(id))!;
    await transactions.update(stored.copyWith(amount: 30));
    expect(await balanceOf(1), -30);
  });

  test('changing a transaction type moves the balance both ways', () async {
    final id = await transactions.insert(
      tx(type: TransactionType.expense, amount: 200),
    );
    final stored = (await transactions.findById(id))!;

    await transactions.update(stored.copyWith(type: TransactionType.income));
    expect(await balanceOf(1), 200);
  });

  test('moving a transaction to another account rebalances both', () async {
    final now = DateTime.now();
    final secondId = await accounts.insert(
      Account(
        id: 0,
        name: 'Bank',
        type: AccountType.bank,
        openingBalance: 0,
        currentBalance: 0,
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final id = await transactions.insert(
      tx(type: TransactionType.expense, amount: 75),
    );
    expect(await balanceOf(1), -75);

    final stored = (await transactions.findById(id))!;
    await transactions.update(stored.copyWith(accountId: secondId));

    expect(await balanceOf(1), 0);
    expect(await balanceOf(secondId), -75);
  });

  test('a transfer debits the source and credits the destination', () async {
    final now = DateTime.now();
    final secondId = await accounts.insert(
      Account(
        id: 0,
        name: 'Savings',
        type: AccountType.savings,
        openingBalance: 100,
        currentBalance: 100,
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await transactions.insert(
      tx(type: TransactionType.transfer, amount: 40, toAccountId: secondId),
    );

    expect(await balanceOf(1), -40);
    expect(await balanceOf(secondId), 140);
  });

  test('recalculateAll reproduces the incrementally maintained balances',
      () async {
    await transactions.insert(tx(type: TransactionType.income, amount: 900));
    await transactions.insert(tx(type: TransactionType.expense, amount: 120.5));
    await transactions.insert(tx(type: TransactionType.expense, amount: 79.5));

    final incremental = await balanceOf(1);
    await accounts.recalculateAll();

    expect(await balanceOf(1), incremental);
    expect(incremental, 700);
  });

  test('search escapes LIKE wildcards typed by the user', () async {
    final now = DateTime.now();
    await transactions.insert(
      MoneyTransaction(
        id: 0,
        accountId: 1,
        type: TransactionType.expense,
        amount: 10,
        title: '100% cotton shirt',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await transactions.insert(tx(type: TransactionType.expense, amount: 20));

    final matches = await transactions.find(
      filter: const TransactionFilter(search: '100%'),
    );
    expect(matches, hasLength(1));
    expect(matches.first.title, '100% cotton shirt');
  });
}
