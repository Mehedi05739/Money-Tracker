import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/database/app_database.dart';
import 'package:money_tracker/core/enums/transaction_type.dart';
import 'package:money_tracker/core/database/db_tables.dart';
import 'package:money_tracker/data/local/daos/transaction_dao.dart';
import 'package:money_tracker/domain/entities/money_transaction.dart';
import 'package:money_tracker/domain/services/data_transfer_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Export, import, backup and restore all move the user's only copy of their
/// financial history, so each is tested against a real file on disk rather
/// than a mock.
void main() {
  setUpAll(sqfliteFfiInit);

  late AppDatabase database;
  late DataTransferService service;
  late Directory workDir;

  setUp(() async {
    workDir = Directory.systemTemp.createTempSync('mt_data_');
    databaseFactory = databaseFactoryFfi;
    // A real file: :memory: has no path to copy for a backup.
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

  Future<int> transactionCount() async {
    final rows = await database.db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.transactions}',
    );
    return rows.first['c']! as int;
  }

  group('export', () {
    test('writes every table and reports how many records', () async {
      await addTransaction(title: 'Coffee');

      final result = await service.exportToJson();

      final file = File(result.path);
      expect(file.existsSync(), isTrue);
      expect(result.recordCount, greaterThan(0));

      final decoded =
          jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
      expect(
        decoded['format_version'],
        DataTransferService.exportFormatVersion,
      );
      final tables = decoded['tables']! as Map<String, Object?>;
      for (final table in DataTransferService.exportedTables) {
        expect(tables.containsKey(table), isTrue, reason: '$table missing');
      }
      expect((tables[Tables.transactions]! as List), hasLength(1));
    });

    test('round-trips through import', () async {
      await addTransaction(amount: 250, title: 'Rent');
      final exported = await service.exportToJson();

      await addTransaction(amount: 999, title: 'Added after the export');
      expect(await transactionCount(), 2);

      await service.importFromJson(exported.path);

      expect(
        await transactionCount(),
        1,
        reason: 'import replaces, not merges',
      );
      final rows = await database.db.query(Tables.transactions);
      expect(rows.first[TransactionColumns.title], 'Rent');
    });
  });

  group('import rejects a file it cannot trust', () {
    test('a missing file', () async {
      await expectLater(
        service.importFromJson('${workDir.path}/nope.json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('something that is not an export', () async {
      final file = File('${workDir.path}/junk.json')
        ..writeAsStringSync('[1, 2, 3]');
      await expectLater(
        service.importFromJson(file.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('an export from another format version', () async {
      final file = File('${workDir.path}/old.json')
        ..writeAsStringSync(jsonEncode({'format_version': 99, 'tables': {}}));
      await expectLater(
        service.importFromJson(file.path),
        throwsA(isA<FormatException>()),
      );
    });

    test('a bad import leaves the existing data untouched', () async {
      await addTransaction(title: 'Keep me');
      final before = await transactionCount();

      final file = File('${workDir.path}/bad.json')
        ..writeAsStringSync(jsonEncode({'format_version': 99, 'tables': {}}));
      await expectLater(
        service.importFromJson(file.path),
        throwsA(isA<FormatException>()),
      );

      expect(await transactionCount(), before);
    });
  });

  group('backup and restore', () {
    test('a backup restores the state it captured', () async {
      await addTransaction(title: 'Before backup');
      final backup = await service.backup();
      expect(File(backup.path).existsSync(), isTrue);
      expect(backup.recordCount, 1);

      await addTransaction(title: 'After backup');
      expect(await transactionCount(), 2);

      await service.restore(backup.path);

      expect(await transactionCount(), 1);
      final rows = await database.db.query(Tables.transactions);
      expect(rows.first[TransactionColumns.title], 'Before backup');
    });

    test('restoring a corrupt file rolls back to the live data', () async {
      await addTransaction(title: 'Precious');
      final corrupt = File('${workDir.path}/money-tracker-backup-bad.bak')
        ..writeAsStringSync('this is not a database');

      await expectLater(service.restore(corrupt.path), throwsA(anything));

      // The rollback copy must have been put back and reopened.
      expect(await transactionCount(), 1);
      final rows = await database.db.query(Tables.transactions);
      expect(rows.first[TransactionColumns.title], 'Precious');
    });

    test('keeps the live connection usable afterwards', () async {
      // Restoring used to close and reopen the database, which left every DAO
      // holding a closed handle — the next query anywhere in the app threw
      // `database_closed`.
      await addTransaction();
      final backup = await service.backup();
      await service.restore(backup.path);

      await addTransaction(title: 'Written after the restore');
      expect(await transactionCount(), 2);
    });

    test('does not reset preferences', () async {
      await database.db.insert(Tables.appSettings, {
        'key': 'theme_mode',
        'value': 'dark',
        'updated_at': DateTime.now().toIso8601String(),
      });
      final backup = await service.backup();

      await database.db.update(
        Tables.appSettings,
        {'value': 'light'},
        where: 'key = ?',
        whereArgs: ['theme_mode'],
      );
      await service.restore(backup.path);

      final rows = await database.db.query(
        Tables.appSettings,
        where: 'key = ?',
        whereArgs: ['theme_mode'],
      );
      expect(
        rows.single['value'],
        'light',
        reason: 'a restore brings back the ledger, not preferences',
      );
    });
  });

  group('listing', () {
    test('separates exports from backups, newest first', () async {
      await addTransaction();
      await service.exportToJson();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      await service.backup();

      final exports = await service.listFiles(backups: false);
      final backups = await service.listFiles(backups: true);

      expect(exports, hasLength(1));
      expect(backups, hasLength(1));
      expect(exports.single.path.endsWith('.json'), isTrue);
      expect(backups.single.path.endsWith('.bak'), isTrue);
    });
  });

  group('clear all', () {
    test('empties user data but leaves a usable app', () async {
      await addTransaction();

      await service.clearAll();

      expect(await transactionCount(), 0);
      // Reseeded, or the user would be left unable to record anything.
      final accounts = await database.db.query(Tables.accounts);
      final categories = await database.db.query(Tables.categories);
      expect(accounts, isNotEmpty, reason: 'a default account is restored');
      expect(categories, isNotEmpty, reason: 'seed categories are restored');
    });
  });
}
