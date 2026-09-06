import '../../core/enums/trend_granularity.dart';
import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
import '../entities/analytics.dart';

/// Read-only aggregates. Every method maps to an indexed `GROUP BY` so report
/// screens never pull raw rows into Dart.
abstract class AnalyticsRepository {
  Future<Result<PeriodTotals>> getTotals(DateRange range);

  /// Top [limit] categories plus the period totals they were measured
  /// against, so shares stay relative to everything spent.
  Future<Result<CategoryBreakdown>> getCategoryBreakdown(
    DateRange range, {
    TransactionType type = TransactionType.expense,
    int limit = 20,
  });

  /// One point per day in [range].
  Future<Result<List<TrendPoint>>> getDailyTrend(DateRange range);

  /// One point per calendar month in [range].
  Future<Result<List<TrendPoint>>> getMonthlyTrend(DateRange range);

  /// Spending grouped by the account it came out of.
  Future<Result<AccountBreakdown>> getAccountBreakdown(
    DateRange range, {
    int limit = 20,
  });

  /// The heaviest single day of spending in [range], or `null` if none.
  Future<Result<DaySpending?>> getHighestSpendingDay(DateRange range);

  /// Every analytics figure the Reports tab needs, in one round trip.
  Future<Result<ReportSnapshot>> getReportSnapshot(
    DateRange range, {
    TrendGranularity granularity = TrendGranularity.daily,
    TransactionType breakdownType = TransactionType.expense,
  });

  /// Everything the dashboard needs.
  ///
  /// Pass [accountId] to scope every figure to one account; `null` means all
  /// accounts.
  Future<Result<DashboardSummary>> getDashboardSummary(
    DateRange range, {
    int? accountId,
  });
}
