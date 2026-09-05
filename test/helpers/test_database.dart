import 'package:money_tracker/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a throwaway in-memory database with the real schema and seed data.
Future<AppDatabase> openTestDatabase() async {
  sqfliteFfiInit();
  final database = AppDatabase(
    fileName: inMemoryDatabasePath,
    factoryOverride: databaseFactoryFfi,
  );
  await database.open();
  return database;
}
