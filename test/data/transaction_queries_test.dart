import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/account_type.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/core/utils/date_utils.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/data/repositories/transaction_repository_impl.dart';
import 'package:money_tracker/domain/entities/account.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/repositories/transaction_repository.dart';

import '../helpers/test_database.dart';

/// The named query and aggregate methods, against the real schema.
void main() {
  late TransactionRepository repository;
  late AccountDao accounts;
  late int savingsId;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    repository = TransactionRepositoryImpl(TransactionDao(database.db));
    accounts = AccountDao(database.db);

    final now = DateTime.now();
    savingsId = await accounts.insert(
      Account(
        id: 0,
        name: 'Savings',
        type: AccountType.savings,
        openingBalance: 0,
        currentBalance: 0,
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  Future<void> add({
    required TransactionType type,
    required double amount,
    required DateTime date,
    int accountId = 1,
    int? toAccountId,
    int? categoryId = 1,
  }) async {
    final now = DateTime.now();
    final result = await repository.create(
      MoneyTransaction(
        id: 0,
        accountId: accountId,
        toAccountId: toAccountId,
        type: type,
        amount: amount,
        categoryId: type.isTransfer ? null : categoryId,
        title: '${type.name} $amount',
        transactionDate: date,
        createdAt: now,
        updatedAt: now,
      ),
    );
    expect(result.isSuccess, isTrue, reason: '${result.failureOrNull}');
  }

  group('period queries', () {
    test('today returns only today', () async {
      final now = DateTime.now();
      await add(type: TransactionType.expense, amount: 10, date: now);
      await add(
        type: TransactionType.expense,
        amount: 99,
        date: now.subtract(const Duration(days: 3)),
      );

      final today = await repository.getToday();
      expect(today.dataOrNull, hasLength(1));
      expect(today.dataOrNull!.single.amount, 10);
    });

    test('this week includes earlier days of the same week', () async {
      final now = DateTime.now();
      final weekStart = AppDate.startOfWeek(now);
      await add(type: TransactionType.expense, amount: 10, date: now);
      await add(
        type: TransactionType.expense,
        amount: 20,
        date: weekStart.add(const Duration(hours: 9)),
      );
      // Firmly outside the week.
      await add(
        type: TransactionType.expense,
        amount: 99,
        date: weekStart.subtract(const Duration(days: 2)),
      );

      final week = await repository.getThisWeek();
      final amounts = week.dataOrNull!.map((t) => t.amount).toSet();
      expect(amounts, isNot(contains(99)));
      expect(amounts, containsAll(<double>[10, 20]));
    });

    test('this month excludes a prior month', () async {
      final now = DateTime.now();
      await add(type: TransactionType.expense, amount: 10, date: now);
      await add(
        type: TransactionType.expense,
        amount: 99,
        date: AppDate.addMonths(now, -2),
      );

      final month = await repository.getThisMonth();
      expect(month.dataOrNull, hasLength(1));
    });

    test('an explicit date range is inclusive of both ends', () async {
      final start = DateTime(2026, 3, 10);
      final end = DateTime(2026, 3, 12);
      await add(type: TransactionType.expense, amount: 1, date: start);
      await add(type: TransactionType.expense, amount: 2, date: end);
      await add(
        type: TransactionType.expense,
        amount: 99,
        date: DateTime(2026, 3, 13),
      );

      final ranged = await repository.getByDateRange(
        DateRange.custom(start, end),
      );
      expect(ranged.dataOrNull, hasLength(2));
    });
  });

  group('dimension queries', () {
    test('by category', () async {
      final now = DateTime.now();
      await add(
        type: TransactionType.expense,
        amount: 10,
        date: now,
        categoryId: 1,
      );
      await add(
        type: TransactionType.expense,
        amount: 20,
        date: now,
        categoryId: 2,
      );

      final result = await repository.getByCategory(2);
      expect(result.dataOrNull, hasLength(1));
      expect(result.dataOrNull!.single.amount, 20);
    });

    test('by account also matches a transfer destination', () async {
      final now = DateTime.now();
      await add(type: TransactionType.expense, amount: 10, date: now);
      await add(
        type: TransactionType.transfer,
        amount: 30,
        date: now,
        toAccountId: savingsId,
      );

      final result = await repository.getByAccount(savingsId);
      expect(result.dataOrNull, hasLength(1));
      expect(result.dataOrNull!.single.isTransfer, isTrue);
    });

    test('income, expenses and transfers are separable', () async {
      final now = DateTime.now();
      await add(type: TransactionType.income, amount: 500, date: now);
      await add(type: TransactionType.expense, amount: 40, date: now);
      await add(
        type: TransactionType.transfer,
        amount: 30,
        date: now,
        toAccountId: savingsId,
      );

      expect((await repository.getIncome()).dataOrNull, hasLength(1));
      expect((await repository.getExpenses()).dataOrNull, hasLength(1));
      expect((await repository.getTransfers()).dataOrNull, hasLength(1));
    });
  });

  group('aggregates', () {
    test('totals split by type and exclude transfers from net', () async {
      final now = DateTime.now();
      await add(type: TransactionType.income, amount: 1000, date: now);
      await add(type: TransactionType.expense, amount: 250, date: now);
      await add(
        type: TransactionType.transfer,
        amount: 400,
        date: now,
        toAccountId: savingsId,
      );

      final totals = (await repository.getTotals()).dataOrNull!;

      expect(totals.income, 1000);
      expect(totals.expense, 250);
      expect(totals.transfer, 400);
      expect(totals.net, 750, reason: 'a transfer moves no net worth');
      expect(totals.savingsRate, 75);
      expect(totals.count, 3);
    });

    test('total income and expenses honour a date range', () async {
      final now = DateTime.now();
      await add(type: TransactionType.income, amount: 100, date: now);
      await add(type: TransactionType.expense, amount: 60, date: now);
      await add(
        type: TransactionType.income,
        amount: 999,
        date: AppDate.addMonths(now, -3),
      );

      final range = DateRange.fromPreset(DateRangePreset.thisMonth);
      expect((await repository.getTotalIncome(range: range)).dataOrNull, 100);
      expect((await repository.getTotalExpenses(range: range)).dataOrNull, 60);
    });

    test('aggregates compose with the filter the list uses', () async {
      final now = DateTime.now();
      await add(
        type: TransactionType.expense,
        amount: 30,
        date: now,
        categoryId: 1,
      );
      await add(
        type: TransactionType.expense,
        amount: 70,
        date: now,
        categoryId: 2,
      );

      final scoped = await repository.getTotalExpenses(
        base: const TransactionFilter(categoryIds: {2}),
      );
      expect(scoped.dataOrNull, 70);
    });

    test('category spending shares add up to 100', () async {
      final now = DateTime.now();
      await add(
        type: TransactionType.expense,
        amount: 75,
        date: now,
        categoryId: 1,
      );
      await add(
        type: TransactionType.expense,
        amount: 25,
        date: now,
        categoryId: 2,
      );

      final spending = (await repository.getCategorySpending()).dataOrNull!;

      expect(spending, hasLength(2));
      expect(spending.first.amount, 75);
      expect(spending.first.share, closeTo(75, 0.001));
      expect(
        spending.fold<double>(0, (sum, e) => sum + e.share),
        closeTo(100, 0.001),
      );
    });

    test(
      'daily spending returns one point per active day, oldest first',
      () async {
        final today = AppDate.startOfDay(DateTime.now());
        await add(type: TransactionType.expense, amount: 10, date: today);
        await add(type: TransactionType.expense, amount: 5, date: today);
        await add(
          type: TransactionType.expense,
          amount: 20,
          date: today.subtract(const Duration(days: 1)),
        );

        final daily = (await repository.getDailySpending()).dataOrNull!;

        expect(daily, hasLength(2));
        expect(daily.first.date.isBefore(daily.last.date), isTrue);
        expect(daily.last.expense, 15, reason: 'same-day rows are summed');
      },
    );

    test('empty results are empty, not an error', () async {
      final totals = await repository.getTotals();
      final spending = await repository.getCategorySpending();
      final daily = await repository.getDailySpending();

      expect(totals.dataOrNull!.isEmpty, isTrue);
      expect(totals.dataOrNull!.savingsRate, 0, reason: 'no divide by zero');
      expect(spending.dataOrNull, isEmpty);
      expect(daily.dataOrNull, isEmpty);
    });
  });
}
