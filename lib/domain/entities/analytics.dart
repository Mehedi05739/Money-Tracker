import '../../core/enums/trend_granularity.dart';
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

/// Totals for an arbitrary [TransactionFilter].
///
/// Distinct from [PeriodTotals], which is tied to a date range: this is what a
/// filtered ledger view sums to, so "total expenses for Groceries on the Cash
/// account this week" is one query rather than a page of rows added up in Dart.
class TransactionTotals {
  const TransactionTotals({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.count,
  });

  const TransactionTotals.empty()
    : income = 0,
      expense = 0,
      transfer = 0,
      count = 0;

  final double income;
  final double expense;

  /// Moved between the user's own accounts. Excluded from [net] because it
  /// changes no net worth.
  final double transfer;

  final int count;

  double get net => income - expense;

  /// Share of income kept, 0–100. Zero income means nothing was saved.
  double get savingsRate => income <= 0 ? 0 : (net / income) * 100;

  bool get isEmpty => count == 0;
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

/// A category breakdown together with the totals it was drawn from.
///
/// [entries] is capped by the caller's limit, so it is usually *not* the whole
/// picture. Carrying [total] separately means a share is a share of everything
/// the user spent, not of whatever survived the `LIMIT` — and the UI can label
/// the remainder honestly instead of implying the top slices are all there is.
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.entries,
    required this.total,
    required this.categoryCount,
  });

  const CategoryBreakdown.empty()
    : entries = const [],
      total = 0,
      categoryCount = 0;

  final List<CategorySpending> entries;

  /// Total across every category in the period, including those not listed.
  final double total;

  /// How many distinct categories contributed, listed or not.
  final int categoryCount;

  bool get isEmpty => entries.isEmpty;

  /// Spending in categories beyond the listed ones.
  double get otherAmount {
    final listed = entries.fold<double>(0, (sum, e) => sum + e.amount);
    final remainder = total - listed;
    // Guard against float dust presenting as a phantom slice.
    return remainder < 0.005 ? 0 : remainder;
  }

  bool get hasOther => otherAmount > 0;

  double get otherShare => total <= 0 ? 0 : (otherAmount / total) * 100;

  CategorySpending? get top => entries.isEmpty ? null : entries.first;
}

/// One account's share of the period's spending.
class AccountSpending {
  const AccountSpending({
    required this.accountId,
    required this.accountName,
    required this.amount,
    required this.transactionCount,
    this.accountColor,
    this.accountIcon,
    this.share = 0,
  });

  final int accountId;
  final String accountName;
  final String? accountIcon;
  final int? accountColor;
  final double amount;
  final int transactionCount;

  /// Percentage of the period total, filled in once the grand total is known.
  final double share;

  AccountSpending withShare(double total) => AccountSpending(
    accountId: accountId,
    accountName: accountName,
    accountIcon: accountIcon,
    accountColor: accountColor,
    amount: amount,
    transactionCount: transactionCount,
    share: total <= 0 ? 0 : (amount / total) * 100,
  );
}

/// Spending grouped by the account it left, with the total it was measured
/// against.
///
/// Transfers are excluded, so this answers "which account did my spending come
/// out of", not "which account did money move through".
class AccountBreakdown {
  const AccountBreakdown({required this.entries, required this.total});

  const AccountBreakdown.empty() : entries = const [], total = 0;

  final List<AccountSpending> entries;
  final double total;

  bool get isEmpty => entries.isEmpty;

  AccountSpending? get top => entries.isEmpty ? null : entries.first;
}

/// The single heaviest spending day in a period.
///
/// Read straight from SQL rather than by scanning the trend series, so it stays
/// a real *day* even when the chart is bucketed by month.
class DaySpending {
  const DaySpending({
    required this.date,
    required this.amount,
    required this.transactionCount,
  });

  final DateTime date;
  final double amount;
  final int transactionCount;
}

