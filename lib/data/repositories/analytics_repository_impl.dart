import '../../core/enums/transaction_type.dart';
import '../../core/utils/date_range.dart';
import '../../core/utils/result.dart';
import '../../domain/entities/analytics.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../local/daos/account_dao.dart';
import '../local/daos/analytics_dao.dart';
import 'repository_guard.dart';

class AnalyticsRepositoryImpl implements AnalyticsRepository {
  const AnalyticsRepositoryImpl(this._dao, this._accountDao);

  final AnalyticsDao _dao;
  final AccountDao _accountDao;

  /// How many categories the dashboard donut shows before grouping the rest.
  static const int dashboardCategoryLimit = 6;

  @override
  Future<Result<PeriodTotals>> getTotals(DateRange range) =>
      guard(() => _dao.totals(range), context: 'totals');

  @override
  Future<Result<List<CategorySpending>>> getCategoryBreakdown(
    DateRange range, {
    TransactionType type = TransactionType.expense,
    int limit = 20,
  }) =>
      guard(
        () => _dao.categoryBreakdown(range, type: type, limit: limit),
        context: 'categoryBreakdown',
      );

  @override
  Future<Result<List<TrendPoint>>> getDailyTrend(DateRange range) => guard(
        () async => AnalyticsDao.fillDailyGaps(
          await _dao.dailyTrend(range),
          range,
        ),
        context: 'dailyTrend',
      );

  @override
  Future<Result<List<TrendPoint>>> getMonthlyTrend(DateRange range) =>
      guard(() => _dao.monthlyTrend(range), context: 'monthlyTrend');

  /// Issues the dashboard's queries concurrently on the shared connection, so
  /// the screen costs one await instead of a serial chain of eight.
  @override
  Future<Result<DashboardSummary>> getDashboardSummary(DateRange range) {
    return guard(() async {
      final now = DateTime.now();
      final monthRange = DateRange.fromPreset(DateRangePreset.thisMonth);

      final results = await Future.wait([
        _dao.totals(range),
        _dao.totals(range.previous),
        _accountDao.totalBalance(),
        _dao.spendOnDay(now),
        _dao.expenseTotal(monthRange),
        _dao.categoryBreakdown(range, limit: dashboardCategoryLimit),
        _trendFor(range),
      ]);

      return DashboardSummary(
        range: range,
        totals: results[0] as PeriodTotals,
        previousTotals: results[1] as PeriodTotals,
        totalBalance: results[2] as double,
        todaySpend: results[3] as double,
        monthSpend: results[4] as double,
        topCategories: results[5] as List<CategorySpending>,
        trend: results[6] as List<TrendPoint>,
      );
    }, context: 'dashboardSummary');
  }

  /// Long windows are charted by month; short ones day by day.
  Future<List<TrendPoint>> _trendFor(DateRange range) async {
    if (range.dayCount > 62) return _dao.monthlyTrend(range);
    return AnalyticsDao.fillDailyGaps(await _dao.dailyTrend(range), range);
  }
}
