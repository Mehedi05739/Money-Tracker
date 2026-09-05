import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../errors/exceptions.dart';
import '../utils/logger.dart';
import 'migrations.dart';
import 'seed_data.dart';

/// Owns the single sqflite connection for the app.
///
/// Opened once during startup; DAOs receive the [Database] rather than opening
/// their own handles, so all writes share one connection and can participate in
/// the same SQL transaction.
class AppDatabase {
  AppDatabase({this.fileName = 'money_tracker.db', this.factoryOverride});

  final String fileName;

  /// Injected by tests to run against an in-memory database.
  final DatabaseFactory? factoryOverride;

  Database? _db;

  /// Throws if accessed before [open] — a programming error, not a user error.
  Database get db {
    final instance = _db;
    if (instance == null) {
      throw StateError('AppDatabase.open() must be awaited before use');
    }
    return instance;
  }

  bool get isOpen => _db?.isOpen ?? false;

  Future<Database> open() async {
    if (_db != null) return _db!;

    try {
      final factory = factoryOverride ?? databaseFactory;
      final path = await _resolvePath(factory);

      _db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kDatabaseVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onDowngrade: onDatabaseDowngradeDelete,
        ),
      );
      return _db!;
    } on DatabaseException catch (error, stackTrace) {
      AppLogger.e(
        'Failed to open database',
        error: error,
        stackTrace: stackTrace,
      );
      throw const CacheException('Could not open the local database');
    }
  }

  /// Resolves [fileName] against the platform database directory, except for
  /// the in-memory sentinel and absolute paths, which are used verbatim.
  Future<String> _resolvePath(DatabaseFactory factory) async {
    if (fileName == inMemoryDatabasePath || p.isAbsolute(fileName)) {
      return fileName;
    }
    return p.join(await factory.getDatabasesPath(), fileName);
  }

  /// Foreign keys are off by default in SQLite and must be enabled per
  /// connection, before any statement runs.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.i('Creating database at version $version', name: 'DB');
    await applyMigrations(db, from: 0, to: version);
    await SeedData.populate(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.i('Upgrading database $oldVersion → $newVersion', name: 'DB');
    await applyMigrations(db, from: oldVersion, to: newVersion);
  }

  /// Runs [action] inside a single SQL transaction. Any thrown error rolls the
  /// whole unit back, which is what keeps account balances consistent with the
  /// rows that produced them.
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) =>
      db.transaction<T>(action);

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Test/diagnostic helper: wipes user data but keeps the schema and reseeds.
  Future<void> resetData() async {
    await db.transaction((txn) async {
      for (final table in const [
        'goal_contributions',
        'financial_goals',
        'spending_plan_items',
        'spending_plans',
        'budgets',
        'transactions',
        'recurring_transactions',
        'categories',
        'accounts',
        'app_settings',
      ]) {
        await txn.delete(table);
      }
      await SeedData.populate(txn);
    });
  }
}