/// A running savings balance across the period's buckets.
///
/// [cumulative] is what the chart plots: net for the bucket added to everything
/// before it, so the line shows savings accumulating rather than jittering
/// around zero.
class SavingsPoint {
  const SavingsPoint({
    required this.label,
    required this.date,
    required this.net,
    required this.cumulative,
  });

  final String label;
  final DateTime date;
  final double net;
  final double cumulative;
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

/// The four period totals the dashboard header needs, read in one pass.
///
/// Kept together because they come from a single query: computing them
/// separately meant four scans of the same table for numbers that sit inches
/// apart on screen.
class DashboardTotals {
  const DashboardTotals({
    required this.current,
    required this.previous,
    required this.todaySpend,
    required this.monthSpend,
  });

  DashboardTotals.empty(DateRange range)
    : current = PeriodTotals.empty(range),
      previous = PeriodTotals.empty(range.previous),
      todaySpend = 0,
      monthSpend = 0;

  final PeriodTotals current;
  final PeriodTotals previous;
  final double todaySpend;
  final double monthSpend;
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
    required this.breakdown,
    required this.trend,
    this.accountId,
    this.accountName,
  });

  DashboardSummary.empty(this.range)
    : totals = PeriodTotals.empty(range),
      previousTotals = PeriodTotals.empty(range),
      totalBalance = 0,
      todaySpend = 0,
      monthSpend = 0,
      breakdown = const CategoryBreakdown.empty(),
      trend = const [],
      accountId = null,
      accountName = null;

  final DateRange range;
  final PeriodTotals totals;
  final PeriodTotals previousTotals;
  final double totalBalance;
  final double todaySpend;
  final double monthSpend;
  final CategoryBreakdown breakdown;
  final List<TrendPoint> trend;

  /// The account the figures are scoped to, or `null` for all accounts.
  final int? accountId;
  final String? accountName;

  bool get isScopedToAccount => accountId != null;

  List<CategorySpending> get topCategories => breakdown.entries;

  CategorySpending? get highestCategory => breakdown.top;

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

/// Everything the Reports tab draws from the analytics layer, assembled in one
/// repository round trip.
///
/// Mirrors [DashboardSummary]: the alternative is each chart asking for its own
/// slice, which turns one screen into a dozen independent queries over the same
/// table.
class ReportSnapshot {
  const ReportSnapshot({
    required this.range,
    required this.granularity,
    required this.totals,
    required this.previousTotals,
    required this.trend,
    required this.savingsTrend,
    required this.categoryBreakdown,
    required this.accountBreakdown,
    this.highestDay,
  });

  ReportSnapshot.empty(this.range, this.granularity)
    : totals = PeriodTotals.empty(range),
      previousTotals = PeriodTotals.empty(range.previous),
      trend = const [],
      savingsTrend = const [],
      categoryBreakdown = const CategoryBreakdown.empty(),
      accountBreakdown = const AccountBreakdown.empty(),
      highestDay = null;

  final DateRange range;
  final TrendGranularity granularity;
  final PeriodTotals totals;
  final PeriodTotals previousTotals;

  /// Income and expense per bucket, at [granularity].
  final List<TrendPoint> trend;

  /// The same buckets carried forward as a running savings balance.
  final List<SavingsPoint> savingsTrend;

  final CategoryBreakdown categoryBreakdown;
  final AccountBreakdown accountBreakdown;

  /// The heaviest single day of spending, or `null` when nothing was spent.
  final DaySpending? highestDay;

  bool get isEmpty => totals.isEmpty;

  CategorySpending? get topCategory => categoryBreakdown.top;
  AccountSpending? get topAccount => accountBreakdown.top;

  /// Change in spending against the preceding equal-length window, signed.
  /// `null` when there is nothing to compare against.
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

  /// Running savings carried to the end of the period — the last point of
  /// [savingsTrend], which equals [PeriodTotals.netSavings].
  double get closingSavings =>
      savingsTrend.isEmpty ? totals.netSavings : savingsTrend.last.cumulative;
}
