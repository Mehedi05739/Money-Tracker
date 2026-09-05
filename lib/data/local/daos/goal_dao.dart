import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../../../core/enums/goal_status.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/financial_goal.dart';
import '../../models/goal_mapper.dart';
import '../../models/row_reader.dart';

class GoalDao {
  const GoalDao(this._db);

  final Database _db;

  Future<List<FinancialGoal>> find({bool activeOnly = false}) async {
    final rows = await _db.query(
      Tables.financialGoals,
      where: activeOnly ? "${GoalColumns.status} = 'active'" : null,
      orderBy:
          "CASE ${GoalColumns.status} WHEN 'active' THEN 0 "
          "WHEN 'achieved' THEN 1 ELSE 2 END, "
          '${GoalColumns.targetDate} IS NULL, ${GoalColumns.targetDate} ASC',
    );
    return rows.map(GoalMapper.fromRow).toList();
  }

  Future<FinancialGoal?> findById(int id, {DatabaseExecutor? executor}) async {
    final rows = await (executor ?? _db).query(
      Tables.financialGoals,
      where: '${GoalColumns.id} = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : GoalMapper.fromRow(rows.first);
  }

  Future<int> insert(FinancialGoal goal) =>
      _db.insert(Tables.financialGoals, GoalMapper.toRow(goal));

  /// Leaves `current_amount` alone: it is derived from contributions, not the
  /// edit form.
  Future<int> update(FinancialGoal goal) {
    final row = GoalMapper.toRow(goal.copyWith(updatedAt: DateTime.now()))
      ..remove(GoalColumns.createdAt)
      ..remove(GoalColumns.currentAmount);
    return _db.update(
      Tables.financialGoals,
      row,
      where: '${GoalColumns.id} = ?',
      whereArgs: [goal.id],
    );
  }

  Future<int> delete(int id) => _db.delete(
    Tables.financialGoals,
    where: '${GoalColumns.id} = ?',
    whereArgs: [id],
  );

  Future<List<GoalContribution>> findContributions(int goalId) async {
    final rows = await _db.rawQuery(
      '''
      SELECT g.*, a.${AccountColumns.name} AS ${GoalContributionMapper.aliasAccountName}
      FROM ${Tables.goalContributions} g
      LEFT JOIN ${Tables.accounts} a
             ON a.${AccountColumns.id} = g.${GoalContributionColumns.accountId}
      WHERE g.${GoalContributionColumns.goalId} = ?
      ORDER BY g.${GoalContributionColumns.contributedAt} DESC, g.${GoalContributionColumns.id} DESC
      ''',
      [goalId],
    );
    return rows.map(GoalContributionMapper.fromRow).toList();
  }

  /// Inserts the contribution and rolls the goal's running total forward in one
  /// SQL transaction, flipping the status to achieved when the target is met.
  Future<FinancialGoal?> addContribution(GoalContribution contribution) {
    return _db.transaction((txn) async {
      await txn.insert(
        Tables.goalContributions,
        GoalContributionMapper.toRow(contribution),
      );
      return _refreshTotal(txn, contribution.goalId);
    });
  }

  /// Rewrites a contribution and rolls the goal's total forward in one SQL
  /// transaction.
  ///
  /// Editing an amount changes the goal's progress, so the two must move
  /// together or the stored total silently disagrees with its own history.
  Future<FinancialGoal?> updateContribution(GoalContribution contribution) {
    return _db.transaction((txn) async {
      final row = GoalContributionMapper.toRow(contribution)
        ..remove(GoalContributionColumns.createdAt)
        ..remove(GoalContributionColumns.goalId);

      final updated = await txn.update(
        Tables.goalContributions,
        row,
        where: '${GoalContributionColumns.id} = ?',
        whereArgs: [contribution.id],
      );
      if (updated == 0) return null;

      return _refreshTotal(txn, contribution.goalId);
    });
  }

  Future<FinancialGoal?> deleteContribution(int contributionId) {
    return _db.transaction((txn) async {
      final rows = await txn.query(
        Tables.goalContributions,
        where: '${GoalContributionColumns.id} = ?',
        whereArgs: [contributionId],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final goalId = rows.first.readInt(GoalContributionColumns.goalId);
      await txn.delete(
        Tables.goalContributions,
        where: '${GoalContributionColumns.id} = ?',
        whereArgs: [contributionId],
      );
      return _refreshTotal(txn, goalId);
    });
  }

  /// Recomputes `current_amount` from the contribution ledger, so the stored
  /// total can never drift from its history.
  static Future<FinancialGoal?> _refreshTotal(
    DatabaseExecutor txn,
    int goalId,
  ) async {
    final sumRows = await txn.rawQuery(
      'SELECT COALESCE(SUM(${GoalContributionColumns.amount}), 0) AS total '
      'FROM ${Tables.goalContributions} '
      'WHERE ${GoalContributionColumns.goalId} = ?',
      [goalId],
    );
    final total = sumRows.first.readDoubleOr('total');

    final goalRows = await txn.query(
      Tables.financialGoals,
      where: '${GoalColumns.id} = ?',
      whereArgs: [goalId],
      limit: 1,
    );
    if (goalRows.isEmpty) return null;

    final goal = GoalMapper.fromRow(goalRows.first);
    final achieved = total >= goal.targetAmount;

    // Only move between active and achieved — an archived goal stays archived.
    final status = goal.status == GoalStatus.archived
        ? GoalStatus.archived
        : (achieved ? GoalStatus.achieved : GoalStatus.active);

    await txn.update(
      Tables.financialGoals,
      {
        GoalColumns.currentAmount: total,
        GoalColumns.status: status.name,
        GoalColumns.updatedAt: AppDate.toDb(DateTime.now()),
      },
      where: '${GoalColumns.id} = ?',
      whereArgs: [goalId],
    );

    return goal.copyWith(currentAmount: total, status: status);
  }
}
