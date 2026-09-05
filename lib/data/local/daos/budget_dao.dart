import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/budget.dart';
import '../../../domain/entities/budget_status.dart';
import '../../models/budget_mapper.dart';
import '../../models/row_reader.dart';

class BudgetDao {
  const BudgetDao(this._db);

  final Database _db;

  static const String _selectWithCategory =
      '''
    SELECT b.*,
           c.${CategoryColumns.name}  AS ${BudgetMapper.aliasCategoryName},
           c.${CategoryColumns.icon}  AS ${BudgetMapper.aliasCategoryIcon},
           c.${CategoryColumns.color} AS ${BudgetMapper.aliasCategoryColor}
    FROM ${Tables.budgets} b
    LEFT JOIN ${Tables.categories} c ON c.${CategoryColumns.id} = b.${BudgetColumns.categoryId}
  ''';

  Future<List<Budget>> find({bool activeOnly = false}) async {
    final rows = await _db.rawQuery(
      '$_selectWithCategory '
      '${activeOnly ? 'WHERE b.${BudgetColumns.isActive} = 1' : ''} '
      'ORDER BY b.${BudgetColumns.startDate} DESC, b.${BudgetColumns.id} DESC',
    );
    return rows.map(BudgetMapper.fromRow).toList();
  }

  Future<Budget?> findById(int id) async {
    final rows = await _db.rawQuery(
      '$_selectWithCategory WHERE b.${BudgetColumns.id} = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : BudgetMapper.fromRow(rows.first);
  }

  Future<int> insert(Budget budget) =>
      _db.insert(Tables.budgets, BudgetMapper.toRow(budget));

  Future<int> update(Budget budget) {
    final row = BudgetMapper.toRow(budget.copyWith(updatedAt: DateTime.now()))
      ..remove(BudgetColumns.createdAt);
    return _db.update(
      Tables.budgets,
      row,
      where: '${BudgetColumns.id} = ?',
      whereArgs: [budget.id],
    );
  }

  /// Pauses or resumes a budget without touching its amount or dates.
  ///
  /// A dedicated write rather than a full update: resuming should not risk
  /// rewriting a period the user did not mean to change.
  Future<int> setActive(int id, bool active) => _db.update(
    Tables.budgets,
    {
      BudgetColumns.isActive: asDbBool(active),
      BudgetColumns.updatedAt: AppDate.toDb(DateTime.now()),
    },
    where: '${BudgetColumns.id} = ?',
    whereArgs: [id],
  );

  Future<int> delete(int id) => _db.delete(
    Tables.budgets,
    where: '${BudgetColumns.id} = ?',
    whereArgs: [id],
  );

  /// Budgets joined to their spend in one pass.
  ///
  /// A correlated subquery keeps this to a single round trip instead of one
  /// aggregate query per budget, and works for both category-scoped budgets
  /// and the overall budget (`category_id IS NULL`).
  Future<List<BudgetStatus>> findWithSpend({
    bool currentOnly = true,
    bool includePaused = false,
  }) async {
    final now = AppDate.toDb(DateTime.now());
    // A paused budget the user cannot see is one they cannot resume, so the
    // budgets screen asks for them; the dashboard does not.
    final activeClause = includePaused ? '' : 'b.${BudgetColumns.isActive} = 1';
    final rows = await _db.rawQuery('''
      SELECT b.*,
             c.${CategoryColumns.name}  AS ${BudgetMapper.aliasCategoryName},
             c.${CategoryColumns.icon}  AS ${BudgetMapper.aliasCategoryIcon},
             c.${CategoryColumns.color} AS ${BudgetMapper.aliasCategoryColor},
             COALESCE((
               SELECT SUM(t.${TransactionColumns.amount})
               FROM ${Tables.transactions} t
               WHERE t.${TransactionColumns.type} = 'expense'
                 AND t.${TransactionColumns.transactionDate}
                     BETWEEN b.${BudgetColumns.startDate} AND b.${BudgetColumns.endDate}
                 AND (b.${BudgetColumns.categoryId} IS NULL
                      OR t.${TransactionColumns.categoryId} = b.${BudgetColumns.categoryId})
             ), 0) AS spent
      FROM ${Tables.budgets} b
      LEFT JOIN ${Tables.categories} c ON c.${CategoryColumns.id} = b.${BudgetColumns.categoryId}
      ${_whereFor(currentOnly: currentOnly, activeClause: activeClause)}
      ORDER BY b.${BudgetColumns.startDate} DESC, b.${BudgetColumns.id} DESC
      ''', currentOnly ? [now, now] : const []);

    return rows
        .map(
          (row) => BudgetStatus(
            budget: BudgetMapper.fromRow(row),
            spent: row.readDoubleOr('spent'),
          ),
        )
        .toList();
  }

  /// Builds the WHERE clause for [findWithSpend].
  static String _whereFor({
    required bool currentOnly,
    required String activeClause,
  }) {
    final conditions = <String>[
      if (activeClause.isNotEmpty) activeClause,
      if (currentOnly) ...[
        'b.${BudgetColumns.startDate} <= ?',
        'b.${BudgetColumns.endDate} >= ?',
      ],
    ];
    return conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
  }

  Future<BudgetStatus?> findStatusById(int id) async {
    final rows = await _db.rawQuery(
      '''
      SELECT b.*,
             c.${CategoryColumns.name}  AS ${BudgetMapper.aliasCategoryName},
             c.${CategoryColumns.icon}  AS ${BudgetMapper.aliasCategoryIcon},
             c.${CategoryColumns.color} AS ${BudgetMapper.aliasCategoryColor},
             COALESCE((
               SELECT SUM(t.${TransactionColumns.amount})
               FROM ${Tables.transactions} t
               WHERE t.${TransactionColumns.type} = 'expense'
                 AND t.${TransactionColumns.transactionDate}
                     BETWEEN b.${BudgetColumns.startDate} AND b.${BudgetColumns.endDate}
                 AND (b.${BudgetColumns.categoryId} IS NULL
                      OR t.${TransactionColumns.categoryId} = b.${BudgetColumns.categoryId})
             ), 0) AS spent
      FROM ${Tables.budgets} b
      LEFT JOIN ${Tables.categories} c ON c.${CategoryColumns.id} = b.${BudgetColumns.categoryId}
      WHERE b.${BudgetColumns.id} = ?
      LIMIT 1
      ''',
      [id],
    );
    if (rows.isEmpty) return null;
    return BudgetStatus(
      budget: BudgetMapper.fromRow(rows.first),
      spent: rows.first.readDoubleOr('spent'),
    );
  }

  /// Prevents two active budgets covering the same category and window.
  Future<bool> overlapsExisting(Budget budget) async {
    final rows = await _db.rawQuery(
      '''
      SELECT ${BudgetColumns.id} FROM ${Tables.budgets}
      WHERE ${BudgetColumns.isActive} = 1
        AND ${BudgetColumns.id} <> ?
        AND (${BudgetColumns.categoryId} IS ?)
        AND ${BudgetColumns.startDate} <= ?
        AND ${BudgetColumns.endDate} >= ?
      LIMIT 1
      ''',
      [
        budget.id,
        budget.categoryId,
        AppDate.toDb(budget.endDate),
        AppDate.toDb(budget.startDate),
      ],
    );
    return rows.isNotEmpty;
  }
}
