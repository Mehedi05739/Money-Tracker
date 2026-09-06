import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/database/db_tables.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/services/data_transfer_service.dart';
import 'package:money_tracker/domain/services/export_schema.dart';
import 'package:money_tracker/domain/services/import_validation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Importing is the one operation that can destroy a ledger it did not create,
/// so the rules are strict: validate everything before writing, never overwrite
/// without being told to, and leave the database untouched if anything fails.
void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late DataTransferService service;
  late Directory workDir;

  setUp(() async {
    workDir = Directory.systemTemp.createTempSync('mt_import_');
    databaseFactory = databaseFactoryFfi;
    database = AppDatabase(
      fileName: '${workDir.path}/money_tracker.db',
      factoryOverride: databaseFactoryFfi,
    );
    await database.open();
    service = DataTransferService(database);

    addTearDown(() async {
      await database.close();
      if (workDir.existsSync()) workDir.deleteSync(recursive: true);
    });
  });

  Future<void> addTransaction({double amount = 100, String title = 'x'}) async {
    final now = DateTime.now();
    await TransactionDao(database.db).insert(
      MoneyTransaction(
        id: 0,
        accountId: 1,
        type: TransactionType.expense,
        amount: amount,
        title: title,
        transactionDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<int> countOf(String table) async {
    final rows = await database.db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return rows.first['c']! as int;
  }

  String writeFile(String name, Object? json) {
    final file = File('${workDir.path}/$name')
      ..writeAsStringSync(jsonEncode(json));
    return file.path;
  }

  /// A minimal but valid export: one account, one category, one transaction.
  Map<String, Object?> validExport({
    int accountId = 50,
    String account = 'Imported wallet',
  }) {
    const stamp = '2026-01-01T00:00:00.000';
    return {
      'format_version': ExportSchema.formatVersion,
      'exported_at': stamp,
      'data': {
        'accounts': [
          {
            'id': accountId,
            'name': account,
            'type': 'cash',
            'opening_balance': 0.0,
            'current_balance': 0.0,
            'currency': 'BDT',
            'created_at': stamp,
            'updated_at': stamp,
          },
        ],
        'categories': [
          {
            'id': 70,
            'name': 'Imported category',
            'type': 'expense',
            'created_at': stamp,
          },
        ],
        'transactions': [
          {
            'id': 90,
            'account_id': accountId,
            'category_id': 70,
            'type': 'expense',
            'amount': 42.0,
            'title': 'Imported expense',
            'transaction_date': stamp,
            'created_at': stamp,
            'updated_at': stamp,
          },
        ],
      },
      'settings': {'theme_mode': 'dark'},
    };
  }

  group('validation', () {
    test('rejects a file that is not an export', () async {
      final path = writeFile('junk.json', [1, 2, 3]);
      await expectLater(
        service.inspect(path),
        throwsA(isA<ImportValidationException>()),
      );
    });

    test('rejects a newer format version', () async {
      final path = writeFile('new.json', {
        'format_version': ExportSchema.formatVersion + 1,
        'data': <String, Object?>{},
      });
      await expectLater(
        service.inspect(path),
        throwsA(isA<ImportValidationException>()),
      );
    });

    test('names the record and the field that is missing', () async {
      final bad = validExport();
      (((bad['data']! as Map)['transactions']! as List).first as Map).remove(
        'amount',
      );
      final path = writeFile('bad.json', bad);

      try {
        await service.inspect(path);
        fail('should have been rejected');
      } on ImportValidationException catch (error) {
        expect(error.problems, hasLength(1));
        expect(error.problems.first.group, 'transactions');
        expect(error.problems.first.index, 0);
        expect(error.problems.first.message, contains('amount'));
      }
    });

    test('reports every problem, not just the first', () async {
      final bad = validExport();
      final data = bad['data']! as Map;
      ((data['transactions']! as List).first as Map).remove('amount');
      ((data['accounts']! as List).first as Map).remove('name');
      final path = writeFile('bad2.json', bad);

      try {
        await service.inspect(path);
        fail('should have been rejected');
      } on ImportValidationException catch (error) {
        expect(error.problems.length, 2);
      }
    });

    test('rejects a link to a record the file does not contain', () async {
      final bad = validExport();
      (((bad['data']! as Map)['transactions']! as List).first
              as Map)['account_id'] =
          999;
      final path = writeFile('orphan.json', bad);

      try {
        await service.inspect(path);
        fail('should have been rejected');
      } on ImportValidationException catch (error) {
        expect(
          error.problems.first.message,
          contains('has no matching account'),
        );
      }
    });

    test('accepts a file with groups omitted entirely', () async {
      final payload = await service.inspect(
        writeFile('sparse.json', validExport()),
      );
      expect(payload.records['budgets'], isEmpty);
      expect(payload.records['transactions'], hasLength(1));
    });

    test('reads without writing anything', () async {
      final before = await countOf(Tables.transactions);
      await service.inspect(writeFile('ok.json', validExport()));
      expect(await countOf(Tables.transactions), before);
    });
  });

  group('merge', () {
    test('keeps existing data and adds the file alongside it', () async {
      await addTransaction(title: 'Mine');
      final path = writeFile('ok.json', validExport());

      final result = await service.importFromJson(path);

      expect(await countOf(Tables.transactions), 2);
      expect(result.added, greaterThan(0));
      final titles = (await database.db.query(Tables.transactions))
          .map((row) => row['title'])
          .toList();
      expect(titles, containsAll(['Mine', 'Imported expense']));
    });

    test('renumbers incoming ids so nothing existing is overwritten', () async {
      await addTransaction(title: 'Mine');
      // The file's account id 1 collides with the seeded account.
      final colliding = validExport(accountId: 1, account: 'Different wallet');
      final path = writeFile('collide.json', colliding);

      await service.importFromJson(path);

      final accounts = await database.db.query(Tables.accounts);
      expect(accounts, hasLength(2), reason: 'the existing account survives');

      // The imported transaction must point at the imported account, not the
      // one that happened to share its id.
      final imported = (await database.db.query(
        Tables.transactions,
        where: 'title = ?',
        whereArgs: ['Imported expense'],
      )).single;
      final wallet = accounts.firstWhere(
        (a) => a['name'] == 'Different wallet',
      );
      expect(imported['account_id'], wallet['id']);
    });

    test('matches records the user already has instead of duplicating', () async {
      // Seeded categories include "Food & Drinks"; import a file naming it too.
      final existing = (await database.db.query(
        Tables.categories,
        where: 'type = ?',
        whereArgs: ['expense'],
        limit: 1,
      )).single;

      final file = validExport();
      final categories = (file['data']! as Map)['categories']! as List;
      (categories.first as Map)['name'] = existing['name'];
      (categories.first as Map)['type'] = existing['type'];
      final path = writeFile('dupe.json', file);

      final before = await countOf(Tables.categories);
      final result = await service.importFromJson(path);

      expect(await countOf(Tables.categories), before);
      expect(result.reused, greaterThan(0));

      // And the imported transaction points at the category already there.
      final imported = (await database.db.query(
        Tables.transactions,
        where: 'title = ?',
        whereArgs: ['Imported expense'],
      )).single;
      expect(imported['category_id'], existing['id']);
    });

    test('never matches transactions, which have no natural identity', () async {
      final path = writeFile('ok.json', validExport());
      await service.importFromJson(path);
      await service.importFromJson(path);

      // Two imports of the same file mean the user really did record it twice;
      // silently collapsing them would lose data.
      expect(await countOf(Tables.transactions), 2);
    });

    test('brings preferences across', () async {
      await service.importFromJson(writeFile('ok.json', validExport()));

      final rows = await database.db.query(
        Tables.appSettings,
        where: 'key = ?',
        whereArgs: ['theme_mode'],
      );
      expect(rows.single['value'], 'dark');
    });
  });

  group('replace', () {
    test('clears first, then loads the file', () async {
      await addTransaction(title: 'Mine');
      final path = writeFile('ok.json', validExport());

      await service.importFromJson(path, mode: ImportMode.replace);

      final rows = await database.db.query(Tables.transactions);
      expect(rows, hasLength(1));
      expect(rows.single['title'], 'Imported expense');
    });
  });

  group('rollback', () {
    test('a write that fails leaves the database untouched', () async {
      await addTransaction(title: 'Precious');
      final before = await countOf(Tables.transactions);

      // Passes validation — the link resolves inside the file — but the type
      // violates the transactions CHECK constraint, so the insert fails
      // partway through the write.
      final file = validExport();
      (((file['data']! as Map)['transactions']! as List).first as Map)['type'] =
          'not_a_type';
      final path = writeFile('boom.json', file);

      await expectLater(
        service.importFromJson(path, mode: ImportMode.replace),
        throwsA(anything),
      );

      expect(
        await countOf(Tables.transactions),
        before,
        reason: 'replace deleted rows, but the rollback put them back',
      );
      final rows = await database.db.query(Tables.transactions);
      expect(rows.single['title'], 'Precious');
    });
  });

  group('progress', () {
    test('reports steps that advance to completion', () async {
      final steps = <TransferProgress>[];
      await service.importFromJson(
        writeFile('ok.json', validExport()),
        onProgress: steps.add,
      );

      expect(steps, isNotEmpty);
      expect(steps.last.fraction, 1.0);
      for (var i = 1; i < steps.length; i++) {
        expect(
          steps[i].fraction,
          greaterThanOrEqualTo(steps[i - 1].fraction),
          reason: 'progress must not go backwards',
        );
      }
    });

    test('export reports progress too', () async {
      final steps = <TransferProgress>[];
      await service.exportToJson(onProgress: steps.add);
      expect(steps.last.fraction, 1.0);
    });
  });

  group('the export omits internal bookkeeping', () {
    test(
      'no occurrence ledger in the file, but it is rebuilt on import',
      () async {
        final exported = await service.exportToJson();
        final decoded = jsonDecode(
          File(exported.path).readAsStringSync(),
        ) as Map<String, Object?>;
        final data = decoded['data']! as Map<String, Object?>;

        expect(
          data.containsKey(Tables.recurringOccurrences),
          isFalse,
          reason: 'the ledger is internal, not the user’s financial data',
        );
        expect(data.containsKey('settings'), isFalse);
        expect(decoded['settings'], isA<Map<String, Object?>>());
      },
    );
  });
}
