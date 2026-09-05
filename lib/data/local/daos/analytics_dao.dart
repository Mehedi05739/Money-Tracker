import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_tables.dart';
import '../../../core/enums/transaction_type.dart';
import '../../../core/utils/date_range.dart';
import '../../../core/utils/date_utils.dart';
import '../../../domain/entities/analytics.dart';
import '../../models/row_reader.dart';

/// All reporting aggregates.
///
/// Every method is a single `GROUP BY` against an index — no query loads
/// transaction rows into Dart just to sum them. Transfers are excluded
/// throughout: moving money between own accounts is not income or expense.
class AnalyticsDao {
  const AnalyticsDao(this._db);

  final Database _db;

  static const String _excludeTransfers =
      "${TransactionColumns.type} <> 'transfer'";

  /// `AND account_id = ?` when the dashboard is scoped to one account.
  ///
  /// Returned as SQL plus its bound value so the caller can never interleave
  /// them wrongly — the value is always a parameter, never interpolated.
  /// [alias] is the table alias used by the query, if any.
  static ({String sql, List<Object?> args}) _accountScope(
    int? accountId, {
    String alias = '',
  }) {
    if (accountId == null) return (sql: '', args: const []);
    final prefix = alias.isEmpty ? '' : '$alias.';
    return (
      sql: ' AND $prefix${TransactionColumns.accountId} = ?',
      args: [accountId],
    );
  }

  /// Every headline figure the dashboard shows, in one pass.
  ///
  /// The current period, the preceding one, today and this month used to be
  /// four separate queries over the same table. Conditional aggregation reads
  /// the widest span once and buckets the rows as it goes.
  Future<DashboardTotals> dashboardTotals(
    DateRange range, {
    int? accountId,
  }) async {
    final now = DateTime.now();
    final previous = range.previous;
    final today = DateRange(
      start: AppDate.startOfDay(now),
      end: AppDate.endOfDay(now),
    );
    final month = DateRange.fromPreset(DateRangePreset.thisMonth, now: now);

    // Scan only as far as the widest window actually needs.
    final spanStart = [
      range.start,
      previous.start,
      today.start,
      month.start,
    ].reduce((a, b) => a.isBefore(b) ? a : b);
    final spanEnd = [
      range.end,
      previous.end,
      today.end,
      month.end,
    ].reduce((a, b) => a.isAfter(b) ? a : b);

    final scope = _accountScope(accountId);

    String sumWhen(String type, String startArg, String endArg) =>
        "COALESCE(SUM(CASE WHEN ${TransactionColumns.type} = '$type' "
        'AND ${TransactionColumns.transactionDate} BETWEEN $startArg AND $endArg '
        'THEN ${TransactionColumns.amount} END), 0)';

    final rows = await _db.rawQuery(
      '''
      SELECT
        ${sumWhen('income', '?', '?')}  AS income,
        ${sumWhen('expense', '?', '?')} AS expense,
        COUNT(CASE WHEN ${TransactionColumns.transactionDate} BETWEEN ? AND ?
                   THEN 1 END)          AS tx_count,
        ${sumWhen('income', '?', '?')}  AS prev_income,
        ${sumWhen('expense', '?', '?')} AS prev_expense,
        ${sumWhen('expense', '?', '?')} AS today_expense,
        ${sumWhen('expense', '?', '?')} AS month_expense
      FROM ${Tables.transactions}
      WHERE $_excludeTransfers
        AND ${TransactionColumns.transactionDate} BETWEEN ? AND ?
        ${scope.sql}
      ''',
      [
        range.startDb, range.endDb, // income
        range.startDb, range.endDb, // expense
        range.startDb, range.endDb, // count
        previous.startDb, previous.endDb,
        previous.startDb, previous.endDb,
        today.startDb, today.endDb,
        month.startDb, month.endDb,
        AppDate.toDb(spanStart), AppDate.toDb(spanEnd),
        ...scope.args,
      ],
    );

    final row = rows.first;
    return DashboardTotals(
      current: PeriodTotals(
        income: row.readDoubleOr('income'),
        expense: row.readDoubleOr('expense'),
        transactionCount: row.readIntOrNull('tx_count') ?? 0,
        range: range,
      ),
      previous: PeriodTotals(
        income: row.readDoubleOr('prev_income'),
        expense: row.readDoubleOr('prev_expense'),
        range: previous,
      ),
      todaySpend: row.readDoubleOr('today_expense'),
      monthSpend: row.readDoubleOr('month_expense'),
    );
  }

