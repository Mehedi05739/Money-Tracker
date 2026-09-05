import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
import '../entities/analytics.dart';

/// Read-only aggregates. Every method maps to an indexed `GROUP BY` so report
/// screens never pull raw rows into Dart.
abstract class AnalyticsRepository {
  Future<Result<PeriodTotals>> getTotals(DateRange range);

  Future<Result<List<CategorySpending>>> getCategoryBreakdown(
    DateRange range, {
    TransactionType type = TransactionType.expense,
    int limit = 20,
  });

  /// One point per day in [range].
  Future<Result<List<TrendPoint>>> getDailyTrend(DateRange range);

  /// One point per calendar month in [range].
  Future<Result<List<TrendPoint>>> getMonthlyTrend(DateRange range);

  /// Everything the dashboard needs, batched to avoid a query per card.
  Future<Result<DashboardSummary>> getDashboardSummary(DateRange range);
}
