import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/database/migrations.dart';
import 'package:money_tracker/core/errors/exceptions.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Migrations are the one part of the schema that cannot be re-run in
/// production, so the upgrade path is exercised here rather than assumed.
void main() {
  setUpAll(sqfliteFfiInit);

  Future<AppDatabase> openAt(String path, int version) async {
    final database = AppDatabase(
      fileName: path,
      factoryOverride: databaseFactoryFfi,
      targetVersion: version,
    );
    await database.open();
    return database;
  }

  Future<Set<String>> indexesOf(AppDatabase database) async {
    final rows = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index'",
    );
    return rows.map((row) => '${row['name']}').toSet();
  }

  group('migration list', () {
    test('versions are unique, ordered and contiguous from 1', () {
      final versions = kMigrations.map((m) => m.version).toList();

      expect(versions.toSet().length, versions.length, reason: 'no duplicates');
      expect(versions, List.generate(versions.length, (i) => i + 1));
    });

    test('the newest migration matches the declared database version', () {
      expect(kMigrations.last.version, kDatabaseVersion);
    });

    test('every migration has at least one statement', () {
      for (final migration in kMigrations) {
        expect(
          migration.statements,
          isNotEmpty,
          reason: 'v${migration.version}',
        );
      }
    });
  });

  group('upgrade path', () {
    test('a v1 install upgrades to the current version, keeping its data', () async {
      // A temp file, because :memory: does not survive a close/reopen.
      final file =
          '${Directory.systemTemp.path}/mt_upgrade_${DateTime.now().microsecondsSinceEpoch}.db';
      final v1 = await openAt(file, 1);
      await v1.db.insert('accounts', {
        'name': 'Legacy',
        'type': 'cash',
        'opening_balance': 10.0,
        'current_balance': 10.0,
        'currency': 'USD',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
      final v1Indexes = await indexesOf(v1);
      expect(v1Indexes, isNot(contains('idx_budgets_period')));
      await v1.close();

      final upgraded = await openAt(file, kDatabaseVersion);
      addTearDown(upgraded.close);

      final version = await upgraded.db.rawQuery('PRAGMA user_version');
      expect(version.first.values.first, kDatabaseVersion);

      // The v2 indexes are present...
      final indexes = await indexesOf(upgraded);
      expect(indexes, contains('idx_budgets_period'));
      expect(indexes, contains('idx_tx_to_account'));

      // ...and the row written under v1 survived.
      final accounts = await upgraded.db.query(
        'accounts',
        where: 'name = ?',
        whereArgs: ['Legacy'],
      );
      expect(accounts, hasLength(1));
      expect((accounts.first['current_balance']! as num).toDouble(), 10.0);
    });

    test('v3 backfills the occurrence ledger from transactions a rule already '
        'generated', () async {
      // The case that matters for anyone already using the app: at v2 the only
      // record that an occurrence was posted is the rule's cursor. If v3 shipped
      // an empty ledger, every past occurrence would read as unprocessed and a
      // rewound or recomputed cursor could charge the user twice.
      final file =
          '${Directory.systemTemp.path}/mt_v3_${DateTime.now().microsecondsSinceEpoch}.db';
      final v2 = await openAt(file, 2);

      final ruleId = await v2.db.insert('recurring_transactions', {
        'account_id': 1,
        'category_id': 1,
        'type': 'expense',
        'amount': 1200.0,
        'title': 'Rent',
        'frequency': 'monthly',
        'interval_count': 1,
        'start_date': '2026-06-01T00:00:00.000',
        'next_run_date': '2026-09-01T00:00:00.000',
        'is_active': 1,
        'auto_post': 1,
        'created_at': '2026-06-01T00:00:00.000',
        'updated_at': '2026-06-01T00:00:00.000',
      });

      for (final date in ['2026-06-01', '2026-07-01', '2026-08-01']) {
        await v2.db.insert('transactions', {
          'account_id': 1,
          'type': 'expense',
          'amount': 1200.0,
          'category_id': 1,
          'title': 'Rent',
          'transaction_date': '${date}T00:00:00.000',
          'recurring_id': ruleId,
          'created_at': '${date}T00:00:00.000',
          'updated_at': '${date}T00:00:00.000',
        });
      }

      // A transaction the user entered by hand must not enter the ledger.
      await v2.db.insert('transactions', {
        'account_id': 1,
        'type': 'expense',
        'amount': 20.0,
        'category_id': 1,
        'title': 'Coffee',
        'transaction_date': '2026-08-15T00:00:00.000',
        'created_at': '2026-08-15T00:00:00.000',
        'updated_at': '2026-08-15T00:00:00.000',
      });

      expect(await indexesOf(v2), isNot(contains('idx_recurring_occurrence')));
      await v2.close();

      final upgraded = await openAt(file, kDatabaseVersion);
      addTearDown(upgraded.close);

      expect(await indexesOf(upgraded), contains('idx_recurring_occurrence'));

      final ledger = await upgraded.db.query(
        'recurring_occurrences',
        orderBy: 'occurrence_date ASC',
      );
      expect(ledger, hasLength(3), reason: 'one per generated transaction');
      expect(ledger.map((row) => row['occurrence_date']), [
        '2026-06-01',
        '2026-07-01',
        '2026-08-01',
      ]);
      expect(
        ledger.every((row) => row['transaction_id'] != null),
        isTrue,
        reason: 'each backfilled row points at the transaction it came from',
      );

      // The uniqueness that makes the ledger a guarantee is in force.
      await expectLater(
        upgraded.db.insert('recurring_occurrences', {
          'recurring_id': ruleId,
          'occurrence_date': '2026-07-01',
          'posted_at': '2026-09-01T00:00:00.000',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('re-opening at the current version is a no-op', () async {
      final file =
          '${Directory.systemTemp.path}/mt_noop_${DateTime.now().microsecondsSinceEpoch}.db';

      final first = await openAt(file, kDatabaseVersion);
      final seeded = await first.db.query('categories');
      await first.close();

      final second = await openAt(file, kDatabaseVersion);
      addTearDown(second.close);

      // Seed data is not applied twice.
      expect(await second.db.query('categories'), hasLength(seeded.length));
    });
  });

  group('downgrade', () {
    test('refuses to open a newer database instead of deleting it', () async {
      final file =
          '${Directory.systemTemp.path}/mt_down_${DateTime.now().microsecondsSinceEpoch}.db';

      final newer = await openAt(file, kDatabaseVersion + 1);
      await newer.db.insert('accounts', {
        'name': 'Precious',
        'type': 'cash',
        'opening_balance': 0.0,
        'current_balance': 0.0,
        'currency': 'USD',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      });
      await newer.close();

      await expectLater(
        openAt(file, kDatabaseVersion),
        throwsA(isA<DatabaseDowngradeException>()),
      );

      // The point of failing: the user's data is still there afterwards.
      final reopened = await openAt(file, kDatabaseVersion + 1);
      addTearDown(reopened.close);
      final rows = await reopened.db.query(
        'accounts',
        where: 'name = ?',
        whereArgs: ['Precious'],
      );
      expect(rows, hasLength(1), reason: 'downgrade must not destroy data');
    });
  });
}
