import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/db_tables.dart';
import 'package:money_tracker/core/enums/account_type.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/data/local/account_balance.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/domain/entities/account.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';

import '../helpers/test_database.dart';

/// Balances are maintained incrementally as rows are written and rebuilt in
/// bulk by `recalculateAll`. Those are two renderings of one rule, and the
/// dangerous failure is them disagreeing: the repair path would then be the
/// thing that corrupts the ledger. These tests hold them to each other.
void main() {
  late AccountDao accounts;
  late TransactionDao transactions;
  late dynamic db;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    db = database.db;
    accounts = AccountDao(database.db);
    transactions = TransactionDao(database.db);
  });

  Future<int> addAccount(String name, {double opening = 0}) {
    final now = DateTime.now();
    return accounts.insert(
      Account(
        id: 0,
        name: name,
        type: AccountType.cash,
        openingBalance: opening,
        currentBalance: opening,
        currency: 'BDT',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> add({
    required TransactionType type,
    required double amount,
    int accountId = 1,
    int? toAccountId,
  }) {
    final now = DateTime.now();
    return transactions.insert(
      MoneyTransaction(
        id: 0,
        accountId: accountId,
        toAccountId: toAccountId,
        type: type,
        amount: amount,
        title: 'x',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<double> balanceOf(int id) async => accounts.balanceOf(id);

  Future<Map<int, double>> allBalances() async {
    final rows = await db.query(Tables.accounts);
    return {
      for (final row in rows)
        row[AccountColumns.id]! as int:
            (row[AccountColumns.currentBalance]! as num).toDouble(),
    };
  }

  group('the two balance paths agree', () {
    test('across every transaction type, transfers included', () async {
      final bank = await addAccount('Bank', opening: 1000);
      await add(type: TransactionType.income, amount: 900);
      await add(type: TransactionType.expense, amount: 120.5);
      await add(type: TransactionType.transfer, amount: 200, toAccountId: bank);
      await add(
        type: TransactionType.transfer,
        amount: 50,
        accountId: bank,
        toAccountId: 1,
      );

      final incremental = await allBalances();
      await accounts.recalculateAll();

      expect(await allBalances(), incremental);
    });

    test('after an edit and a delete', () async {
      final bank = await addAccount('Bank');
      await add(type: TransactionType.income, amount: 500);
      final transferId = await add(
        type: TransactionType.transfer,
        amount: 200,
        toAccountId: bank,
      );
      final expenseId = await add(type: TransactionType.expense, amount: 75);

      // Re-point the transfer at a different amount, then remove the expense.
      final stored = await transactions.findById(transferId);
      await transactions.update(stored!.copyWith(amount: 250));
      await transactions.delete(expenseId);

      final incremental = await allBalances();
      await accounts.recalculateAll();

      expect(await allBalances(), incremental);
    });

    test('recalculating twice is idempotent', () async {
      final bank = await addAccount('Bank');
      await add(type: TransactionType.income, amount: 400);
      await add(type: TransactionType.transfer, amount: 150, toAccountId: bank);

      await accounts.recalculateAll();
      final once = await allBalances();
      await accounts.recalculateAll();

      expect(await allBalances(), once);
    });
  });

  group('generated SQL', () {
    test('covers every transaction type', () {
      final sql = AccountBalance.sourceDeltaSql();
      for (final type in TransactionType.values) {
        expect(
          sql,
          contains("WHEN '${type.name}'"),
          reason: '${type.name} has no arm, so it would sum as NULL',
        );
      }
    });

    test('signs match balanceSign', () {
      final sql = AccountBalance.sourceDeltaSql();
      expect(sql, contains("WHEN 'income' THEN t.amount"));
      expect(sql, contains("WHEN 'expense' THEN -t.amount"));
      expect(sql, contains("WHEN 'transfer' THEN -t.amount"));
    });
  });

  group('transfer: Bank to Cash', () {
    test('moves the money and counts as neither income nor expense', () async {
      // The brief's example, with the accounts the app seeds.
      final cash = 1;
      final bank = await addAccount('Bank', opening: 1000);

      await add(
        type: TransactionType.transfer,
        amount: 200,
        accountId: bank,
        toAccountId: cash,
      );

      expect(await balanceOf(bank), 800, reason: 'source decreases');
      expect(await balanceOf(cash), 200, reason: 'destination increases');

      // Net worth is unchanged: a transfer creates and destroys nothing.
      final total = await accounts.totalBalance();
      expect(total, 1000);

      // And it is invisible to the income/expense aggregates.
      final rows = await db.rawQuery(
        "SELECT COALESCE(SUM(CASE WHEN type = 'income' THEN amount END), 0) AS income, "
        "COALESCE(SUM(CASE WHEN type = 'expense' THEN amount END), 0) AS expense "
        'FROM transactions',
      );
      expect((rows.first['income']! as num).toDouble(), 0);
      expect((rows.first['expense']! as num).toDouble(), 0);
    });

    test('is atomic — a failed transfer moves neither balance', () async {
      final bank = await addAccount('Bank', opening: 1000);
      final before = await allBalances();

      // A transfer to a non-existent account violates the foreign key, so the
      // whole SQL transaction — row and both balance updates — rolls back.
      await expectLater(
        add(
          type: TransactionType.transfer,
          amount: 200,
          accountId: bank,
          toAccountId: 9999,
        ),
        throwsA(anything),
      );

      expect(await allBalances(), before, reason: 'nothing moved');
      final rows = await db.query(Tables.transactions);
      expect(rows, isEmpty, reason: 'no half-written transfer');
    });

    test('reversing a transfer restores both balances exactly', () async {
      final bank = await addAccount('Bank', opening: 1000);
      final before = await allBalances();

      final id = await add(
        type: TransactionType.transfer,
        amount: 200,
        accountId: bank,
        toAccountId: 1,
      );
      await transactions.delete(id);

      expect(await allBalances(), before);
    });
  });

  group('deleting an account', () {
    test('reclassifies inbound transfers instead of orphaning them', () async {
      final bank = await addAccount('Bank', opening: 1000);
      await add(
        type: TransactionType.transfer,
        amount: 200,
        accountId: bank,
        toAccountId: 1,
      );
      expect(await balanceOf(bank), 800);

      await accounts.delete(1);

      // The Bank row survives, still debited by the same 200 — the money did
      // leave, and the balance must not silently jump back up.
      expect(await balanceOf(bank), 800);

      final rows = await db.query(Tables.transactions);
      expect(rows, hasLength(1));
      expect(rows.first[TransactionColumns.type], 'expense');
      expect(
        rows.first[TransactionColumns.toAccountId],
        isNull,
        reason: 'no transfer left pointing at a deleted account',
      );
    });

    test('leaves no transfer row without a destination', () async {
      final bank = await addAccount('Bank', opening: 500);
      await add(
        type: TransactionType.transfer,
        amount: 100,
        accountId: bank,
        toAccountId: 1,
      );

      await accounts.delete(1);

      final orphans = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM transactions "
        "WHERE type = 'transfer' AND to_account_id IS NULL",
      );
      expect(orphans.first['c'], 0);
    });

    test('the repair path still agrees afterwards', () async {
      final bank = await addAccount('Bank', opening: 1000);
      await add(type: TransactionType.expense, amount: 50, accountId: bank);
      await add(
        type: TransactionType.transfer,
        amount: 200,
        accountId: bank,
        toAccountId: 1,
      );

      await accounts.delete(1);
      final afterDelete = await allBalances();
      await accounts.recalculateAll();

      expect(
        await allBalances(),
        afterDelete,
        reason: 'a repair must not move balances a delete already settled',
      );
    });

    test('takes the account own transactions with it', () async {
      await addAccount('Bank');
      await add(type: TransactionType.expense, amount: 30);

      await accounts.delete(1);

      expect(await db.query(Tables.transactions), isEmpty);
    });
  });
}
