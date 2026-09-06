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
  AppDatabase({
    this.fileName = 'money_tracker.db',
    this.factoryOverride,
    int? targetVersion,
  }) : targetVersion = targetVersion ?? kDatabaseVersion;

  final String fileName;

  /// Injected by tests to run against an in-memory database.
  final DatabaseFactory? factoryOverride;

  /// Schema version to open at. Production always uses [kDatabaseVersion];
  /// tests pin an older version so the upgrade path can be exercised rather
  /// than assumed.
  final int targetVersion;

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
          version: targetVersion,
          onConfigure: _onConfigure,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onDowngrade: _onDowngrade,
        ),
      );
      return _db!;
    } on MigrationException catch (error, stackTrace) {
      // Log the version and statement, never the rows involved.
      AppLogger.e(
        'Migration to v${error.version} failed: ${error.statementSummary}',
        error: error.cause.runtimeType,
        stackTrace: stackTrace,
      );
      throw CacheException(
        'Could not update the local database to version ${error.version}',
      );
    } on DatabaseException catch (error, stackTrace) {
      AppLogger.e(
        'Failed to open database',
        error: error.runtimeType,
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

    // The daily reminder's reply is handled in a background isolate, which
    // opens its own connection to this same file while the app may still hold
    // one. Without a busy timeout the second writer fails immediately with
    // "database is locked"; five seconds is far longer than any write here
    // takes, and only costs anything in the rare case of contention.
    // `rawQuery`, not `execute`: this pragma returns the value it set, and
    // Android's execSQL throws for any statement that returns rows.
    await db.rawQuery('PRAGMA busy_timeout = 5000');
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

  /// Refuses to open a database written by a newer build.
  ///
  /// sqflite's `onDatabaseDowngradeDelete` would drop the file and start over.
  /// For a ledger that is silent, unrecoverable loss of the user's financial
  /// history, so this fails loudly instead and leaves the data untouched.
  Future<void> _onDowngrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.e(
      'Refusing to downgrade database $oldVersion → $newVersion',
      name: 'DB',
    );
    throw DatabaseDowngradeException(
      currentVersion: oldVersion,
      supportedVersion: newVersion,
    );
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

  /// Wipes every user table and reseeds the defaults, keeping the schema.
  ///
  /// Backs the "clear all data" action as well as tests. Children are deleted
  /// before parents so nothing is orphaned mid-wipe, and the reseed runs inside
  /// the same transaction — a failure leaves the ledger untouched rather than
  /// empty and unusable.
  Future<void> resetData() async {
    await db.transaction((txn) async {
      for (final table in const [
        'recurring_occurrences',
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
