import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:money_tracker/core/enums/account_type.dart';
import 'package:money_tracker/domain/entities/account.dart';
import 'package:money_tracker/domain/entities/financial_goal.dart';

/// Regression cover for a stale-screen bug: the entities compared on `id`
/// alone, and `Rx.value = x` skips the assignment when the incoming value
/// equals the one already held. Reloading a goal after a contribution
/// therefore left the old object — and the old balance — on screen.
void main() {
  FinancialGoal goal({double current = 0}) => FinancialGoal(
    id: 1,
    name: 'Laptop',
    targetAmount: 1500,
    currentAmount: current,
    createdAt: DateTime(2026, 9, 5),
    updatedAt: DateTime(2026, 9, 5),
  );

  group('entity equality', () {
    test('two reads of an unchanged row compare equal', () {
      expect(goal(), equals(goal()));
      expect(goal().hashCode, equals(goal().hashCode));
    });

    test('a changed field makes the same row unequal', () {
      expect(goal(current: 700), isNot(equals(goal())));
    });

    test('different entity types never compare equal', () {
      final account = Account(
        id: 1,
        name: 'Cash',
        type: AccountType.cash,
        openingBalance: 0,
        currentBalance: 0,
        currency: 'BDT',
        createdAt: DateTime(2026, 9, 5),
        updatedAt: DateTime(2026, 9, 5),
      );
      expect(account, isNot(equals(goal())));
    });
  });

  group('Rx propagation', () {
    // GetX fires unconditionally on the first assignment, so each case burns
    // that one first and then measures the deduplicating path that matters.
    Rxn<FinancialGoal> seeded() => Rxn<FinancialGoal>(goal())..value = goal();

    test('a same-id update with a new balance reaches listeners', () {
      final rx = seeded();
      var notified = 0;
      final sub = rx.listen((_) => notified++);
      addTearDown(sub.cancel);

      rx.value = goal(current: 700);

      expect(rx.value?.currentAmount, 700, reason: 'the Rx kept a stale goal');
      expect(notified, 1, reason: 'listeners were never told the goal moved');
    });

    test('an identical reload does not churn listeners', () {
      final rx = seeded();
      var notified = 0;
      final sub = rx.listen((_) => notified++);
      addTearDown(sub.cancel);

      rx.value = goal();

      expect(notified, 0);
    });
  });
}
