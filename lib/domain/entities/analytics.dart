import '../../core/utils/date_range.dart';

/// Aggregate totals for one window, produced by a single SQL query rather than
/// by loading transactions into memory.
class PeriodTotals {
  const PeriodTotals({
    required this.income,
    required this.expense,
    required this.range,
    this.transactionCount = 0,
  });

  const PeriodTotals.empty(this.range)
      : income = 0,
        expense = 0,
        transactionCount = 0;

  final double income;
  final double expense;
  final int transactionCount;
  final DateRange range;

  double get netSavings => income - expense;

  /// Share of income kept, 0–100. Zero income means nothing was saved.
  double get savingsRate => income <= 0 ? 0 : (netSavings / income) * 100;

  double get averageDailySpend {
    final days = range.elapsedDays;
    return days <= 0 ? 0 : expense / days;
  }

  bool get isEmpty => transactionCount == 0;
}

/// One slice of the category breakdown.
class CategorySpending {
  const CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.transactionCount,
    this.categoryIcon,
    this.categoryColor,
    this.share = 0,
  });

  final int? categoryId;
  final String categoryName;
  final String? categoryIcon;
  final int? categoryColor;
  final double amount;
  final int transactionCount;

  /// Percentage of the period total, filled in by the repository once the
  /// grand total is known.
  final double share;

  CategorySpending withShare(double total) => CategorySpending(
        categoryId: categoryId,
        categoryName: categoryName,
        categoryIcon: categoryIcon,
        categoryColor: categoryColor,
        amount: amount,
        transactionCount: transactionCount,
        share: total <= 0 ? 0 : (amount / total) * 100,
      );
}

/// A point on the daily/monthly trend chart.
class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.date,
    required this.income,
    required this.expense,
  });

  final String label;
  final DateTime date;
  final double income;
  final double expense;

  double get net => income - expense;
}

/// Everything the dashboard renders, assembled in one repository round trip.
class DashboardSummary {
  const DashboardSummary({
    required this.range,
    required this.totals,
    required this.previousTotals,
    required this.totalBalance,
    required this.todaySpend,
    required this.monthSpend,
    required this.topCategories,
    required this.trend,
  });

  DashboardSummary.empty(this.range)
      : totals = PeriodTotals.empty(range),
        previousTotals = PeriodTotals.empty(range),
        totalBalance = 0,
        todaySpend = 0,
        monthSpend = 0,
        topCategories = const [],
        trend = const [];

  final DateRange range;
  final PeriodTotals totals;
  final PeriodTotals previousTotals;
  final double totalBalance;
  final double todaySpend;
  final double monthSpend;
  final List<CategorySpending> topCategories;
  final List<TrendPoint> trend;

  CategorySpending? get highestCategory =>
      topCategories.isEmpty ? null : topCategories.first;

  /// Change in spending versus the preceding equal-length window, as a signed
  /// percentage. `null` when there is no prior data to compare against.
  double? get expenseChangePercent {
    if (previousTotals.expense <= 0) return null;
    return ((totals.expense - previousTotals.expense) /
            previousTotals.expense) *
        100;
  }

  double? get incomeChangePercent {
    if (previousTotals.income <= 0) return null;
    return ((totals.income - previousTotals.income) / previousTotals.income) *
        100;
  }
}
