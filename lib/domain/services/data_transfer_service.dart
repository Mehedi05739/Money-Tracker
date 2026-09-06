import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/database/db_tables.dart';
import '../../core/database/migrations.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/logger.dart';

/// What an export, backup or restore produced.
class DataTransferResult {
  const DataTransferResult({required this.path, required this.recordCount});

  final String path;
  final int recordCount;

  String get fileName => p.basename(path);
}

/// Export, import, backup and restore for the local database.
///
/// Everything stays on the device: files are written beside the database, in
/// the app's own storage. That is a deliberate limit rather than an oversight —
/// handing the file to a share sheet or a cloud picker would mean the user's
/// complete financial history leaving the app, which the whole design has so
/// far avoided.
///
/// Two shapes, because they answer different questions. An **export** is JSON:
/// readable, inspectable, and portable to something else. A **backup** is a
/// byte copy of the SQLite file: exact, including schema version, and the right
/// thing to restore from.
class DataTransferService {
  const DataTransferService(this._database);

  final AppDatabase _database;

  /// Tables carried by an export, in dependency order so an import can insert
  /// them without tripping a foreign key.
  static const List<String> exportedTables = [
    Tables.accounts,
    Tables.categories,
    Tables.transactions,
    Tables.budgets,
    Tables.spendingPlans,
    Tables.spendingPlanItems,
    Tables.financialGoals,
    Tables.goalContributions,
    Tables.recurringTransactions,
    Tables.recurringOccurrences,
  ];

  /// Bumped if the export shape ever changes, so an import can refuse a file it
  /// does not understand rather than half-loading it.
  static const int exportFormatVersion = 1;

  /// Where exports and backups are written: beside the database itself.
  ///
  /// Derived from the open connection's path rather than the global
  /// `databaseFactory`, which is process-wide state anything can reassign —
  /// a file written to one directory and looked for in another is a backup the
  /// user cannot find.
  Future<Directory> _storageDir() async {
    final dir = Directory(p.dirname(_database.db.path));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  String _stamp() =>
      AppDate.toDb(DateTime.now()).replaceAll(':', '-').replaceAll('.', '-');

  /// Writes every table to a JSON file.
  Future<DataTransferResult> exportToJson() async {
    final db = _database.db;
    final payload = <String, Object?>{
      'format_version': exportFormatVersion,
      'schema_version': await db.getVersion(),
      'exported_at': AppDate.toDb(DateTime.now()),
      'tables': <String, Object?>{},
    };

    var records = 0;
    final tables = payload['tables']! as Map<String, Object?>;
    for (final table in exportedTables) {
      final rows = await db.query(table);
      tables[table] = rows;
      records += rows.length;
    }

    final dir = await _storageDir();
    final file = File(
      p.join(dir.path, 'money-tracker-export-${_stamp()}.json'),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    return DataTransferResult(path: file.path, recordCount: records);
  }

  /// The exports and backups already on the device, newest first.
  Future<List<File>> listFiles({required bool backups}) async {
    final dir = await _storageDir();
    final suffix = backups ? '.bak' : '.json';
    final files =
        dir
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith(suffix))
            .where((file) => p.basename(file.path).startsWith('money-tracker-'))
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );
    return files;
  }

  /// Replaces the current data with the contents of [path].
  ///
  /// Runs as one SQL transaction: an import that fails partway leaves the
  /// ledger exactly as it was rather than half-replaced.
  Future<DataTransferResult> importFromJson(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const FormatException('That file no longer exists');
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('This is not a Money Tracker export');
    }
    if (decoded['format_version'] != exportFormatVersion) {
      throw const FormatException(
        'This export was made by a different version of the app',
      );
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, Object?>) {
      throw const FormatException('This export has no data in it');
    }

    var records = 0;
    await _database.db.transaction((txn) async {
      // Children first, so nothing is orphaned mid-wipe.
      for (final table in exportedTables.reversed) {
        await txn.delete(table);
      }

      for (final table in exportedTables) {
        final rows = tables[table];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is! Map) continue;
          await txn.insert(table, Map<String, Object?>.from(row));
          records++;
        }
      }
    });

    return DataTransferResult(path: path, recordCount: records);
  }

  /// Copies the database file itself.
  ///
  /// The connection is checkpointed first: SQLite may still hold committed
  /// pages in a journal, and copying without that can capture a file that is
  /// missing the newest transactions.
  Future<DataTransferResult> backup() async {
    final db = _database.db;

    // Best-effort checkpoint so the copy includes anything still sitting in a
    // write-ahead log. `rawQuery`, not `execute`: this pragma returns a row,
    // and Android's execSQL throws for any statement that does — which made
    // every backup fail silently. Wrapped because a database not in WAL mode
    // has nothing to checkpoint and that is not an error.
    try {
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (error) {
      AppLogger.d('Checkpoint skipped: ${error.runtimeType}', name: 'DATA');
    }

    final source = File(db.path);
    final dir = await _storageDir();
    final target = File(
      p.join(dir.path, 'money-tracker-backup-${_stamp()}.bak'),
    );
    await source.copy(target.path);

    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.transactions}',
    );
    return DataTransferResult(
      path: target.path,
      recordCount: (rows.first['c'] as int?) ?? 0,
    );
  }

  /// Loads a backup's contents into the live database.
  ///
  /// The obvious implementation — close the connection, copy the file over it,
  /// reopen — does not work here. Every DAO is constructed with the `Database`
  /// handle resolved at startup, so reopening leaves them all pointing at a
  /// closed connection and the next query anywhere in the app fails. The
  /// backup is instead opened on its own read-only connection and its rows are
  /// copied in, which keeps the one live connection valid throughout.
  ///
  /// The copy runs as a single SQL transaction, so a backup that turns out to
  /// be unreadable leaves the current data exactly as it was — no separate
  /// rollback file needed.
  ///
  /// Preferences are not touched: a restore should bring back your ledger, not
  /// silently change your theme and currency.
  Future<DataTransferResult> restore(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const FormatException('That backup no longer exists');
    }

    // `singleInstance: false` so this never collides with the live connection.
    final Database backup;
    try {
      backup = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
    } catch (_) {
      throw const FormatException('That file is not a Money Tracker backup');
    }

    var records = 0;
    try {
      final version = await backup.getVersion();
      if (version > kDatabaseVersion) {
        throw const FormatException(
          'That backup was made by a newer version of the app',
        );
      }

      final snapshot = <String, List<Map<String, Object?>>>{};
      for (final table in exportedTables) {
        snapshot[table] = await backup.query(table);
      }

      await _database.db.transaction((txn) async {
        for (final table in exportedTables.reversed) {
          await txn.delete(table);
        }
        for (final table in exportedTables) {
          for (final row in snapshot[table]!) {
            await txn.insert(table, row);
            records++;
          }
        }
      });
    } on FormatException {
      rethrow;
    } catch (error) {
      AppLogger.w('Restore failed: ${error.runtimeType}', name: 'DATA');
      throw const FormatException('That backup could not be read');
    } finally {
      await backup.close();
    }

    return DataTransferResult(path: path, recordCount: records);
  }

  /// Wipes everything and reseeds the defaults.
  ///
  /// Delegates to [AppDatabase.resetData] rather than repeating the wipe:
  /// clearing the ledger without restoring a default account and the seed
  /// categories would leave an app that cannot record a transaction.
  Future<void> clearAll() => _database.resetData();
}
