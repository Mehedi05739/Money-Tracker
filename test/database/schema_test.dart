import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/migrations.dart';

import '../helpers/test_database.dart';

void main() {
  test('creates every table at the current schema version', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    final tables = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = tables.map((row) => row['name']).toSet();

    expect(
      names,
      containsAll([
        'accounts',
        'categories',
        'transactions',
        'budgets',
        'spending_plans',
        'spending_plan_items',
        'financial_goals',
        'goal_contributions',
        'recurring_transactions',
        'app_settings',
      ]),
    );
    final version = await database.db.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, kDatabaseVersion);
  });

  test('enables foreign key enforcement on the connection', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    final result = await database.db.rawQuery('PRAGMA foreign_keys');
    expect(result.first.values.first, 1);
  });

  test('seeds a default account and category set', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    expect(await database.db.query('accounts'), hasLength(1));
    final categories = await database.db.query('categories');
    expect(categories.length, greaterThan(15));
    expect(categories.where((c) => c['type'] == 'income'), isNotEmpty);
  });

  test('rejects a transaction whose amount is not positive', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    expect(
      () => database.db.insert('transactions', _row(amount: 0)),
      throwsA(anything),
    );
  });

  test('rejects a transaction pointing at a missing account', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    expect(
      () => database.db.insert('transactions', _row(accountId: 999)),
      throwsA(anything),
    );
  });

  test('rejects a transfer without a destination account', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    expect(
      () => database.db.insert('transactions', _row(type: 'transfer')),
      throwsA(anything),
    );
  });

  test('cascades transaction deletion when an account is removed', () async {
    final database = await openTestDatabase();
    addTearDown(database.close);

    await database.db.insert('transactions', _row());
    expect(await database.db.query('transactions'), hasLength(1));

    await database.db.delete('accounts', where: 'id = 1');
    expect(await database.db.query('transactions'), isEmpty);
  });
}

Map<String, Object?> _row({
  int accountId = 1,
  String type = 'expense',
  double amount = 10,
}) =>
    {
      'account_id': accountId,
      'type': type,
      'amount': amount,
      'title': 'Test',
      'transaction_date': '2026-09-05T10:00:00.000',
      'created_at': '2026-09-05T10:00:00.000',
      'updated_at': '2026-09-05T10:00:00.000',
    };
