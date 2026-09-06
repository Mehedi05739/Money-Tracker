import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/database/db_tables.dart';
import '../../core/database/migrations.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/logger.dart';
import '../../data/local/daos/account_dao.dart';
import 'export_schema.dart';
import 'import_validation.dart';

/// How an import treats data already in the app.
enum ImportMode {
  /// Adds the file's records alongside what is there, renumbering incoming ids
  /// so nothing existing is touched. The default, because an import should
  /// never cost the user data they did not ask to lose.
  merge,

  /// Deletes everything first, then loads the file. Only ever reached through
  /// an explicit typed confirmation.
  replace,
}

/// A step in a long-running transfer, for the UI to show.
class TransferProgress {
  const TransferProgress({
    required this.label,
    required this.completed,
    required this.total,
  });

  final String label;
  final int completed;
  final int total;

  double get fraction => total <= 0 ? 0 : (completed / total).clamp(0.0, 1.0);
}

typedef ProgressCallback = void Function(TransferProgress progress);

/// What a transfer produced.
class DataTransferResult {
  const DataTransferResult({
    required this.path,
    required this.recordCount,
    this.added = 0,
    this.reused = 0,
    this.replaced = false,
  });

  final String path;
  final int recordCount;

  /// Records written.
  final int added;

  /// Records the file carried that already existed and were matched to the
  /// existing ones instead of duplicated.
  final int reused;

  final bool replaced;

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
/// readable, inspectable, portable, and describable by [ExportSchema]. A
/// **backup** is a byte copy of the SQLite file: exact, including schema
/// version, and the right thing to restore from.
class DataTransferService {
  const DataTransferService(this._database);

  final AppDatabase _database;

