import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/enums/spending_warning.dart';
import 'package:money_tracker/core/utils/date_utils.dart';
import 'package:money_tracker/data/local/daos/spending_plan_dao.dart';
import 'package:money_tracker/data/repositories/spending_plan_repository_impl.dart';
import 'package:money_tracker/domain/entities/spending_plan.dart';
import 'package:money_tracker/domain/repositories/spending_plan_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late SpendingPlanRepository repository;
  late SpendingPlanDao dao;

  setUp(() async {
    final database = await openTestDatabase();
    addTearDown(database.close);
    dao = SpendingPlanDao(database.db);
    repository = SpendingPlanRepositoryImpl(dao);
  });

  SpendingPlan planFor(DateTime month, {double income = 2000, String? name}) {
    final now = DateTime.now();
    return SpendingPlan(
      id: 0,
      name: name ?? 'Plan ${month.month}',
      expectedIncome: income,
      startDate: AppDate.startOfMonth(month),
      endDate: AppDate.endOfMonth(month),
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<SpendingPlan> seedPlanWithItems(DateTime month) async {
    final created = (await repository.create(planFor(month))).dataOrNull!;
    final now = DateTime.now();
    for (final entry in {1: 600.0, 2: 300.0, 3: 150.0}.entries) {
      await repository.upsertItem(
        SpendingPlanItem(
          id: 0,
          planId: created.id,
          categoryId: entry.key,
          plannedAmount: entry.value,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return created;
  }

  group('previous plan', () {
    test('finds the most recent plan that already ended', () async {
      final now = DateTime.now();
      await seedPlanWithItems(AppDate.addMonths(now, -2));
      final lastMonth = await seedPlanWithItems(AppDate.addMonths(now, -1));

      final found = await repository.getPreviousPlan(AppDate.startOfMonth(now));

      expect(found.dataOrNull?.id, lastMonth.id);
    });

    test('returns null when there is nothing earlier', () async {
      final found = await repository.getPreviousPlan(DateTime(2000));
      expect(found.isSuccess, isTrue);
      expect(found.dataOrNull, isNull);
    });

    test('ignores a plan that has not finished yet', () async {
      final now = DateTime.now();
      await seedPlanWithItems(now);

      final found = await repository.getPreviousPlan(AppDate.startOfMonth(now));

      expect(found.dataOrNull, isNull, reason: 'this month has not ended');
    });
  });

  group('copying a plan', () {
    test('carries every allocation to the new plan', () async {
      final now = DateTime.now();
      final source = await seedPlanWithItems(AppDate.addMonths(now, -1));

      final copy = await repository.createFromTemplate(
        plan: planFor(now, name: 'September'),
        sourcePlanId: source.id,
      );

      expect(copy.isSuccess, isTrue);
      final items = (await repository.getItems(copy.dataOrNull!.id))
          .dataOrNull!;

      expect(items, hasLength(3));
      expect(items.map((i) => i.plannedAmount).toList()..sort(), [
        150.0,
        300.0,
        600.0,
      ]);
      expect(items.every((i) => i.planId == copy.dataOrNull!.id), isTrue);
    });

    test('leaves the source plan untouched', () async {
      final now = DateTime.now();
      final source = await seedPlanWithItems(AppDate.addMonths(now, -1));

      await repository.createFromTemplate(
        plan: planFor(now),
        sourcePlanId: source.id,
      );

      final original = (await repository.getItems(source.id)).dataOrNull!;
      expect(original, hasLength(3));
    });

    test('copies allocations but not spending', () async {
      final now = DateTime.now();
      final source = await seedPlanWithItems(AppDate.addMonths(now, -1));

      final copy = (await repository.createFromTemplate(
        plan: planFor(now),
        sourcePlanId: source.id,
      )).dataOrNull!;

      final progress = (await repository.getProgress(copy.id)).dataOrNull!;

      expect(progress.totalPlanned, 1050);
      expect(progress.totalSpent, 0, reason: 'a new month starts at zero');
    });

    test('rejects an invalid plan without copying anything', () async {
      final now = DateTime.now();
      final source = await seedPlanWithItems(AppDate.addMonths(now, -1));

      final result = await repository.createFromTemplate(
        plan: planFor(now, income: 0),
        sourcePlanId: source.id,
      );

      expect(result.isError, isTrue);
      final plans = (await repository.getPlans()).dataOrNull!;
      expect(plans, hasLength(1), reason: 'only the source plan exists');
    });
  });

  group('warning thresholds', () {
    test('classifies each threshold from the brief', () {
      expect(SpendingWarning.fromPercent(0), SpendingWarning.none);
      expect(SpendingWarning.fromPercent(69.9), SpendingWarning.none);
      expect(SpendingWarning.fromPercent(70), SpendingWarning.approaching);
      expect(SpendingWarning.fromPercent(89.9), SpendingWarning.approaching);
      expect(SpendingWarning.fromPercent(90), SpendingWarning.critical);
      expect(SpendingWarning.fromPercent(99.9), SpendingWarning.critical);
      expect(SpendingWarning.fromPercent(100), SpendingWarning.atLimit);
      expect(SpendingWarning.fromPercent(100.1), SpendingWarning.exceeded);
      expect(SpendingWarning.fromPercent(250), SpendingWarning.exceeded);
    });

    test('only an exceeded plan reports overspending', () {
      expect(SpendingWarning.atLimit.isExceeded, isFalse);
      expect(SpendingWarning.atLimit.isSpent, isTrue);
      expect(SpendingWarning.exceeded.isExceeded, isTrue);
      expect(SpendingWarning.none.shouldWarn, isFalse);
      expect(SpendingWarning.approaching.shouldWarn, isTrue);
    });
  });

  group('plan arithmetic from the brief', () {
    test('income minus planned is what is left to allocate', () async {
      final now = DateTime.now();
      final plan = (await repository.create(planFor(now, income: 2000)))
          .dataOrNull!;

      // The brief's example, one category each. Distinct ids matter: the
      // schema allows a category only once per plan.
      const allocations = <int, double>{
        1: 600, // Housing
        2: 300, // Food
        3: 150, // Transport
        4: 100, // Shopping
        5: 100, // Entertainment
        6: 400, // Savings
        7: 150, // Other
      };

      final created = DateTime.now();
      for (final entry in allocations.entries) {
        await repository.upsertItem(
          SpendingPlanItem(
            id: 0,
            planId: plan.id,
            categoryId: entry.key,
            plannedAmount: entry.value,
            createdAt: created,
            updatedAt: created,
          ),
        );
      }

      final progress = (await repository.getProgress(plan.id)).dataOrNull!;

      expect(progress.expectedIncome, 2000);
      expect(progress.totalPlanned, 1800);
      expect(progress.unallocated, 200);
      expect(progress.isOverAllocated, isFalse);
      expect(progress.items, hasLength(7));
    });
  });
}
