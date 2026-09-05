import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/money_transaction.dart';
import '../../../domain/repositories/transaction_repository.dart';
import '../../models/row_reader.dart';
import '../../models/transaction_mapper.dart';

/// Reads use a join so list rows carry their category and account names; writes
/// run inside a SQL transaction that also moves the affected account balances.
class TransactionDao {
  const TransactionDao(this._db);

  final Database _db;

  static const String _selectWithJoins =
      '''
    SELECT t.*,
           c.${CategoryColumns.name}  AS ${TransactionMapper.aliasCategoryName},
           c.${CategoryColumns.icon}  AS ${TransactionMapper.aliasCategoryIcon},
           c.${CategoryColumns.color} AS ${TransactionMapper.aliasCategoryColor},
           a.${AccountColumns.name}   AS ${TransactionMapper.aliasAccountName},
           ta.${AccountColumns.name}  AS ${TransactionMapper.aliasToAccountName}
    FROM ${Tables.transactions} t
    LEFT JOIN ${Tables.categories} c ON c.${CategoryColumns.id} = t.${TransactionColumns.categoryId}
    LEFT JOIN ${Tables.accounts}   a ON a.${AccountColumns.id}  = t.${TransactionColumns.accountId}
    LEFT JOIN ${Tables.accounts}   ta ON ta.${AccountColumns.id} = t.${TransactionColumns.toAccountId}
  ''';

  Future<List<MoneyTransaction>> find({
    TransactionFilter filter = const TransactionFilter(),
    int limit = 30,
    int offset = 0,
  }) async {
    final clause = _buildWhere(filter);
    final rows = await _db.rawQuery(
      '$_selectWithJoins ${clause.sql} '
      'ORDER BY t.${TransactionColumns.transactionDate} DESC, t.${TransactionColumns.id} DESC '
      'LIMIT ? OFFSET ?',
      [...clause.args, limit, offset],
    );
    return rows.map(TransactionMapper.fromRow).toList();
  }

