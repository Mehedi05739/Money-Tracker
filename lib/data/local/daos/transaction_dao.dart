import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../account_balance.dart';
import '../../../core/enums/transaction_sort.dart';
import '../../../core/enums/transaction_type.dart';
import '../../../domain/entities/analytics.dart';
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
    TransactionSort sort = TransactionSort.newestFirst,
    int limit = 30,
    int offset = 0,
  }) async {
    final clause = _buildWhere(filter);
    final rows = await _db.rawQuery(
      '$_selectWithJoins ${clause.sql} '
      'ORDER BY ${_orderBy(sort)} '
      'LIMIT ? OFFSET ?',
      [...clause.args, limit, offset],
    );
    return rows.map(TransactionMapper.fromRow).toList();
  }

  /// Fixed SQL per sort option — never built from user input.
  ///
  /// Each ends with the id so paging is stable: without a tiebreaker, rows
  /// sharing a timestamp or amount can reshuffle between pages and appear
  /// twice or not at all.
  static String _orderBy(TransactionSort sort) => switch (sort) {
    TransactionSort.newestFirst =>
      't.${TransactionColumns.transactionDate} DESC, t.${TransactionColumns.id} DESC',
    TransactionSort.oldestFirst =>
      't.${TransactionColumns.transactionDate} ASC, t.${TransactionColumns.id} ASC',
    TransactionSort.largestFirst =>
      't.${TransactionColumns.amount} DESC, t.${TransactionColumns.id} DESC',
    TransactionSort.smallestFirst =>
      't.${TransactionColumns.amount} ASC, t.${TransactionColumns.id} ASC',
    TransactionSort.titleAZ =>
      't.${TransactionColumns.title} COLLATE NOCASE ASC, t.${TransactionColumns.id} ASC',
  };

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

  // ---- Aggregates ---------------------------------------------------------
  // These answer questions about many rows without returning any. The filter
  // is the same one the list uses, so a total always describes exactly the
  // rows the user is looking at.

  /// Income, expense, transfer and row count for [filter], in one pass.
  Future<TransactionTotals> totals(TransactionFilter filter) async {
    final clause = _buildWhere(filter);
    final rows = await _db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN t.${TransactionColumns.type} = 'income'
                          THEN t.${TransactionColumns.amount} END), 0) AS income,
        COALESCE(SUM(CASE WHEN t.${TransactionColumns.type} = 'expense'
                          THEN t.${TransactionColumns.amount} END), 0) AS expense,
        COALESCE(SUM(CASE WHEN t.${TransactionColumns.type} = 'transfer'
                          THEN t.${TransactionColumns.amount} END), 0) AS transfer,
        COUNT(*) AS tx_count
      FROM ${Tables.transactions} t
      ${clause.sql}
      ''', clause.args);

    final row = rows.first;
    return TransactionTotals(
      income: row.readDoubleOr('income'),
      expense: row.readDoubleOr('expense'),
      transfer: row.readDoubleOr('transfer'),
      count: row.readIntOrNull('tx_count') ?? 0,
    );
  }

  /// Sum of a single [type] under [filter].
  Future<double> sumByType(
    TransactionFilter filter,
    TransactionType type,
  ) async {
    final clause = _buildWhere(filter.copyWith(types: {type}));
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(t.${TransactionColumns.amount}), 0) AS total '
      'FROM ${Tables.transactions} t ${clause.sql}',
      clause.args,
    );
    return rows.first.readDoubleOr('total');
  }

  /// Per-category totals for [filter], largest first.
  Future<List<CategorySpending>> categoryTotals(
    TransactionFilter filter, {
    int limit = 50,
  }) async {
    final clause = _buildWhere(filter);
    final rows = await _db.rawQuery(
      '''
      SELECT t.${TransactionColumns.categoryId}      AS category_id,
             COALESCE(c.${CategoryColumns.name}, 'Uncategorized') AS category_name,
             c.${CategoryColumns.icon}               AS category_icon,
             c.${CategoryColumns.color}              AS category_color,
             SUM(t.${TransactionColumns.amount})     AS total,
             COUNT(*)                                AS tx_count
      FROM ${Tables.transactions} t
      LEFT JOIN ${Tables.categories} c
             ON c.${CategoryColumns.id} = t.${TransactionColumns.categoryId}
      ${clause.sql}
      GROUP BY t.${TransactionColumns.categoryId}
      ORDER BY total DESC
      LIMIT ?
      ''',
      [...clause.args, limit],
    );

    final total = rows.fold<double>(
      0,
      (sum, row) => sum + row.readDoubleOr('total'),
    );

    // Every group is present here (no truncation before the sum), so this
    // total is the real one and the shares are honest.
    return rows
        .map(
          (row) => CategorySpending(
            categoryId: row.readIntOrNull('category_id'),
            categoryName: row.readString('category_name'),
            categoryIcon: row.readStringOrNull('category_icon'),
            categoryColor: row.readIntOrNull('category_color'),
            amount: row.readDoubleOr('total'),
            transactionCount: row.readIntOrNull('tx_count') ?? 0,
          ).withShare(total),
        )
        .toList();
  }

  /// One row per day that has activity under [filter], oldest first.
  Future<List<TrendPoint>> dailyTotals(TransactionFilter filter) async {
    final clause = _buildWhere(filter);
    final rows = await _db.rawQuery('''
      SELECT substr(t.${TransactionColumns.transactionDate}, 1, 10) AS day,
             COALESCE(SUM(CASE WHEN t.${TransactionColumns.type} = 'income'
                               THEN t.${TransactionColumns.amount} END), 0) AS income,
             COALESCE(SUM(CASE WHEN t.${TransactionColumns.type} = 'expense'
                               THEN t.${TransactionColumns.amount} END), 0) AS expense
      FROM ${Tables.transactions} t
      ${clause.sql}
      GROUP BY day
      ORDER BY day ASC
      ''', clause.args);

    return rows.map((row) {
      final day = DateTime.parse(row.readString('day'));
      return TrendPoint(
        label: '${day.day}',
        date: day,
        income: row.readDoubleOr('income'),
        expense: row.readDoubleOr('expense'),
      );
    }).toList();
  }

  /// Bulk insert used when materialising recurring rules; shares one SQL
  /// transaction with the caller so a partial run cannot be committed.
  /// Returns the new transaction's id, so a caller writing in the same
  /// transaction can link its own row to it.
  static Future<int> insertWithinTransaction(
    DatabaseExecutor txn,
    MoneyTransaction transaction,
  ) async {
    final id = await txn.insert(
      Tables.transactions,
      TransactionMapper.toRow(transaction),
    );
    await _adjustBalance(txn, transaction, 1);
    return id;
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
    final delta = AccountBalance.sourceDelta(transaction) * direction;

    await txn.rawUpdate(
      'UPDATE ${Tables.accounts} '
      'SET ${AccountColumns.currentBalance} = ${AccountColumns.currentBalance} + ?, '
      '    ${AccountColumns.updatedAt} = ? '
      'WHERE ${AccountColumns.id} = ?',
      [delta, now, transaction.accountId],
    );

    // A transfer credits the destination by the same amount it debited.
    final destination = AccountBalance.destinationDelta(transaction);
    if (destination != 0) {
      await txn.rawUpdate(
        'UPDATE ${Tables.accounts} '
        'SET ${AccountColumns.currentBalance} = ${AccountColumns.currentBalance} + ?, '
        '    ${AccountColumns.updatedAt} = ? '
        'WHERE ${AccountColumns.id} = ?',
        [destination * direction, now, transaction.toAccountId],
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
      // EXISTS rather than a join on categories: `count` and the aggregate
      // queries use this clause without joining, and a join there would change
      // their row counts.
      conditions.add(
        "(t.${TransactionColumns.title} LIKE ? ESCAPE '\\' "
        "OR t.${TransactionColumns.note} LIKE ? ESCAPE '\\' "
        "OR t.${TransactionColumns.description} LIKE ? ESCAPE '\\' "
        'OR EXISTS (SELECT 1 FROM ${Tables.categories} sc '
        'WHERE sc.${CategoryColumns.id} = t.${TransactionColumns.categoryId} '
        "AND sc.${CategoryColumns.name} LIKE ? ESCAPE '\\'))",
      );
      final pattern = '%${_escapeLike(search)}%';
      args
        ..add(pattern)
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
