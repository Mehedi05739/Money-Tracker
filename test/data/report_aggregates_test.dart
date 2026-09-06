import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/account_type.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/enums/trend_granularity.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/data/local/daos/account_dao.dart';
import 'package:money_tracker/data/local/daos/analytics_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/data/repositories/analytics_repository_impl.dart';
import 'package:money_tracker/domain/entities/account.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';

import '../helpers/test_database.dart';

void main() {
  late AnalyticsDao analytics;
  late AnalyticsRepositoryImpl repository;
  late TransactionDao transactions;
  late AccountDao accounts;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    analytics = AnalyticsDao(database.db);
    transactions = TransactionDao(database.db);
    accounts = AccountDao(database.db);
    repository = AnalyticsRepositoryImpl(analytics, accounts);
  });

  Future<int> addAccount(String name) async {
    final now = DateTime.now();
    return accounts.insert(
      Account(
        id: 0,
        name: name,
        type: AccountType.cash,
        openingBalance: 0,
        currentBalance: 0,
        currency: 'BDT',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> add({
    required TransactionType type,
    required double amount,
    required DateTime date,
    int accountId = 1,
    int? toAccountId,
  }) async {
    final now = DateTime.now();
    await transactions.insert(
      MoneyTransaction(
        id: 0,
        accountId: accountId,
        toAccountId: toAccountId,
        type: type,
        amount: amount,
        title: 'x',
        transactionDate: date,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  DateRange thisMonth() => DateRange.fromPreset(DateRangePreset.thisMonth);

  /// A day safely inside the current month, whatever today is.
  DateTime dayOfMonth(int day) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, day, 12);
  }

  group('rolling presets', () {
    test('cover exactly the number of days they name', () {
      expect(DateRange.fromPreset(DateRangePreset.last7Days).dayCount, 7);
      expect(DateRange.fromPreset(DateRangePreset.last30Days).dayCount, 30);
    });

    test('end today and include today', () {
      final range = DateRange.fromPreset(DateRangePreset.last7Days);
      expect(range.contains(DateTime.now()), isTrue);
    });

    test('month windows span whole months, not months plus a day', () {
      final now = DateTime(2026, 9, 6, 12);
      final quarter = DateRange.fromPreset(
        DateRangePreset.last3Months,
        now: now,
      );
      // 6 Jun is the day the window starts; 6 Mar belongs to the one before.
      expect(quarter.start.month, 6);
      expect(quarter.start.day, 7);
      expect(quarter.end.month, 9);
      expect(quarter.end.day, 6);
    });

    test('carry a readable label', () {
      expect(DateRangePreset.last3Months.label, '3 months');
      expect(DateRangePreset.lastYear.label, '1 year');
    });
  });

  group('account breakdown', () {
    test('groups spending by the account it left', () async {
      final second = await addAccount('Bank');
      await add(
        type: TransactionType.expense,
        amount: 300,
        date: dayOfMonth(3),
      );
      await add(
        type: TransactionType.expense,
        amount: 100,
        date: dayOfMonth(4),
      );
      await add(
        type: TransactionType.expense,
        amount: 100,
        date: dayOfMonth(5),
        accountId: second,
      );

      final breakdown = await analytics.accountBreakdown(thisMonth());

      expect(breakdown.total, 500);
      expect(breakdown.entries, hasLength(2));
      // Ranked by spend, so the heaviest account leads.
      expect(breakdown.top!.amount, 400);
      expect(breakdown.top!.share, closeTo(80, 0.01));
      expect(breakdown.entries.last.share, closeTo(20, 0.01));
    });

    test('excludes income and transfers', () async {
      final second = await addAccount('Bank');
      await add(
        type: TransactionType.expense,
        amount: 100,
        date: dayOfMonth(3),
      );
      await add(
        type: TransactionType.income,
        amount: 5000,
        date: dayOfMonth(3),
      );
      await add(
        type: TransactionType.transfer,
        amount: 900,
        date: dayOfMonth(4),
        toAccountId: second,
      );

      final breakdown = await analytics.accountBreakdown(thisMonth());

      expect(breakdown.total, 100, reason: 'only the expense is spending');
      expect(breakdown.entries.single.transactionCount, 1);
    });

    test(
      'shares stay relative to the full total when the list is capped',
      () async {
        for (var i = 0; i < 4; i++) {
          final id = await addAccount('A$i');
          await add(
            type: TransactionType.expense,
            amount: 100,
            date: dayOfMonth(3),
            accountId: id,
          );
        }

        final breakdown = await analytics.accountBreakdown(
          thisMonth(),
          limit: 2,
        );

        expect(breakdown.entries, hasLength(2));
        expect(
          breakdown.total,
          400,
          reason: 'the denominator is every account',
        );
        expect(breakdown.top!.share, closeTo(25, 0.01));
      },
    );
  });

  group('highest spending day', () {
    test('returns the heaviest day, summing that day', () async {
      await add(
        type: TransactionType.expense,
        amount: 100,
        date: dayOfMonth(3),
      );
      await add(
        type: TransactionType.expense,
        amount: 250,
        date: dayOfMonth(5),
      );
      await add(type: TransactionType.expense, amount: 60, date: dayOfMonth(5));
      await add(
        type: TransactionType.expense,
        amount: 200,
        date: dayOfMonth(9),
      );

      final day = await analytics.highestSpendingDay(thisMonth());

      expect(day, isNotNull);
      expect(day!.amount, 310, reason: 'the 5th sums to 250 + 60');
      expect(day.date.day, 5);
      expect(day.transactionCount, 2);
    });

    test('ignores income', () async {
      await add(
        type: TransactionType.income,
        amount: 9000,
        date: dayOfMonth(3),
      );
      await add(type: TransactionType.expense, amount: 50, date: dayOfMonth(7));

      final day = await analytics.highestSpendingDay(thisMonth());

      expect(day!.date.day, 7);
      expect(day.amount, 50);
    });

    test('is null when nothing was spent', () async {
      await add(type: TransactionType.income, amount: 100, date: dayOfMonth(3));
      expect(await analytics.highestSpendingDay(thisMonth()), isNull);
    });
  });

  group('report snapshot', () {
    test('carries a running savings balance across the period', () async {
      await add(type: TransactionType.income, amount: 500, date: dayOfMonth(1));
      await add(
        type: TransactionType.expense,
        amount: 200,
        date: dayOfMonth(2),
      );
      await add(
        type: TransactionType.expense,
        amount: 100,
        date: dayOfMonth(3),
      );

      final snapshot = (await repository.getReportSnapshot(
        thisMonth(),
        granularity: TrendGranularity.daily,
      )).dataOrNull!;

      final savings = snapshot.savingsTrend;
      expect(savings.length, greaterThanOrEqualTo(3));
      expect(savings[0].cumulative, 500);
      expect(savings[1].cumulative, 300, reason: '500 in, then 200 out');
      expect(savings[2].cumulative, 200);
      // The line ends where the period totals say it should.
      expect(snapshot.closingSavings, snapshot.totals.netSavings);
    });

    test('assembles every report from one call', () async {
      await add(type: TransactionType.income, amount: 800, date: dayOfMonth(2));
      await add(
        type: TransactionType.expense,
        amount: 300,
        date: dayOfMonth(4),
      );

      final snapshot = (await repository.getReportSnapshot(thisMonth()))
          .dataOrNull!;

      expect(snapshot.totals.income, 800);
      expect(snapshot.totals.expense, 300);
      expect(snapshot.totals.netSavings, 500);
      expect(snapshot.highestDay!.amount, 300);
      expect(snapshot.accountBreakdown.total, 300);
      expect(snapshot.categoryBreakdown.total, 300);
      expect(snapshot.isEmpty, isFalse);
    });

    test('monthly granularity buckets by month', () async {
      final now = DateTime.now();
      await add(type: TransactionType.expense, amount: 100, date: now);

      final year = DateRange.fromPreset(DateRangePreset.lastYear);
      final snapshot = (await repository.getReportSnapshot(
        year,
        granularity: TrendGranularity.monthly,
      )).dataOrNull!;

      expect(snapshot.granularity, TrendGranularity.monthly);
      expect(snapshot.trend, hasLength(1), reason: 'one month had data');
    });

    test('an empty period reports empty rather than failing', () async {
      final snapshot = (await repository.getReportSnapshot(thisMonth()))
          .dataOrNull!;

      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.highestDay, isNull);
      expect(snapshot.accountBreakdown.isEmpty, isTrue);
      expect(snapshot.savingsTrend.every((p) => p.cumulative == 0), isTrue);
    });
  });
}
