import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/money_transaction.dart';
import '../../../domain/entities/recurring_transaction.dart';
import '../../models/recurring_mapper.dart';
import '../../models/row_reader.dart';
import 'transaction_dao.dart';

class RecurringDao {
  const RecurringDao(this._db);

  final Database _db;

  /// Guards against a pathological schedule (e.g. a daily rule dormant for
  /// years) writing an unbounded number of rows in one pass.
  static const int maxOccurrencesPerRun = 120;

  static const String _selectWithJoins = '''
    SELECT r.*,
           c.${CategoryColumns.name}  AS ${RecurringMapper.aliasCategoryName},
           c.${CategoryColumns.icon}  AS ${RecurringMapper.aliasCategoryIcon},
           c.${CategoryColumns.color} AS ${RecurringMapper.aliasCategoryColor},
           a.${AccountColumns.name}   AS ${RecurringMapper.aliasAccountName}
    FROM ${Tables.recurringTransactions} r
    LEFT JOIN ${Tables.categories} c ON c.${CategoryColumns.id} = r.${RecurringColumns.categoryId}
    LEFT JOIN ${Tables.accounts}   a ON a.${AccountColumns.id}  = r.${RecurringColumns.accountId}
  ''';

  Future<List<RecurringTransaction>> find({bool activeOnly = false}) async {
    final rows = await _db.rawQuery(
      '$_selectWithJoins '
      '${activeOnly ? 'WHERE r.${RecurringColumns.isActive} = 1' : ''} '
      'ORDER BY r.${RecurringColumns.nextRunDate} ASC',
    );
    return rows.map(RecurringMapper.fromRow).toList();
  }

  Future<RecurringTransaction?> findById(int id) async {
    final rows = await _db.rawQuery(
      '$_selectWithJoins WHERE r.${RecurringColumns.id} = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : RecurringMapper.fromRow(rows.first);
  }

  /// Active rules that are due today or overdue, and not past their end date.
  Future<List<RecurringTransaction>> findDue() async {
    final today = AppDate.toDb(AppDate.endOfDay(DateTime.now()));
    final rows = await _db.rawQuery(
      '$_selectWithJoins '
      'WHERE r.${RecurringColumns.isActive} = 1 '
      '  AND r.${RecurringColumns.autoPost} = 1 '
      '  AND r.${RecurringColumns.nextRunDate} <= ? '
      '  AND (r.${RecurringColumns.endDate} IS NULL '
      '       OR r.${RecurringColumns.nextRunDate} <= r.${RecurringColumns.endDate}) '
      'ORDER BY r.${RecurringColumns.nextRunDate} ASC',
      [today],
    );
    return rows.map(RecurringMapper.fromRow).toList();
  }

  Future<int> insert(RecurringTransaction rule) =>
      _db.insert(Tables.recurringTransactions, RecurringMapper.toRow(rule));

  Future<int> update(RecurringTransaction rule) {
    final row = RecurringMapper.toRow(
      rule.copyWith(updatedAt: DateTime.now()),
    )..remove(RecurringColumns.createdAt);
    return _db.update(
      Tables.recurringTransactions,
      row,
      where: '${RecurringColumns.id} = ?',
      whereArgs: [rule.id],
    );
  }

  Future<int> delete(int id) => _db.delete(
        Tables.recurringTransactions,
        where: '${RecurringColumns.id} = ?',
        whereArgs: [id],
      );

  Future<int> setActive(int id, bool active) => _db.update(
        Tables.recurringTransactions,
        {
          RecurringColumns.isActive: asDbBool(active),
          RecurringColumns.updatedAt: AppDate.toDb(DateTime.now()),
        },
        where: '${RecurringColumns.id} = ?',
        whereArgs: [id],
      );

  /// Writes every occurrence from `next_run_date` up to today and advances the
  /// schedule past them.
  ///
  /// The whole catch-up runs in one SQL transaction, so a crash mid-way cannot
  /// leave some transactions posted and the rule's cursor un-advanced — which
  /// would double-post them on the next launch.
  Future<int> postDueOccurrences(RecurringTransaction rule) {
    return _db.transaction((txn) async {
      final cutoff = AppDate.endOfDay(DateTime.now());
      var cursor = rule.nextRunDate;
      var posted = 0;
      DateTime? lastPosted;

      while (!cursor.isAfter(cutoff) && posted < maxOccurrencesPerRun) {
        if (rule.endDate != null && cursor.isAfter(AppDate.endOfDay(rule.endDate!))) {
          break;
        }

        final now = DateTime.now();
        await TransactionDao.insertWithinTransaction(
          txn,
          MoneyTransaction(
            id: 0,
            accountId: rule.accountId,
            type: rule.type,
            amount: rule.amount,
            categoryId: rule.categoryId,
            title: rule.title,
            transactionDate: cursor,
            paymentMethod: rule.paymentMethod,
            note: rule.note,
            recurringId: rule.id,
            createdAt: now,
            updatedAt: now,
          ),
        );

        posted += 1;
        lastPosted = cursor;
        cursor = rule.occurrenceAfter(cursor);
      }

      if (posted == 0) return 0;

      final ended = rule.endDate != null &&
          cursor.isAfter(AppDate.endOfDay(rule.endDate!));

      await txn.update(
        Tables.recurringTransactions,
        {
          RecurringColumns.nextRunDate: AppDate.toDb(cursor),
          RecurringColumns.lastRunDate: AppDate.toDb(lastPosted!),
          if (ended) RecurringColumns.isActive: 0,
          RecurringColumns.updatedAt: AppDate.toDb(DateTime.now()),
        },
        where: '${RecurringColumns.id} = ?',
        whereArgs: [rule.id],
      );

      return posted;
    });
  }
}
