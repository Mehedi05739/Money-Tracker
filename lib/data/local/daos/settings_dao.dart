import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../../../core/utils/date_utils.dart';

class SettingsDao {
  const SettingsDao(this._db);

  final Database _db;

  Future<Map<String, String>> findAll() async {
    final rows = await _db.query(Tables.appSettings);
    return {
      for (final row in rows)
        row[SettingsColumns.key]! as String:
            (row[SettingsColumns.value] as String?) ?? '',
    };
  }

  Future<String?> find(String key) async {
    final rows = await _db.query(
      Tables.appSettings,
      where: '${SettingsColumns.key} = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[SettingsColumns.value] as String?;
  }

  Future<void> put(String key, String value) => _db.insert(
        Tables.appSettings,
        {
          SettingsColumns.key: key,
          SettingsColumns.value: value,
          SettingsColumns.updatedAt: AppDate.toDb(DateTime.now()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<int> remove(String key) => _db.delete(
        Tables.appSettings,
        where: '${SettingsColumns.key} = ?',
        whereArgs: [key],
      );
}
