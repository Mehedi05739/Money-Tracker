import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/core/utils/date_utils.dart';
import 'package:money_tracker/core/enums/account_type.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/analytics_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/domain/entities/account.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';

import '../helpers/test_database.dart';

void main() {
  late AnalyticsDao analytics;
  late TransactionDao transactions;
  late AccountDao accounts;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    analytics = AnalyticsDao(database.db);
    transactions = TransactionDao(database.db);
    accounts = AccountDao(database.db);
  });

  Future<void> add({
    required TransactionType type,
    required double amount,
    required DateTime date,
    int? categoryId,
    int? toAccountId,
  }) async {
    final now = DateTime.now();
    await transactions.insert(
      MoneyTransaction(
        id: 0,
        accountId: 1,
        toAccountId: toAccountId,
        type: type,
        amount: amount,
        categoryId: categoryId,
        title: 'x',
        transactionDate: date,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  DateRange thisMonth() => DateRange.fromPreset(DateRangePreset.thisMonth);

  test('totals sum income and expense inside the range only', () async {
    final now = DateTime.now();
    await add(type: TransactionType.income, amount: 3000, date: now);
    await add(type: TransactionType.expense, amount: 400, date: now);
    await add(type: TransactionType.expense, amount: 100, date: now);

    // Well outside the current month.
    await add(
      type: TransactionType.expense,
      amount: 9999,
      date: AppDate.addMonths(now, -4),
    );

    final totals = await analytics.totals(thisMonth());

    expect(totals.income, 3000);
    expect(totals.expense, 500);
    expect(totals.netSavings, 2500);
    expect(totals.transactionCount, 3);
  });

  test('savings rate is the share of income kept', () async {
    final now = DateTime.now();
    await add(type: TransactionType.income, amount: 1000, date: now);
    await add(type: TransactionType.expense, amount: 250, date: now);

    final totals = await analytics.totals(thisMonth());
    expect(totals.savingsRate, 75);
  });

  test('savings rate is zero when there is no income', () async {
    await add(
      type: TransactionType.expense,
      amount: 80,
      date: DateTime.now(),
    );

    final totals = await analytics.totals(thisMonth());
    expect(totals.savingsRate, 0);
    expect(totals.netSavings, -80);
  });

  test('transfers are excluded from income and expense totals', () async {
    final now = DateTime.now();
    final second = await accounts.insert(
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

    await add(type: TransactionType.income, amount: 500, date: now);
    await add(
      type: TransactionType.transfer,
      amount: 200,
      date: now,
      toAccountId: second,
    );

    final totals = await analytics.totals(thisMonth());

    expect(totals.income, 500);
    expect(totals.expense, 0, reason: 'a transfer is not spending');
    expect(totals.netSavings, 500);
  });

  test('category breakdown ranks by amount and computes shares', () async {
    final now = DateTime.now();
    await add(type: TransactionType.expense, amount: 300, date: now, categoryId: 1);
    await add(type: TransactionType.expense, amount: 100, date: now, categoryId: 1);
    await add(type: TransactionType.expense, amount: 100, date: now, categoryId: 2);

    final breakdown = await analytics.categoryBreakdown(thisMonth());

    expect(breakdown, hasLength(2));
    expect(breakdown.first.amount, 400);
    expect(breakdown.first.transactionCount, 2);
    expect(breakdown.first.share, closeTo(80, 0.001));
    expect(breakdown.last.share, closeTo(20, 0.001));
  });

  test('daily trend returns one point per day with data', () async {
    final today = AppDate.startOfDay(DateTime.now());
    await add(type: TransactionType.expense, amount: 20, date: today);
    await add(
      type: TransactionType.expense,
      amount: 30,
      date: today.subtract(const Duration(days: 1)),
    );

    final trend = await analytics.dailyTrend(thisMonth());
    final withData = trend.where((point) => point.expense > 0).toList();

    expect(withData.length, greaterThanOrEqualTo(1));
    expect(
      withData.fold<double>(0, (sum, point) => sum + point.expense),
      lessThanOrEqualTo(50),
    );
  });

  test('fillDailyGaps produces a continuous axis', () async {
    final range = DateRange.custom(
      DateTime.now().subtract(const Duration(days: 6)),
      DateTime.now(),
    );
    await add(type: TransactionType.expense, amount: 15, date: DateTime.now());

    final filled = AnalyticsDao.fillDailyGaps(
      await analytics.dailyTrend(range),
      range,
    );

    expect(filled, hasLength(7));
    expect(filled.where((point) => point.expense == 0).length, 6);
  });

  test('fillDailyGaps stops at today rather than padding the future', () async {
    final now = DateTime.now();
    final range = DateRange(
      start: AppDate.startOfDay(now).subtract(const Duration(days: 2)),
      end: AppDate.endOfDay(now).add(const Duration(days: 20)),
    );
    await add(type: TransactionType.expense, amount: 10, date: now);

    final filled = AnalyticsDao.fillDailyGaps(
      await analytics.dailyTrend(range),
      range,
    );

    expect(filled, hasLength(3), reason: 'two days back, plus today');
    expect(filled.last.expense, 10);
    expect(
      filled.every((point) => !AppDate.startOfDay(point.date)
          .isAfter(AppDate.startOfDay(now))),
      isTrue,
    );
  });

  test('spendOnDay counts only that day', () async {
    final today = DateTime.now();
    await add(type: TransactionType.expense, amount: 45, date: today);
    await add(
      type: TransactionType.expense,
      amount: 500,
      date: today.subtract(const Duration(days: 3)),
    );

    expect(await analytics.spendOnDay(today), 45);
  });
}
