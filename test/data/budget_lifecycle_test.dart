import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/budget_period.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/core/utils/date_utils.dart';
import 'package:money_tracker/data/local/daos/budget_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/data/repositories/budget_repository_impl.dart';
import 'package:money_tracker/domain/entities/budget.dart';
import 'package:money_tracker/domain/entities/budget_status.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/repositories/budget_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late BudgetRepository repository;
  late BudgetDao dao;
  late TransactionDao transactions;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    dao = BudgetDao(database.db);
    transactions = TransactionDao(database.db);
    repository = BudgetRepositoryImpl(dao);
  });

  Future<Budget> addBudget({
    int? categoryId = 1,
    double amount = 300,
    BudgetPeriod period = BudgetPeriod.monthly,
    DateRange? range,
    bool isActive = true,
  }) async {
    final window = range ?? DateRange.fromPreset(DateRangePreset.thisMonth);
    final now = DateTime.now();
    final result = await repository.create(
      Budget(
        id: 0,
        categoryId: categoryId,
        amount: amount,
        period: period,
        startDate: window.start,
        endDate: window.end,
        isActive: isActive,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return result.dataOrNull!;
  }

  Future<void> spend(double amount, {int categoryId = 1}) async {
    final now = DateTime.now();
    await transactions.insert(
      MoneyTransaction(
        id: 0,
        accountId: 1,
        type: TransactionType.expense,
        amount: amount,
        categoryId: categoryId,
        title: 'spend',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<BudgetStatus> statusOf({bool includePaused = true}) async {
    final result = await repository.getStatuses(includePaused: includePaused);
    return result.dataOrNull!.first;
  }

  group('calculations from the brief', () {
    test(
      'reports spend, remaining, percentage, days left and daily amount',
      () async {
        // A ten-day window ending today+9, so days remaining is predictable.
        final start = AppDate.startOfDay(DateTime.now());
        final range = DateRange(
          start: start,
          end: AppDate.endOfDay(start.add(const Duration(days: 9))),
        );
        await addBudget(amount: 300, range: range);
        await spend(220);

        final status = await statusOf();

        expect(status.limit, 300);
        expect(status.spent, 220);
        expect(status.remaining, 80);
        expect(status.usagePercent, closeTo(73.33, 0.01));
        expect(status.daysRemaining, 10);
        expect(status.recommendedDailySpend, 8, reason: '80 over 10 days');
      },
    );

    test('recommends nothing once the budget is spent', () async {
      await addBudget(amount: 100);
      await spend(100);

      final status = await statusOf();

      expect(status.remaining, 0);
      expect(status.recommendedDailySpend, 0);
    });

    test('reports the overspend separately from remaining', () async {
      await addBudget(amount: 100);
      await spend(140);

      final status = await statusOf();

      expect(status.isExceeded, isTrue);
      expect(status.overspend, closeTo(40, 0.001));
      expect(status.remaining, closeTo(-40, 0.001));
      expect(status.usageFraction, 1.0, reason: 'the bar cannot overflow');
      expect(status.headline, 'Over budget');
    });

    test('days remaining never goes negative for a finished period', () async {
      final past = DateRange.custom(
        DateTime.now().subtract(const Duration(days: 40)),
        DateTime.now().subtract(const Duration(days: 10)),
      );
      await addBudget(range: past);

      final result = await repository.getStatuses(
        currentOnly: false,
        includePaused: true,
      );
      final status = result.dataOrNull!.first;

      expect(status.daysRemaining, 0);
      expect(status.isFinished, isTrue);
      expect(status.recommendedDailySpend, 0);
    });
  });

  group('pause and resume', () {
    test('pausing keeps the budget and its spend', () async {
      final budget = await addBudget(amount: 300);
      await spend(120);

      final paused = await repository.setActive(budget.id, false);
      expect(paused.isSuccess, isTrue);

      final status = await statusOf();
      expect(status.isPaused, isTrue);
      expect(status.spent, 120, reason: 'history is kept');
      expect(status.headline, 'Paused');
    });

    test('resuming restores it', () async {
      final budget = await addBudget();
      await repository.setActive(budget.id, false);
      await repository.setActive(budget.id, true);

      expect((await statusOf()).isPaused, isFalse);
    });

    test(
      'a paused budget is hidden from callers that do not ask for it',
      () async {
        final budget = await addBudget();
        await repository.setActive(budget.id, false);

        final forDashboard = await repository.getStatuses();
        final forBudgetsScreen = await repository.getStatuses(
          includePaused: true,
        );

        expect(forDashboard.dataOrNull, isEmpty, reason: 'raises no alerts');
        expect(forBudgetsScreen.dataOrNull, hasLength(1), reason: 'resumable');
      },
    );

    test('pausing does not disturb the amount or the period', () async {
      final budget = await addBudget(amount: 250);
      await repository.setActive(budget.id, false);

      final reloaded = (await repository.getById(budget.id)).dataOrNull!;

      expect(reloaded.amount, 250);
      expect(reloaded.startDate, budget.startDate);
      expect(reloaded.endDate, budget.endDate);
      expect(reloaded.isActive, isFalse);
    });
  });

  group('scope', () {
    test('an overall budget counts spending in every category', () async {
      await addBudget(categoryId: null, amount: 500);
      await spend(100, categoryId: 1);
      await spend(50, categoryId: 2);

      final status = await statusOf();

      expect(status.budget.isOverall, isTrue);
      expect(status.spent, 150);
      expect(status.budget.displayName, 'All expenses');
    });

    test('a weekly budget only counts its own week', () async {
      final now = DateTime.now();
      await addBudget(
        period: BudgetPeriod.weekly,
        amount: 200,
        range: DateRange(
          start: AppDate.startOfWeek(now),
          end: AppDate.endOfWeek(now),
        ),
      );
      await spend(60);

      final status = await statusOf();
      expect(status.spent, 60);
      expect(status.budget.period, BudgetPeriod.weekly);
    });
  });
}
