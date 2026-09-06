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

  static const String _selectWithJoins =
      '''
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

  /// [executor] lets a caller read inside an open transaction, so posting can
  /// re-read the rule under the same lock it writes with.
  Future<RecurringTransaction?> findById(
    int id, {
    DatabaseExecutor? executor,
  }) async {
    final rows = await (executor ?? _db).rawQuery(
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
    final row = RecurringMapper.toRow(rule.copyWith(updatedAt: DateTime.now()))
      ..remove(RecurringColumns.createdAt);
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
  /// Materialises everything [rule] owes up to the end of today.
  ///
  /// Duplicate prevention has two layers, and the second is the one that
  /// matters. The cursor (`next_run_date`) says where to resume; the
  /// `recurring_occurrences` ledger, with its unique index on
  /// `(recurring_id, occurrence_date)`, decides whether a given day may be
  /// written at all. Claiming the ledger row *before* inserting the transaction
  /// means a replayed run, two overlapping runs, or a cursor that was reset by
  /// an edit all collide with the index and post nothing.
  ///
  /// The rule is re-read inside the transaction rather than trusted from the
  /// caller: `runDue` fetches rules up front, and the startup catch-up can
  /// overlap with the user tapping "Run now", so the copy in hand may already
  /// be stale.
  Future<int> postDueOccurrences(RecurringTransaction rule) {
    return _db.transaction((txn) async {
      final current = await findById(rule.id, executor: txn);
      if (current == null || !current.isActive) return 0;

      final cutoff = AppDate.endOfDay(DateTime.now());
      var cursor = current.nextRunDate;
      var posted = 0;
      DateTime? lastPosted;

      while (!cursor.isAfter(cutoff) && posted < maxOccurrencesPerRun) {
        if (current.endDate != null &&
            cursor.isAfter(AppDate.endOfDay(current.endDate!))) {
          break;
        }

        final now = DateTime.now();

        // Claim the day first. A zero rowid means the unique index rejected
        // it — that occurrence is already processed, so skip the insert and
        // move on rather than writing a duplicate.
        final claimId = await txn.insert(Tables.recurringOccurrences, {
          RecurringOccurrenceColumns.recurringId: current.id,
          RecurringOccurrenceColumns.occurrenceDate: AppDate.toDayKey(cursor),
          RecurringOccurrenceColumns.postedAt: AppDate.toDb(now),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);

        if (claimId != 0) {
          final transactionId = await TransactionDao.insertWithinTransaction(
            txn,
            MoneyTransaction(
              id: 0,
              accountId: current.accountId,
              type: current.type,
              amount: current.amount,
              categoryId: current.categoryId,
              title: current.title,
              transactionDate: cursor,
              paymentMethod: current.paymentMethod,
              note: current.note,
              recurringId: current.id,
              createdAt: now,
              updatedAt: now,
            ),
          );

          await txn.update(
            Tables.recurringOccurrences,
            {RecurringOccurrenceColumns.transactionId: transactionId},
            where: '${RecurringOccurrenceColumns.id} = ?',
            whereArgs: [claimId],
          );

          posted += 1;
          lastPosted = cursor;
        }

        cursor = current.occurrenceAfter(cursor);
      }

      // The cursor advances even when every occurrence was already claimed, so
      // a rule that has been caught up stops being re-examined every launch.
      final ended =
          current.endDate != null &&
          cursor.isAfter(AppDate.endOfDay(current.endDate!));

      await txn.update(
        Tables.recurringTransactions,
        {
          RecurringColumns.nextRunDate: AppDate.toDb(cursor),
          if (lastPosted != null)
            RecurringColumns.lastRunDate: AppDate.toDb(lastPosted),
          if (ended) RecurringColumns.isActive: 0,
          RecurringColumns.updatedAt: AppDate.toDb(DateTime.now()),
        },
        where: '${RecurringColumns.id} = ?',
        whereArgs: [rule.id],
      );

      return posted;
    });
  }

  /// Whether [date]'s occurrence of [ruleId] has already been processed.
  ///
  /// The direct form of the question the ledger exists to answer.
  Future<bool> isOccurrenceProcessed(int ruleId, DateTime date) async {
    final rows = await _db.query(
      Tables.recurringOccurrences,
      columns: [RecurringOccurrenceColumns.id],
      where:
          '${RecurringOccurrenceColumns.recurringId} = ? '
          'AND ${RecurringOccurrenceColumns.occurrenceDate} = ?',
      whereArgs: [ruleId, AppDate.toDayKey(date)],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// The occurrences [ruleId] has produced, most recent first.
  Future<List<RecurringOccurrence>> findOccurrences(
    int ruleId, {
    int limit = 50,
  }) async {
    final rows = await _db.query(
      Tables.recurringOccurrences,
      where: '${RecurringOccurrenceColumns.recurringId} = ?',
      whereArgs: [ruleId],
      orderBy: '${RecurringOccurrenceColumns.occurrenceDate} DESC',
      limit: limit,
    );
    return rows.map(RecurringMapper.occurrenceFromRow).toList();
  }

  /// How many occurrences each rule has produced, in one grouped query.
  Future<Map<int, int>> occurrenceCounts() async {
    final rows = await _db.rawQuery(
      'SELECT ${RecurringOccurrenceColumns.recurringId} AS rule_id, '
      'COUNT(*) AS total '
      'FROM ${Tables.recurringOccurrences} '
      'GROUP BY ${RecurringOccurrenceColumns.recurringId}',
    );
    return {
      for (final row in rows)
        row.readIntOrNull('rule_id') ?? 0: row.readIntOrNull('total') ?? 0,
    };
  }
}
