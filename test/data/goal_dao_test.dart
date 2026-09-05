import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/goal_status.dart';
import 'package:money_tracker/data/local/daos/goal_dao.dart';
import 'package:money_tracker/domain/entities/financial_goal.dart';

import '../helpers/test_database.dart';

void main() {
  late GoalDao goals;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    goals = GoalDao(database.db);
  });

  Future<int> addGoal({double target = 1000}) {
    final now = DateTime.now();
    return goals.insert(
      FinancialGoal(
        id: 0,
        name: 'Emergency Fund',
        targetAmount: target,
        currentAmount: 0,
        targetDate: now.add(const Duration(days: 90)),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> contribute(int goalId, double amount) async {
    final now = DateTime.now();
    await goals.addContribution(
      GoalContribution(
        id: 0,
        goalId: goalId,
        amount: amount,
        contributedAt: now,
        createdAt: now,
      ),
    );
  }

  test('contributions roll into the goal total', () async {
    final id = await addGoal();

    await contribute(id, 200);
    await contribute(id, 150);

    final goal = await goals.findById(id);
    expect(goal!.currentAmount, 350);
    expect(goal.remainingAmount, 650);
    expect(goal.progressPercent, 35);
  });

  test('a withdrawal reduces the total', () async {
    final id = await addGoal();
    await contribute(id, 500);
    await contribute(id, -120);

    expect((await goals.findById(id))!.currentAmount, 380);
  });

  test('reaching the target marks the goal achieved', () async {
    final id = await addGoal(target: 500);
    await contribute(id, 500);

    final goal = await goals.findById(id);
    expect(goal!.status, GoalStatus.achieved);
    expect(goal.isAchieved, isTrue);
    expect(goal.progressPercent, 100);
  });

  test('dropping back below the target reopens the goal', () async {
    final id = await addGoal(target: 500);
    await contribute(id, 500);
    expect((await goals.findById(id))!.status, GoalStatus.achieved);

    await contribute(id, -100);
    expect((await goals.findById(id))!.status, GoalStatus.active);
  });

  test('deleting a contribution recomputes the total from history', () async {
    final id = await addGoal();
    await contribute(id, 300);
    await contribute(id, 200);

    final history = await goals.findContributions(id);
    await goals.deleteContribution(history.first.id);

    final goal = await goals.findById(id);
    expect(goal!.currentAmount, 300);
    expect(await goals.findContributions(id), hasLength(1));
  });

  test('progress is capped at 100 percent when over-funded', () async {
    final id = await addGoal(target: 100);
    await contribute(id, 250);

    final goal = await goals.findById(id);
    expect(goal!.currentAmount, 250);
    expect(goal.progressPercent, 100);
    expect(goal.remainingAmount, 0);
  });

  test('an editable goal keeps its derived current amount', () async {
    final id = await addGoal(target: 1000);
    await contribute(id, 400);

    final goal = (await goals.findById(id))!;
    await goals.update(goal.copyWith(name: 'Renamed', targetAmount: 2000));

    final reloaded = (await goals.findById(id))!;
    expect(reloaded.name, 'Renamed');
    expect(reloaded.targetAmount, 2000);
    expect(reloaded.currentAmount, 400, reason: 'owned by the ledger');
  });
}
