import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../../../core/enums/transaction_type.dart';
import '../../../domain/entities/category.dart';
import '../../models/category_mapper.dart';
import '../../models/row_reader.dart';

class CategoryDao {
  const CategoryDao(this._db);

  final Database _db;

  Future<List<Category>> find({
    TransactionType? type,
    bool includeArchived = false,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];

    if (type != null) {
      conditions.add('${CategoryColumns.type} = ?');
      args.add(type.name);
    }
    if (!includeArchived) {
      conditions.add('${CategoryColumns.isArchived} = 0');
    }

    final rows = await _db.query(
      Tables.categories,
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: '${CategoryColumns.name} ASC',
    );
    return rows.map(CategoryMapper.fromRow).toList();
  }

  Future<Category?> findById(int id) async {
    final rows = await _db.query(
      Tables.categories,
      where: '${CategoryColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : CategoryMapper.fromRow(rows.first);
  }

  Future<int> insert(Category category) =>
      _db.insert(Tables.categories, CategoryMapper.toRow(category));

  Future<int> update(Category category) {
    final row = CategoryMapper.toRow(category)
      ..remove(CategoryColumns.createdAt);
    return _db.update(
      Tables.categories,
      row,
      where: '${CategoryColumns.id} = ?',
      whereArgs: [category.id],
    );
  }

  Future<int> delete(int id) => _db.delete(
    Tables.categories,
    where: '${CategoryColumns.id} = ?',
    whereArgs: [id],
  );

  Future<int> setArchived(int id, bool archived) => _db.update(
    Tables.categories,
    {CategoryColumns.isArchived: asDbBool(archived)},
    where: '${CategoryColumns.id} = ?',
    whereArgs: [id],
  );

  /// Used to decide whether deleting is safe or the user should archive.
  Future<int> countTransactions(int categoryId) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.transactions} '
      'WHERE ${TransactionColumns.categoryId} = ?',
      [categoryId],
    );
    return rows.first.readIntOrNull('c') ?? 0;
  }

  Future<bool> existsWithName(
    String name,
    TransactionType type, {
    int? excludingId,
  }) async {
    final rows = await _db.query(
      Tables.categories,
      columns: [CategoryColumns.id],
      where:
          'LOWER(${CategoryColumns.name}) = ? AND ${CategoryColumns.type} = ?'
          '${excludingId != null ? ' AND ${CategoryColumns.id} <> ?' : ''}',
      whereArgs: [name.trim().toLowerCase(), type.name, ?excludingId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }
}
