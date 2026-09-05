import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/spending_plan.dart';
import '../../../domain/entities/spending_plan_progress.dart';
import '../../models/row_reader.dart';
import '../../models/spending_plan_mapper.dart';

class SpendingPlanDao {
  const SpendingPlanDao(this._db);

  final Database _db;

  Future<List<SpendingPlan>> find({bool activeOnly = false}) async {
    final rows = await _db.query(
      Tables.spendingPlans,
      where: activeOnly ? "${SpendingPlanColumns.status} = 'active'" : null,
      orderBy:
          '${SpendingPlanColumns.startDate} DESC, '
          '${SpendingPlanColumns.id} DESC',
    );
    return rows.map(SpendingPlanMapper.fromRow).toList();
  }

  Future<SpendingPlan?> findById(int id) async {
    final rows = await _db.query(
      Tables.spendingPlans,
      where: '${SpendingPlanColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : SpendingPlanMapper.fromRow(rows.first);
  }

  /// The plan whose window contains today, if any.
  Future<SpendingPlan?> findCurrent() async {
    final now = AppDate.toDb(DateTime.now());
    final rows = await _db.query(
      Tables.spendingPlans,
      where:
          "${SpendingPlanColumns.status} = 'active' "
          'AND ${SpendingPlanColumns.startDate} <= ? '
          'AND ${SpendingPlanColumns.endDate} >= ?',
      whereArgs: [now, now],
      orderBy: '${SpendingPlanColumns.startDate} DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : SpendingPlanMapper.fromRow(rows.first);
  }

  /// The latest plan that finished before [before].
  Future<SpendingPlan?> findPrevious(DateTime before) async {
    final rows = await _db.query(
      Tables.spendingPlans,
      where: '${SpendingPlanColumns.endDate} < ?',
      whereArgs: [AppDate.toDb(before)],
      orderBy: '${SpendingPlanColumns.endDate} DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : SpendingPlanMapper.fromRow(rows.first);
  }

  /// Inserts [plan] and copies every allocation from [sourcePlanId].
  ///
  /// One SQL transaction: a partially copied plan would understate what the
  /// user had allocated, and they would have no way to tell.
  Future<int> insertCopy({
    required SpendingPlan plan,
    required int sourcePlanId,
  }) {
    return _db.transaction((txn) async {
      final planId = await txn.insert(
        Tables.spendingPlans,
        SpendingPlanMapper.toRow(plan),
      );

      final source = await txn.query(
        Tables.spendingPlanItems,
        where: '${SpendingPlanItemColumns.planId} = ?',
        whereArgs: [sourcePlanId],
      );

      final now = AppDate.toDb(DateTime.now());
      final batch = txn.batch();
      for (final row in source) {
        batch.insert(Tables.spendingPlanItems, {
          SpendingPlanItemColumns.planId: planId,
          SpendingPlanItemColumns.categoryId:
              row[SpendingPlanItemColumns.categoryId],
          SpendingPlanItemColumns.plannedAmount:
              row[SpendingPlanItemColumns.plannedAmount],
          SpendingPlanItemColumns.note: row[SpendingPlanItemColumns.note],
          SpendingPlanItemColumns.createdAt: now,
          SpendingPlanItemColumns.updatedAt: now,
        });
      }
      await batch.commit(noResult: true);

      return planId;
    });
  }

  Future<int> insert(SpendingPlan plan) =>
      _db.insert(Tables.spendingPlans, SpendingPlanMapper.toRow(plan));

  Future<int> update(SpendingPlan plan) {
    final row = SpendingPlanMapper.toRow(
      plan.copyWith(updatedAt: DateTime.now()),
    )..remove(SpendingPlanColumns.createdAt);
    return _db.update(
      Tables.spendingPlans,
      row,
      where: '${SpendingPlanColumns.id} = ?',
      whereArgs: [plan.id],
    );
  }

  /// Items cascade via the foreign key.
  Future<int> delete(int id) => _db.delete(
    Tables.spendingPlans,
    where: '${SpendingPlanColumns.id} = ?',
    whereArgs: [id],
  );

  Future<List<SpendingPlanItem>> findItems(int planId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT i.*,
             c.${CategoryColumns.name}  AS ${SpendingPlanItemMapper.aliasCategoryName},
             c.${CategoryColumns.icon}  AS ${SpendingPlanItemMapper.aliasCategoryIcon},
             c.${CategoryColumns.color} AS ${SpendingPlanItemMapper.aliasCategoryColor}
      FROM ${Tables.spendingPlanItems} i
      LEFT JOIN ${Tables.categories} c
             ON c.${CategoryColumns.id} = i.${SpendingPlanItemColumns.categoryId}
      WHERE i.${SpendingPlanItemColumns.planId} = ?
      ORDER BY i.${SpendingPlanItemColumns.plannedAmount} DESC
      ''',
      [planId],
    );
    return rows.map(SpendingPlanItemMapper.fromRow).toList();
  }

  Future<int> upsertItem(SpendingPlanItem item) async {
    if (item.isPersisted) {
      final row = SpendingPlanItemMapper.toRow(
        item.copyWith(updatedAt: DateTime.now()),
      )..remove(SpendingPlanItemColumns.createdAt);
      await _db.update(
        Tables.spendingPlanItems,
        row,
        where: '${SpendingPlanItemColumns.id} = ?',
        whereArgs: [item.id],
      );
      return item.id;
    }
    return _db.insert(
      Tables.spendingPlanItems,
      SpendingPlanItemMapper.toRow(item),
    );
  }

  Future<int> deleteItem(int itemId) => _db.delete(
    Tables.spendingPlanItems,
    where: '${SpendingPlanItemColumns.id} = ?',
    whereArgs: [itemId],
  );

  /// Plan items paired with the actual spend in each allocated category, plus
  /// the plan-wide expense total — two queries rather than one per item.
  Future<SpendingPlanProgress> findProgress(SpendingPlan plan) async {
    final itemRows = await _db.rawQuery(
      '''
      SELECT i.*,
             c.${CategoryColumns.name}  AS ${SpendingPlanItemMapper.aliasCategoryName},
             c.${CategoryColumns.icon}  AS ${SpendingPlanItemMapper.aliasCategoryIcon},
             c.${CategoryColumns.color} AS ${SpendingPlanItemMapper.aliasCategoryColor},
             COALESCE((
               SELECT SUM(t.${TransactionColumns.amount})
               FROM ${Tables.transactions} t
               WHERE t.${TransactionColumns.type} = 'expense'
                 AND t.${TransactionColumns.categoryId} = i.${SpendingPlanItemColumns.categoryId}
                 AND t.${TransactionColumns.transactionDate} BETWEEN ? AND ?
             ), 0) AS spent
      FROM ${Tables.spendingPlanItems} i
      LEFT JOIN ${Tables.categories} c
             ON c.${CategoryColumns.id} = i.${SpendingPlanItemColumns.categoryId}
      WHERE i.${SpendingPlanItemColumns.planId} = ?
      ORDER BY i.${SpendingPlanItemColumns.plannedAmount} DESC
      ''',
      [AppDate.toDb(plan.startDate), AppDate.toDb(plan.endDate), plan.id],
    );

    final totalRows = await _db.rawQuery(
      'SELECT COALESCE(SUM(${TransactionColumns.amount}), 0) AS total '
      'FROM ${Tables.transactions} '
      "WHERE ${TransactionColumns.type} = 'expense' "
      'AND ${TransactionColumns.transactionDate} BETWEEN ? AND ?',
      [AppDate.toDb(plan.startDate), AppDate.toDb(plan.endDate)],
    );

    return SpendingPlanProgress(
      plan: plan,
      items: itemRows
          .map(
            (row) => SpendingPlanItemProgress(
              item: SpendingPlanItemMapper.fromRow(row),
              spent: row.readDoubleOr('spent'),
            ),
          )
          .toList(),
      totalSpent: totalRows.first.readDoubleOr('total'),
    );
  }
}
