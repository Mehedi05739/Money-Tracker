import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/budget_period.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/data/local/daos/budget_dao.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/domain/entities/budget.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';

import '../helpers/test_database.dart';

void main() {
  late BudgetDao budgets;
  late TransactionDao transactions;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    budgets = BudgetDao(database.db);
    transactions = TransactionDao(database.db);
  });

  Future<int> addBudget({
    int? categoryId,
    double amount = 500,
    int alertPercentage = 80,
  }) {
    final range = DateRange.fromPreset(DateRangePreset.thisMonth);
    final now = DateTime.now();
    return budgets.insert(
      Budget(
        id: 0,
        categoryId: categoryId,
        amount: amount,
        period: BudgetPeriod.monthly,
        startDate: range.start,
        endDate: range.end,
        alertPercentage: alertPercentage,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> spend(double amount, {int? categoryId}) async {
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

  test('pairs each budget with its category spend in one query', () async {
    await addBudget(categoryId: 1, amount: 400);
    await addBudget(categoryId: 2, amount: 200);

    await spend(150, categoryId: 1);
    await spend(90, categoryId: 2);
    await spend(70, categoryId: 3); // outside both budgets

    final statuses = await budgets.findWithSpend();
    final first = statuses.firstWhere((s) => s.budget.categoryId == 1);
    final second = statuses.firstWhere((s) => s.budget.categoryId == 2);

    expect(first.spent, 150);
    expect(second.spent, 90);
  });

  test('an overall budget counts every expense category', () async {
    await addBudget(amount: 1000);

    await spend(100, categoryId: 1);
    await spend(200, categoryId: 2);
    await spend(50);

    final status = (await budgets.findWithSpend()).single;
    expect(status.budget.isOverall, isTrue);
    expect(status.spent, 350);
  });

  test('flags a budget as exceeded past its limit', () async {
    await addBudget(categoryId: 1, amount: 100);
    await spend(140, categoryId: 1);

    final status = (await budgets.findWithSpend()).single;

    expect(status.isExceeded, isTrue);
    expect(status.remaining, -40);
    expect(status.usagePercent, 140);
    expect(status.usageFraction, 1.0, reason: 'clamped for the progress bar');
    expect(status.headline, 'Over budget');
    expect(status.safeDailyAllowance, 0);
  });

  test('flags a budget at risk once the alert threshold is reached', () async {
    await addBudget(categoryId: 1, amount: 100, alertPercentage: 75);
    await spend(80, categoryId: 1);

    final status = (await budgets.findWithSpend()).single;

    expect(status.isAtRisk, isTrue);
    expect(status.isExceeded, isFalse);
    expect(status.headline, 'Approaching limit');
  });

  test('a healthy budget reports remaining and a daily allowance', () async {
    await addBudget(categoryId: 1, amount: 300);
    await spend(30, categoryId: 1);

    final status = (await budgets.findWithSpend()).single;

    expect(status.isHealthy, isTrue);
    expect(status.remaining, 270);
    expect(status.safeDailyAllowance, greaterThan(0));
  });

  test('income does not consume an expense budget', () async {
    await addBudget(categoryId: 1, amount: 500);

    final now = DateTime.now();
    await transactions.insert(
      MoneyTransaction(
        id: 0,
        accountId: 1,
        type: TransactionType.income,
        amount: 2000,
        categoryId: 1,
        title: 'salary',
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final status = (await budgets.findWithSpend()).single;
    expect(status.spent, 0);
  });

  test('detects an overlapping active budget for the same category', () async {
    await addBudget(categoryId: 1);
    final range = DateRange.fromPreset(DateRangePreset.thisMonth);
    final now = DateTime.now();

    final overlapping = Budget(
      id: 0,
      categoryId: 1,
      amount: 250,
      period: BudgetPeriod.monthly,
      startDate: range.start,
      endDate: range.end,
      createdAt: now,
      updatedAt: now,
    );
    final differentCategory = overlapping.copyWith(categoryId: 2);

    expect(await budgets.overlapsExisting(overlapping), isTrue);
    expect(await budgets.overlapsExisting(differentCategory), isFalse);
  });
}
