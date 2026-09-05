import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/account_type.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/analytics_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/data/repositories/analytics_repository_impl.dart';
import 'package:money_tracker/domain/entities/account.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';

import '../helpers/test_database.dart';

/// The dashboard's headline figures, and their account scoping.
void main() {
  late AnalyticsDao analytics;
  late AnalyticsRepositoryImpl repository;
  late TransactionDao transactions;
  late int cardId;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    final accountDao = AccountDao(database.db);
    analytics = AnalyticsDao(database.db);
    transactions = TransactionDao(database.db);
    repository = AnalyticsRepositoryImpl(analytics, accountDao);

    final now = DateTime.now();
    cardId = await accountDao.insert(
      Account(
        id: 0,
        name: 'Card',
        type: AccountType.card,
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
    int categoryId = 1,
  }) async {
    final now = DateTime.now();
    await transactions.insert(
      MoneyTransaction(
        id: 0,
        accountId: accountId,
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

  group('combined totals', () {
    test(
      'one query returns the period, the previous period, today and month',
      () async {
        final now = DateTime.now();
        await add(type: TransactionType.income, amount: 1000, date: now);
        await add(type: TransactionType.expense, amount: 250, date: now);

        final totals = await analytics.dashboardTotals(thisMonth());

        expect(totals.current.income, 1000);
        expect(totals.current.expense, 250);
        expect(totals.current.transactionCount, 2);
        expect(totals.current.netSavings, 750);
        expect(totals.todaySpend, 250);
        expect(totals.monthSpend, 250);
      },
    );

    test(
      'the previous period is measured separately from the current one',
      () async {
        final now = DateTime.now();
        final range = DateRange.custom(
          now.subtract(const Duration(days: 2)),
          now,
        );

        await add(type: TransactionType.expense, amount: 30, date: now);
        // Inside the preceding window of equal length.
        await add(
          type: TransactionType.expense,
          amount: 90,
          date: now.subtract(const Duration(days: 4)),
        );

        final totals = await analytics.dashboardTotals(range);

        expect(totals.current.expense, 30);
        expect(totals.previous.expense, 90);
      },
    );

    test('transfers never count as income or expense', () async {
      final now = DateTime.now();
      await add(type: TransactionType.income, amount: 500, date: now);
      await transactions.insert(
        MoneyTransaction(
          id: 0,
          accountId: 1,
          toAccountId: cardId,
          type: TransactionType.transfer,
          amount: 200,
          title: 'move',
          transactionDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final totals = await analytics.dashboardTotals(thisMonth());

      expect(totals.current.income, 500);
      expect(totals.current.expense, 0);
    });

    test('an empty period yields zeros, not nulls', () async {
      final totals = await analytics.dashboardTotals(thisMonth());

      expect(totals.current.income, 0);
      expect(totals.current.expense, 0);
      expect(totals.current.savingsRate, 0);
      expect(totals.todaySpend, 0);
    });
  });

  group('account scoping', () {
    test('totals cover only the selected account', () async {
      final now = DateTime.now();
      await add(type: TransactionType.expense, amount: 40, date: now);
      await add(
        type: TransactionType.expense,
        amount: 60,
        date: now,
        accountId: cardId,
      );

      final all = await analytics.dashboardTotals(thisMonth());
      final card = await analytics.dashboardTotals(
        thisMonth(),
        accountId: cardId,
      );

      expect(all.current.expense, 100);
      expect(card.current.expense, 60);
      expect(card.todaySpend, 60);
    });

    test('the category breakdown is scoped too', () async {
      final now = DateTime.now();
      await add(
        type: TransactionType.expense,
        amount: 40,
        date: now,
        categoryId: 1,
      );
      await add(
        type: TransactionType.expense,
        amount: 60,
        date: now,
        accountId: cardId,
        categoryId: 2,
      );

      final card = await analytics.categoryBreakdown(
        thisMonth(),
        accountId: cardId,
      );

      expect(card.total, 60);
      expect(card.entries, hasLength(1));
      expect(card.entries.single.share, 100);
    });

    test('the trend is scoped too', () async {
      final now = DateTime.now();
      await add(type: TransactionType.expense, amount: 40, date: now);
      await add(
        type: TransactionType.expense,
        amount: 60,
        date: now,
        accountId: cardId,
      );

      final trend = await analytics.dailyTrend(thisMonth(), accountId: cardId);

      expect(trend.fold<double>(0, (sum, point) => sum + point.expense), 60);
    });

    test(
      'the summary reports the selected account and its own balance',
      () async {
        final now = DateTime.now();
        await add(
          type: TransactionType.expense,
          amount: 25,
          date: now,
          accountId: cardId,
        );

        final scoped = await repository.getDashboardSummary(
          thisMonth(),
          accountId: cardId,
        );
        final summary = scoped.dataOrNull!;

        expect(summary.isScopedToAccount, isTrue);
        expect(summary.accountName, 'Card');
        expect(summary.totalBalance, -25, reason: 'that account alone');
        expect(summary.totals.expense, 25);
      },
    );

    test('no account scope means every account', () async {
      final now = DateTime.now();
      await add(type: TransactionType.expense, amount: 40, date: now);
      await add(
        type: TransactionType.expense,
        amount: 60,
        date: now,
        accountId: cardId,
      );

      final summary = (await repository.getDashboardSummary(thisMonth()))
          .dataOrNull!;

      expect(summary.isScopedToAccount, isFalse);
      expect(summary.accountName, isNull);
      expect(summary.totals.expense, 100);
      expect(summary.totalBalance, -100);
    });
  });
}