  Future<PeriodTotals> totals(DateRange range) async {
    final rows = await _db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN ${TransactionColumns.type} = 'income'
                          THEN ${TransactionColumns.amount} END), 0) AS income,
        COALESCE(SUM(CASE WHEN ${TransactionColumns.type} = 'expense'
                          THEN ${TransactionColumns.amount} END), 0) AS expense,
        COUNT(*) AS tx_count
      FROM ${Tables.transactions}
      WHERE $_excludeTransfers
        AND ${TransactionColumns.transactionDate} BETWEEN ? AND ?
      ''',
      [range.startDb, range.endDb],
    );

    final row = rows.first;
    return PeriodTotals(
      income: row.readDoubleOr('income'),
      expense: row.readDoubleOr('expense'),
      transactionCount: row.readIntOrNull('tx_count') ?? 0,
      range: range,
    );
  }

  /// Sum of expenses on a single day — used for the dashboard's "today" tile.
  Future<double> spendOnDay(DateTime day) async {
    final range = DateRange(
      start: AppDate.startOfDay(day),
      end: AppDate.endOfDay(day),
    );
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(${TransactionColumns.amount}), 0) AS total '
      'FROM ${Tables.transactions} '
      "WHERE ${TransactionColumns.type} = 'expense' "
      'AND ${TransactionColumns.transactionDate} BETWEEN ? AND ?',
      [range.startDb, range.endDb],
    );
    return rows.first.readDoubleOr('total');
  }

  Future<double> expenseTotal(DateRange range, {int? categoryId}) async {
    final rows = await _db.rawQuery(
      'SELECT COALESCE(SUM(${TransactionColumns.amount}), 0) AS total '
      'FROM ${Tables.transactions} '
      "WHERE ${TransactionColumns.type} = 'expense' "
      'AND ${TransactionColumns.transactionDate} BETWEEN ? AND ?'
      '${categoryId != null ? ' AND ${TransactionColumns.categoryId} = ?' : ''}',
      [range.startDb, range.endDb, ?categoryId],
    );
    return rows.first.readDoubleOr('total');
  }

  /// Top [limit] categories, plus the totals they were drawn from.
  ///
  /// The grand total is a second scalar aggregate rather than a sum of the
  /// returned rows: those are truncated by `LIMIT`, so folding them would make
  /// every share a share of the visible slice instead of the real spend.
  Future<CategoryBreakdown> categoryBreakdown(
    DateRange range, {
    TransactionType type = TransactionType.expense,
    int limit = 20,
    int? accountId,
  }) async {
    // The grouped query aliases the table as `t`; the total query does not.
    final scopedT = _accountScope(accountId, alias: 't');
    final scope = _accountScope(accountId);
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
      WHERE t.${TransactionColumns.type} = ?
        AND t.${TransactionColumns.transactionDate} BETWEEN ? AND ?
        ${scopedT.sql}
      GROUP BY t.${TransactionColumns.categoryId}
      ORDER BY total DESC
      LIMIT ?
      ''',
      [type.name, range.startDb, range.endDb, ...scopedT.args, limit],
    );

    final totals = await _db.rawQuery(
      '''
      SELECT COALESCE(SUM(${TransactionColumns.amount}), 0) AS grand_total,
             COUNT(DISTINCT ${TransactionColumns.categoryId}) AS category_count
      FROM ${Tables.transactions}
      WHERE ${TransactionColumns.type} = ?
        AND ${TransactionColumns.transactionDate} BETWEEN ? AND ?
        ${scope.sql}
      ''',
      [type.name, range.startDb, range.endDb, ...scope.args],
    );

    final grandTotal = totals.first.readDoubleOr('grand_total');

    return CategoryBreakdown(
      total: grandTotal,
      categoryCount: totals.first.readIntOrNull('category_count') ?? 0,
      entries: rows
          .map(
            (row) => CategorySpending(
              categoryId: row.readIntOrNull('category_id'),
              categoryName: row.readString('category_name'),
              categoryIcon: row.readStringOrNull('category_icon'),
              categoryColor: row.readIntOrNull('category_color'),
              amount: row.readDoubleOr('total'),
              transactionCount: row.readIntOrNull('tx_count') ?? 0,
            ).withShare(grandTotal),
          )
          .toList(),
    );
  }

  /// One point per day that has data. Gaps are filled by the caller so the
  /// query stays a plain aggregate.
  Future<List<TrendPoint>> dailyTrend(DateRange range, {int? accountId}) async {
    final scope = _accountScope(accountId);
    final rows = await _db.rawQuery(
      '''
      SELECT substr(${TransactionColumns.transactionDate}, 1, 10) AS day,
             COALESCE(SUM(CASE WHEN ${TransactionColumns.type} = 'income'
                               THEN ${TransactionColumns.amount} END), 0) AS income,
             COALESCE(SUM(CASE WHEN ${TransactionColumns.type} = 'expense'
                               THEN ${TransactionColumns.amount} END), 0) AS expense
      FROM ${Tables.transactions}
      WHERE $_excludeTransfers
        AND ${TransactionColumns.transactionDate} BETWEEN ? AND ?
        ${scope.sql}
      GROUP BY day
      ORDER BY day ASC
      ''',
      [range.startDb, range.endDb, ...scope.args],
    );

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

  Future<List<TrendPoint>> monthlyTrend(
    DateRange range, {
    int? accountId,
  }) async {
    final scope = _accountScope(accountId);
    final rows = await _db.rawQuery(
      '''
      SELECT substr(${TransactionColumns.transactionDate}, 1, 7) AS month,
             COALESCE(SUM(CASE WHEN ${TransactionColumns.type} = 'income'
                               THEN ${TransactionColumns.amount} END), 0) AS income,
             COALESCE(SUM(CASE WHEN ${TransactionColumns.type} = 'expense'
                               THEN ${TransactionColumns.amount} END), 0) AS expense
      FROM ${Tables.transactions}
      WHERE $_excludeTransfers
        AND ${TransactionColumns.transactionDate} BETWEEN ? AND ?
        ${scope.sql}
      GROUP BY month
      ORDER BY month ASC
      ''',
      [range.startDb, range.endDb, ...scope.args],
    );

    return rows.map((row) {
      final month = DateTime.parse('${row.readString('month')}-01');
      return TrendPoint(
        label: AppDate.monthsShort[month.month - 1],
        date: month,
        income: row.readDoubleOr('income'),
        expense: row.readDoubleOr('expense'),
      );
    }).toList();
  }

  /// Fills days with no transactions so the chart shows a continuous axis.
  ///
  /// Stops at today: padding out the rest of the current month with empty days
  /// would push the real data off the end of the chart.
  static List<TrendPoint> fillDailyGaps(
    List<TrendPoint> points,
    DateRange range, {
    int maxDays = 62,
  }) {
    if (range.dayCount > maxDays) return points;

    final today = AppDate.startOfDay(DateTime.now());
    final start = AppDate.startOfDay(range.start);
    final lastDay = AppDate.startOfDay(range.end).isAfter(today)
        ? today
        : AppDate.startOfDay(range.end);

    // A range entirely in the future has nothing to plot.
    if (lastDay.isBefore(start)) return points;

    final byDay = {
      for (final point in points) AppDate.toDayKey(point.date): point,
    };

    return List.generate(AppDate.daysBetween(start, lastDay) + 1, (index) {
      final day = start.add(Duration(days: index));
      return byDay[AppDate.toDayKey(day)] ??
          TrendPoint(label: '${day.day}', date: day, income: 0, expense: 0);
    });
  }
}