  Future<Directory> _storageDir() async {
    final dir = Directory(p.dirname(_database.db.path));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  String _stamp() =>
      AppDate.toDb(DateTime.now()).replaceAll(':', '-').replaceAll('.', '-');

  // ----------------------------------------------------------------- Export

  /// Writes the user's financial data and preferences to a JSON file.
  Future<DataTransferResult> exportToJson({
    ProgressCallback? onProgress,
  }) async {
    final db = _database.db;
    final data = <String, Object?>{};
    var records = 0;

    final total = ExportSchema.groups.length + 1;
    for (var i = 0; i < ExportSchema.groups.length; i++) {
      final group = ExportSchema.groups[i];
      onProgress?.call(
        TransferProgress(
          label: 'Reading ${group.key}',
          completed: i,
          total: total,
        ),
      );

      final rows = await db.query(group.table);
      data[group.key] = rows;
      records += rows.length;
    }

    onProgress?.call(
      TransferProgress(
        label: 'Reading settings',
        completed: ExportSchema.groups.length,
        total: total,
      ),
    );
    final settings = await _readSettings(db);

    final payload = <String, Object?>{
      'format_version': ExportSchema.formatVersion,
      'app_version': AppConstants.appVersion,
      'exported_at': AppDate.toDb(DateTime.now()),
      'counts': {
        for (final group in ExportSchema.groups)
          group.key: (data[group.key]! as List).length,
      },
      ExportSchema.dataKey: data,
      ExportSchema.settingsKey: settings,
    };

    final dir = await _storageDir();
    final file = File(
      p.join(dir.path, 'money-tracker-export-${_stamp()}.json'),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    onProgress?.call(
      TransferProgress(label: 'Done', completed: total, total: total),
    );
    return DataTransferResult(path: file.path, recordCount: records);
  }

  Future<Map<String, String>> _readSettings(DatabaseExecutor db) async {
    final rows = await db.query(Tables.appSettings);
    return {
      for (final row in rows)
        row[SettingsColumns.key]! as String:
            (row[SettingsColumns.value] as String?) ?? '',
    };
  }

  // ----------------------------------------------------------------- Import

  /// Reads and validates a file without writing anything.
  ///
  /// Separate from [importFromJson] so the UI can tell the user what a file
  /// contains, and refuse a bad one, before asking them to confirm.
  Future<ImportPayload> inspect(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const ImportValidationException([
        ImportProblem(message: 'That file no longer exists'),
      ]);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(await file.readAsString());
    } on FormatException {
      throw const ImportValidationException([
        ImportProblem(message: 'That file is not readable JSON'),
      ]);
    }

    return ImportValidator.parse(decoded);
  }

  /// Loads a validated file into the database.
  ///
  /// The whole write is one SQL transaction: if anything fails, nothing is
  /// kept — including, in replace mode, the deletion that would otherwise have
  /// already destroyed the user's data.
  Future<DataTransferResult> importFromJson(
    String path, {
    ImportMode mode = ImportMode.merge,
    ProgressCallback? onProgress,
  }) async {
    final payload = await inspect(path);

    var added = 0;
    var reused = 0;

    await _database.db.transaction((txn) async {
      if (mode == ImportMode.replace) {
        onProgress?.call(
          const TransferProgress(
            label: 'Clearing existing data',
            completed: 0,
            total: 1,
          ),
        );
        for (final group in ExportSchema.groups.reversed) {
          await txn.delete(group.table);
        }
        await txn.delete(Tables.recurringOccurrences);
      }

      // Incoming id → id actually used. Merge renumbers to avoid colliding
      // with rows already present; replace keeps the file's own ids.
      final idMap = <String, Map<int, int>>{
        for (final group in ExportSchema.groups) group.key: {},
      };

      final total = ExportSchema.groups.length + 2;
      for (var i = 0; i < ExportSchema.groups.length; i++) {
        final group = ExportSchema.groups[i];
        final rows = payload.records[group.key] ?? const [];
        onProgress?.call(
          TransferProgress(
            label: 'Importing ${group.key}',
            completed: i,
            total: total,
          ),
        );

        for (final row in rows) {
          final incomingId = row['id'] as int?;
          final prepared = Map<String, Object?>.from(row)..remove('id');

          // Rewrite links to whatever id their target actually received.
          group.references.forEach((column, targetKey) {
            final value = prepared[column];
            if (value is int) {
              prepared[column] = idMap[targetKey]?[value] ?? value;
            }
          });

          if (mode == ImportMode.replace) {
            if (incomingId != null) prepared['id'] = incomingId;
            final newId = await txn.insert(group.table, prepared);
            if (incomingId != null) idMap[group.key]![incomingId] = newId;
            added++;
            continue;
          }

          // Merge: reuse a record that already describes the same thing rather
          // than creating a second one. Importing a file that also has a
          // "Groceries" category must not leave the user with two.
          final existingId = await _findMatch(txn, group, prepared);
          if (existingId != null) {
            if (incomingId != null) idMap[group.key]![incomingId] = existingId;
            reused++;
            continue;
          }

          final newId = await txn.insert(group.table, prepared);
          if (incomingId != null) idMap[group.key]![incomingId] = newId;
          added++;
        }
      }

      onProgress?.call(
        TransferProgress(
          label: 'Restoring preferences',
          completed: ExportSchema.groups.length,
          total: total,
        ),
      );
      for (final entry in payload.settings.entries) {
        await txn.insert(Tables.appSettings, {
          SettingsColumns.key: entry.key,
          SettingsColumns.value: entry.value,
          SettingsColumns.updatedAt: AppDate.toDb(DateTime.now()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      onProgress?.call(
        TransferProgress(
          label: 'Rebuilding schedules',
          completed: total - 1,
          total: total,
        ),
      );
      await _rebuildOccurrenceLedger(txn);

      // Imported transactions are written straight to the table, so none of
      // the per-row balance maintenance ran. Without this every account keeps
      // whatever balance it had and silently disagrees with its own ledger —
      // in merge mode the accounts are reused, so they end up short by exactly
      // the imported spending.
      await AccountDao.recalculateWithin(txn);
    });

    onProgress?.call(
      const TransferProgress(label: 'Done', completed: 1, total: 1),
    );

    return DataTransferResult(
      path: path,
      recordCount: payload.recordCount,
      added: added,
      reused: reused,
      replaced: mode == ImportMode.replace,
    );
  }

  /// Finds a record already in the database describing the same thing.
  ///
  /// Only groups with an [ExportGroup.identity] can match — a transaction has
  /// no natural key, and treating two same-day, same-amount coffees as one
  /// record would quietly lose data.
  Future<int?> _findMatch(
    DatabaseExecutor txn,
    ExportGroup group,
    Map<String, Object?> row,
  ) async {
    final identity = group.identity;
    if (identity == null) return null;

    final where = identity.map((column) => '$column = ?').join(' AND ');
    final args = identity.map((column) => row[column]).toList();
    if (args.any((value) => value == null)) return null;

    final rows = await txn.query(
      group.table,
      columns: ['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as int?;
  }

  /// Rebuilds the recurring occurrence ledger from the imported transactions.
  ///
  /// The ledger is internal bookkeeping, so it is deliberately not exported.
  /// It still has to exist afterwards, or the next catch-up would treat every
  /// already-posted occurrence as unprocessed. Reconstructed the same way
  /// migration v3 backfills it: from the transactions that carry a
  /// `recurring_id`.
  Future<void> _rebuildOccurrenceLedger(DatabaseExecutor txn) async {
    await txn.rawInsert('''
      INSERT OR IGNORE INTO ${Tables.recurringOccurrences}
        (${RecurringOccurrenceColumns.recurringId},
         ${RecurringOccurrenceColumns.occurrenceDate},
         ${RecurringOccurrenceColumns.transactionId},
         ${RecurringOccurrenceColumns.postedAt})
      SELECT ${TransactionColumns.recurringId},
             substr(${TransactionColumns.transactionDate}, 1, 10),
             ${TransactionColumns.id},
             ${TransactionColumns.createdAt}
      FROM ${Tables.transactions}
      WHERE ${TransactionColumns.recurringId} IS NOT NULL
    ''');
  }

  // ------------------------------------------------------- Backup / restore

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

  /// Copies the database file itself.
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
  /// be unreadable leaves the current data exactly as it was.
  Future<DataTransferResult> restore(
    String path, {
    ProgressCallback? onProgress,
  }) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw const FormatException('That backup no longer exists');
    }

    final Database backup;
    try {
      backup = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
      );
    } catch (_) {
      throw const FormatException('That file is not a Money Tracker backup');
    }

    // A backup carries the occurrence ledger, unlike an export: it is a copy of
    // the database rather than a portable document.
    final tables = [
      ...ExportSchema.groups.map((group) => group.table),
      Tables.recurringOccurrences,
    ];

    var records = 0;
    try {
      final version = await backup.getVersion();
      if (version > kDatabaseVersion) {
        throw const FormatException(
          'That backup was made by a newer version of the app',
        );
      }

      final snapshot = <String, List<Map<String, Object?>>>{};
      for (var i = 0; i < tables.length; i++) {
        onProgress?.call(
          TransferProgress(
            label: 'Reading backup',
            completed: i,
            total: tables.length * 2,
          ),
        );
        snapshot[tables[i]] = await backup.query(tables[i]);
      }

      await _database.db.transaction((txn) async {
        for (final table in tables.reversed) {
          await txn.delete(table);
        }
        for (var i = 0; i < tables.length; i++) {
          onProgress?.call(
            TransferProgress(
              label: 'Restoring ${tables[i]}',
              completed: tables.length + i,
              total: tables.length * 2,
            ),
          );
          for (final row in snapshot[tables[i]]!) {
            await txn.insert(tables[i], row);
            records++;
          }
        }
        // The backup carries its own balances, but rebuilding them costs one
        // statement and removes any doubt that they match the rows restored
        // alongside them.
        await AccountDao.recalculateWithin(txn);
      });
    } on FormatException {
      rethrow;
    } catch (error) {
      AppLogger.w('Restore failed: ${error.runtimeType}', name: 'DATA');
      throw const FormatException('That backup could not be read');
    } finally {
      await backup.close();
    }

    return DataTransferResult(path: path, recordCount: records, replaced: true);
  }

  /// Wipes everything and reseeds the defaults.
  Future<void> clearAll() => _database.resetData();
}