  Future<int> count(TransactionFilter filter) async {
    final clause = _buildWhere(filter);
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${Tables.transactions} t ${clause.sql}',
      clause.args,
    );
    return rows.first.readIntOrNull('c') ?? 0;
  }

  Future<MoneyTransaction?> findById(int id) async {
    final rows = await _db.rawQuery(
      '$_selectWithJoins WHERE t.${TransactionColumns.id} = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : TransactionMapper.fromRow(rows.first);
  }

  Future<List<MoneyTransaction>> findRecent({int limit = 5}) async {
    final rows = await _db.rawQuery(
      '$_selectWithJoins '
      'ORDER BY t.${TransactionColumns.transactionDate} DESC, t.${TransactionColumns.id} DESC '
      'LIMIT ?',
      [limit],
    );
    return rows.map(TransactionMapper.fromRow).toList();
  }

  Future<int> insert(MoneyTransaction transaction) {
    return _db.transaction((txn) async {
      final id = await txn.insert(
        Tables.transactions,
        TransactionMapper.toRow(transaction),
      );
      await _applyBalance(txn, transaction, 1);
      return id;
    });
  }

  /// Reverses the stored row's balance effect before applying the new one, so
  /// changing an amount, account or type can never leave a balance stale.
  Future<int> update(MoneyTransaction transaction) {
    return _db.transaction((txn) async {
      final existingRows = await txn.query(
        Tables.transactions,
        where: '${TransactionColumns.id} = ?',
        whereArgs: [transaction.id],
        limit: 1,
      );
      if (existingRows.isEmpty) return 0;

      final existing = TransactionMapper.fromRow(existingRows.first);
      await _applyBalance(txn, existing, -1);

      final row = TransactionMapper.toRow(
        transaction.copyWith(updatedAt: DateTime.now()),
      )..remove(TransactionColumns.createdAt);

      final updated = await txn.update(
        Tables.transactions,
        row,
        where: '${TransactionColumns.id} = ?',
        whereArgs: [transaction.id],
      );
      await _applyBalance(txn, transaction, 1);
      return updated;
    });
  }

  Future<int> delete(int id) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        Tables.transactions,
        where: '${TransactionColumns.id} = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return 0;

      await _applyBalance(txn, TransactionMapper.fromRow(rows.first), -1);
      return txn.delete(
        Tables.transactions,
        where: '${TransactionColumns.id} = ?',
        whereArgs: [id],
      );
    });
  }

  /// Bulk insert used when materialising recurring rules; shares one SQL
  /// transaction with the caller so a partial run cannot be committed.
  static Future<void> insertWithinTransaction(
    DatabaseExecutor txn,
    MoneyTransaction transaction,
  ) async {
    await txn.insert(Tables.transactions, TransactionMapper.toRow(transaction));
    await _adjustBalance(txn, transaction, 1);
  }

  Future<void> _applyBalance(
    DatabaseExecutor txn,
    MoneyTransaction transaction,
    int direction,
  ) => _adjustBalance(txn, transaction, direction);

  /// Moves account balances by [transaction]'s effect, multiplied by
  /// [direction] (`1` to apply, `-1` to reverse).
  static Future<void> _adjustBalance(
    DatabaseExecutor txn,
    MoneyTransaction transaction,
    int direction,
  ) async {
    final now = AppDate.toDb(DateTime.now());
    final delta = transaction.amount * transaction.type.balanceSign * direction;

    await txn.rawUpdate(
      'UPDATE ${Tables.accounts} '
      'SET ${AccountColumns.currentBalance} = ${AccountColumns.currentBalance} + ?, '
      '    ${AccountColumns.updatedAt} = ? '
      'WHERE ${AccountColumns.id} = ?',
      [delta, now, transaction.accountId],
    );

    // A transfer credits the destination by the same amount it debited.
    if (transaction.type.isTransfer && transaction.toAccountId != null) {
      await txn.rawUpdate(
        'UPDATE ${Tables.accounts} '
        'SET ${AccountColumns.currentBalance} = ${AccountColumns.currentBalance} + ?, '
        '    ${AccountColumns.updatedAt} = ? '
        'WHERE ${AccountColumns.id} = ?',
        [transaction.amount * direction, now, transaction.toAccountId],
      );
    }
  }

  /// Builds a parameterised WHERE clause. Values are always bound, never
  /// interpolated, so user input cannot reach the SQL text.
  _WhereClause _buildWhere(TransactionFilter filter) {
    final conditions = <String>[];
    final args = <Object?>[];

    if (filter.range != null) {
      conditions.add('t.${TransactionColumns.transactionDate} BETWEEN ? AND ?');
      args
        ..add(filter.range!.startDb)
        ..add(filter.range!.endDb);
    }

    if (filter.types.isNotEmpty) {
      final placeholders = List.filled(filter.types.length, '?').join(', ');
      conditions.add('t.${TransactionColumns.type} IN ($placeholders)');
      args.addAll(filter.types.map((type) => type.name));
    }

    if (filter.categoryIds.isNotEmpty) {
      final placeholders = List.filled(
        filter.categoryIds.length,
        '?',
      ).join(', ');
      conditions.add('t.${TransactionColumns.categoryId} IN ($placeholders)');
      args.addAll(filter.categoryIds);
    }

    if (filter.accountIds.isNotEmpty) {
      final placeholders = List.filled(
        filter.accountIds.length,
        '?',
      ).join(', ');
      conditions.add(
        '(t.${TransactionColumns.accountId} IN ($placeholders) '
        'OR t.${TransactionColumns.toAccountId} IN ($placeholders))',
      );
      args
        ..addAll(filter.accountIds)
        ..addAll(filter.accountIds);
    }

    final search = filter.search?.trim();
    if (search != null && search.isNotEmpty) {
      conditions.add(
        "(t.${TransactionColumns.title} LIKE ? ESCAPE '\\' "
        "OR t.${TransactionColumns.note} LIKE ? ESCAPE '\\' "
        "OR t.${TransactionColumns.description} LIKE ? ESCAPE '\\')",
      );
      final pattern = '%${_escapeLike(search)}%';
      args
        ..add(pattern)
        ..add(pattern)
        ..add(pattern);
    }

    if (filter.minAmount != null) {
      conditions.add('t.${TransactionColumns.amount} >= ?');
      args.add(filter.minAmount);
    }
    if (filter.maxAmount != null) {
      conditions.add('t.${TransactionColumns.amount} <= ?');
      args.add(filter.maxAmount);
    }

    return _WhereClause(
      conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}',
      args,
    );
  }

  /// Neutralises LIKE wildcards typed by the user so a `%` searches literally.
  static String _escapeLike(String value) =>
      value.replaceAll('%', r'\%').replaceAll('_', r'\_');
}

class _WhereClause {
  const _WhereClause(this.sql, this.args);
  final String sql;
  final List<Object?> args;
}
