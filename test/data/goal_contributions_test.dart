import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/utils/date_utils.dart';
import 'package:money_tracker/data/local/daos/goal_dao.dart';
import 'package:money_tracker/data/repositories/goal_repository_impl.dart';
import 'package:money_tracker/domain/entities/financial_goal.dart';
import 'package:money_tracker/domain/repositories/goal_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late GoalRepository repository;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    repository = GoalRepositoryImpl(GoalDao(database.db));
  });

  Future<FinancialGoal> addGoal({
    double target = 1500,
    int daysAhead = 120,
  }) async {
    final now = DateTime.now();
    final result = await repository.create(
      FinancialGoal(
        id: 0,
        name: 'New Laptop',
        targetAmount: target,
        currentAmount: 0,
        targetDate: AppDate.startOfDay(now).add(Duration(days: daysAhead)),
        note: 'For work',
        createdAt: now,
        updatedAt: now,
      ),
    );
    return result.dataOrNull!;
  }

  Future<FinancialGoal> contribute(int goalId, double amount) async {
    final now = DateTime.now();
    final result = await repository.addContribution(
      GoalContribution(
        id: 0,
        goalId: goalId,
        amount: amount,
        contributedAt: now,
        createdAt: now,
      ),
    );
    expect(result.isSuccess, isTrue, reason: '${result.failureOrNull}');
    return result.dataOrNull!;
  }

  group('the brief\'s example', () {
    test('reports saved, remaining and the monthly rate', () async {
      final goal = await addGoal(target: 1500, daysAhead: 120);
      await contribute(goal.id, 700);

      final saved = (await repository.getById(goal.id)).dataOrNull!;

      expect(saved.currentAmount, 700);
      expect(saved.remainingAmount, 800);
      expect(saved.progressPercent, closeTo(46.67, 0.01));
      expect(saved.monthsRemaining, 4);
      expect(saved.requiredMonthlyContribution, 200, reason: '800 over 4');
    });

    test('also reports a weekly rate', () async {
      final goal = await addGoal(target: 1500, daysAhead: 70);
      await contribute(goal.id, 500);

      final saved = (await repository.getById(goal.id)).dataOrNull!;

      expect(saved.weeksRemaining, 10);
      expect(saved.requiredWeeklyContribution, 100, reason: '1000 over 10');
    });

    test('describes the time left in a readable unit', () async {
      expect((await addGoal(daysAhead: 120)).timeToTarget, '4 months');
      expect((await addGoal(daysAhead: 21)).timeToTarget, '3 weeks');
      expect((await addGoal(daysAhead: 5)).timeToTarget, '5 days');
      expect((await addGoal(daysAhead: 1)).timeToTarget, '1 day');
    });

    test('recommends no rate once the goal is met', () async {
      final goal = await addGoal(target: 500);
      await contribute(goal.id, 500);

      final saved = (await repository.getById(goal.id)).dataOrNull!;

      expect(saved.isAchieved, isTrue);
      expect(saved.requiredMonthlyContribution, isNull);
      expect(saved.requiredWeeklyContribution, isNull);
    });

    test('recommends no rate when the date has passed', () async {
      // Creating a goal in the past is refused, so the date is moved back
      // afterwards — which is how a goal actually becomes overdue.
      final goal = await addGoal();
      await repository.update(
        goal.copyWith(
          targetDate: AppDate.startOfDay(DateTime.now())
              .subtract(const Duration(days: 5)),
        ),
      );
      final saved = (await repository.getById(goal.id)).dataOrNull!;

      expect(saved.isOverdue, isTrue);
      expect(saved.requiredMonthlyContribution, isNull);
      expect(saved.timeToTarget, 'Overdue');
    });
  });

  group('editing a contribution', () {
    test('changes the amount and the goal total together', () async {
      final goal = await addGoal();
      await contribute(goal.id, 700);

      final entry = (await repository.getContributions(goal.id))
          .dataOrNull!
          .single;
      final updated = await repository.updateContribution(
        entry.copyWith(amount: 900),
      );

      expect(updated.isSuccess, isTrue);
      expect(
        (await repository.getById(goal.id)).dataOrNull!.currentAmount,
        900,
      );
      expect(
        (await repository.getContributions(goal.id)).dataOrNull!.single.amount,
        900,
      );
    });

    test('keeps the history a single entry rather than adding one', () async {
      final goal = await addGoal();
      await contribute(goal.id, 100);

      final entry = (await repository.getContributions(goal.id))
          .dataOrNull!
          .single;
      await repository.updateContribution(entry.copyWith(amount: 250));

      expect(
        (await repository.getContributions(goal.id)).dataOrNull,
        hasLength(1),
      );
    });

    test('re-opens a goal when the edit drops it below target', () async {
      final goal = await addGoal(target: 500);
      await contribute(goal.id, 500);
      expect(
        (await repository.getById(goal.id)).dataOrNull!.isAchieved,
        isTrue,
      );

      final entry = (await repository.getContributions(goal.id))
          .dataOrNull!
          .single;
      await repository.updateContribution(entry.copyWith(amount: 200));

      final reopened = (await repository.getById(goal.id)).dataOrNull!;
      expect(reopened.isAchieved, isFalse);
      expect(reopened.currentAmount, 200);
    });

    test('rejects an edit that would take the goal below zero', () async {
      final goal = await addGoal();
      await contribute(goal.id, 100);
      await contribute(goal.id, -40);

      final withdrawal = (await repository.getContributions(goal.id))
          .dataOrNull!
          .firstWhere((entry) => entry.isWithdrawal);

      // 100 held, so a withdrawal beyond -100 must be refused.
      final result = await repository.updateContribution(
        withdrawal.copyWith(amount: -150),
      );

      expect(result.isError, isTrue);
      expect(
        (await repository.getById(goal.id)).dataOrNull!.currentAmount,
        60,
        reason: 'the rejected edit changed nothing',
      );
    });

    test(
      'measures a withdrawal edit against the total without itself',
      () async {
        final goal = await addGoal();
        await contribute(goal.id, 100);
        await contribute(goal.id, -40);

        final withdrawal = (await repository.getContributions(goal.id))
            .dataOrNull!
            .firstWhere((entry) => entry.isWithdrawal);

        // -90 is allowed against the 100 held, even though the current total is
        // only 60 because this same entry already removed 40.
        final result = await repository.updateContribution(
          withdrawal.copyWith(amount: -90),
        );

        expect(result.isSuccess, isTrue, reason: '${result.failureOrNull}');
        expect(
          (await repository.getById(goal.id)).dataOrNull!.currentAmount,
          10,
        );
      },
    );
  });

  group('history', () {
    test('is stored separately and survives goal edits', () async {
      final goal = await addGoal();
      await contribute(goal.id, 200);
      await contribute(goal.id, 300);

      await repository.update(
        goal.copyWith(name: 'Renamed', targetAmount: 2000),
      );

      final history = (await repository.getContributions(goal.id)).dataOrNull!;
      final reloaded = (await repository.getById(goal.id)).dataOrNull!;

      expect(history, hasLength(2));
      expect(reloaded.name, 'Renamed');
      expect(reloaded.targetAmount, 2000);
      expect(reloaded.currentAmount, 500, reason: 'derived from history');
    });

    test('deleting a goal removes its contributions', () async {
      final goal = await addGoal();
      await contribute(goal.id, 100);

      await repository.delete(goal.id);

      expect((await repository.getContributions(goal.id)).dataOrNull, isEmpty);
    });
  });
}
