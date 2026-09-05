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

  Future<List<CategorySpending>> categoryBreakdown(
    DateRange range, {
    TransactionType type = TransactionType.expense,
    int limit = 20,
  }) async {
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
      GROUP BY t.${TransactionColumns.categoryId}
      ORDER BY total DESC
      LIMIT ?
      ''',
      [type.name, range.startDb, range.endDb, limit],
    );

    final total = rows.fold<double>(
      0,
      (sum, row) => sum + row.readDoubleOr('total'),
    );

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

  /// One point per day that has data. Gaps are filled by the caller so the
  /// query stays a plain aggregate.
  Future<List<TrendPoint>> dailyTrend(DateRange range) async {
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
      GROUP BY day
      ORDER BY day ASC
      ''',
      [range.startDb, range.endDb],
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

  Future<List<TrendPoint>> monthlyTrend(DateRange range) async {
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
      GROUP BY month
      ORDER BY month ASC
      ''',
      [range.startDb, range.endDb],
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
