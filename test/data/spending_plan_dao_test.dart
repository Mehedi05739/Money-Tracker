import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/data/local/daos/spending_plan_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/entities/spending_plan.dart';

import '../helpers/test_database.dart';

void main() {
  late SpendingPlanDao plans;
  late TransactionDao transactions;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    plans = SpendingPlanDao(database.db);
    transactions = TransactionDao(database.db);
  });

  Future<SpendingPlan> addPlan({double limit = 1000}) async {
    final range = DateRange.fromPreset(DateRangePreset.thisMonth);
    final now = DateTime.now();
    final id = await plans.insert(
      SpendingPlan(
        id: 0,
        name: 'September',
        totalLimit: limit,
        startDate: range.start,
        endDate: range.end,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return (await plans.findById(id))!;
  }

  Future<void> allocate(int planId, int categoryId, double amount) async {
    final now = DateTime.now();
    await plans.upsertItem(
      SpendingPlanItem(
        id: 0,
        planId: planId,
        categoryId: categoryId,
        plannedAmount: amount,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> spend(double amount, int categoryId) async {
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

  test('tracks planned versus actual per category', () async {
    final plan = await addPlan();
    await allocate(plan.id, 1, 400);
    await allocate(plan.id, 2, 300);

    await spend(120, 1);
    await spend(350, 2);

    final progress = await plans.findProgress(plan);
    final first = progress.items.firstWhere((i) => i.item.categoryId == 1);
    final second = progress.items.firstWhere((i) => i.item.categoryId == 2);

    expect(first.spent, 120);
    expect(first.remaining, 280);
    expect(first.isExceeded, isFalse);

    expect(second.spent, 350);
    expect(second.isExceeded, isTrue);
    expect(progress.breachedItems, hasLength(1));
  });

  test('total spent includes categories with no allocation', () async {
    final plan = await addPlan(limit: 1000);
    await allocate(plan.id, 1, 400);

    await spend(100, 1);
    await spend(250, 5); // not allocated in the plan

    final progress = await plans.findProgress(plan);

    expect(progress.totalSpent, 350);
    expect(progress.totalPlanned, 400);
    expect(progress.unallocated, 600);
    expect(progress.remaining, 650);
  });

  test('detects allocations exceeding the plan limit', () async {
    final plan = await addPlan(limit: 500);
    await allocate(plan.id, 1, 300);
    await allocate(plan.id, 2, 400);

    final progress = await plans.findProgress(plan);

    expect(progress.totalPlanned, 700);
    expect(progress.isOverAllocated, isTrue);
    expect(progress.unallocated, -200);
  });

  test('flags the plan once total spending passes the limit', () async {
    final plan = await addPlan(limit: 200);
    await spend(260, 1);

    final progress = await plans.findProgress(plan);

    expect(progress.isExceeded, isTrue);
    expect(progress.usageFraction, 1.0);
    expect(progress.headline, 'Limit exceeded');
    expect(progress.safeDailyAllowance, 0);
  });

  test('re-allocating a category replaces the amount rather than adding a row',
      () async {
    final plan = await addPlan();
    await allocate(plan.id, 1, 100);

    final existing = (await plans.findItems(plan.id)).single;
    await plans.upsertItem(existing.copyWith(plannedAmount: 250));

    final items = await plans.findItems(plan.id);
    expect(items, hasLength(1));
    expect(items.single.plannedAmount, 250);
  });

  test('deleting a plan removes its allocations', () async {
    final plan = await addPlan();
    await allocate(plan.id, 1, 100);

    await plans.delete(plan.id);

    expect(await plans.findItems(plan.id), isEmpty);
  });

  test('findCurrent returns the plan covering today', () async {
    final plan = await addPlan();
    final current = await plans.findCurrent();
    expect(current?.id, plan.id);
  });
}
