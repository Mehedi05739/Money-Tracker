import '../../core/enums/trend_granularity.dart';
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
  Future<Result<CategoryBreakdown>> getCategoryBreakdown(
    DateRange range, {
    TransactionType type = TransactionType.expense,
    int limit = 20,
  }) => guard(
    () => _dao.categoryBreakdown(range, type: type, limit: limit),
    context: 'categoryBreakdown',
  );

  @override
  Future<Result<List<TrendPoint>>> getDailyTrend(DateRange range) => guard(
    () async => AnalyticsDao.fillDailyGaps(await _dao.dailyTrend(range), range),
    context: 'dailyTrend',
  );

  @override
  Future<Result<List<TrendPoint>>> getMonthlyTrend(DateRange range) =>
      guard(() => _dao.monthlyTrend(range), context: 'monthlyTrend');

  @override
  Future<Result<AccountBreakdown>> getAccountBreakdown(
    DateRange range, {
    int limit = 20,
  }) => guard(
    () => _dao.accountBreakdown(range, limit: limit),
    context: 'accountBreakdown',
  );

  @override
  Future<Result<DaySpending?>> getHighestSpendingDay(DateRange range) => guard(
    () => _dao.highestSpendingDay(range),
    context: 'highestSpendingDay',
  );

  /// Assembles the whole Reports tab in five queries.
  ///
  /// Each is a grouped aggregate over an index; none returns transaction rows.
  /// They are started together and awaited in order, so the screen costs one
  /// round trip of wall time rather than five.
  @override
  Future<Result<ReportSnapshot>> getReportSnapshot(
    DateRange range, {
    TrendGranularity granularity = TrendGranularity.daily,
    TransactionType breakdownType = TransactionType.expense,
  }) {
    return guard(() async {
      final totalsFuture = _dao.totals(range);
      final previousFuture = _dao.totals(range.previous);
      final trendFuture = granularity.isDaily
          ? _dao
                .dailyTrend(range)
                .then((points) => AnalyticsDao.fillDailyGaps(points, range))
          : _dao.monthlyTrend(range);
      final categoryFuture = _dao.categoryBreakdown(range, type: breakdownType);
      final accountFuture = _dao.accountBreakdown(range);
      final highestDayFuture = _dao.highestSpendingDay(range);

      final totals = await totalsFuture;
      final previous = await previousFuture;
      final trend = await trendFuture;

      return ReportSnapshot(
        range: range,
        granularity: granularity,
        totals: totals,
        previousTotals: previous,
        trend: trend,
        savingsTrend: _accumulate(trend),
        categoryBreakdown: await categoryFuture,
        accountBreakdown: await accountFuture,
        highestDay: await highestDayFuture,
      );
    }, context: 'reportSnapshot');
  }

  /// Carries each bucket's net forward into a running savings balance.
  ///
  /// A prefix sum over buckets the database already grouped — at most a few
  /// dozen points, never the underlying transactions. SQLite could do it with a
  /// window function, but those need SQLite 3.25+, which is not guaranteed on
  /// the older Android system libraries this app still runs on.
  static List<SavingsPoint> _accumulate(List<TrendPoint> trend) {
    var running = 0.0;
    return [
      for (final point in trend)
        SavingsPoint(
          label: point.label,
          date: point.date,
          net: point.net,
          cumulative: running += point.net,
        ),
    ];
  }

  /// Assembles the dashboard in four queries, not a dozen.
  ///
  /// Headline totals are one conditional aggregate; the category breakdown is
  /// a grouped query plus its grand total; the trend is one more. Everything
  /// starts together and is awaited in order, so the cost is one round trip of
  /// wall time.
  @override
  Future<Result<DashboardSummary>> getDashboardSummary(
    DateRange range, {
    int? accountId,
  }) {
    return guard(() async {
      final totalsFuture = _dao.dashboardTotals(range, accountId: accountId);
      final balanceFuture = accountId == null
          ? _accountDao.totalBalance()
          : _accountDao.balanceOf(accountId);
      final breakdownFuture = _dao.categoryBreakdown(
        range,
        limit: dashboardCategoryLimit,
        accountId: accountId,
      );
      final trendFuture = _trendFor(range, accountId: accountId);
      final accountFuture = accountId == null
          ? null
          : _accountDao.findById(accountId);

      final totals = await totalsFuture;
      final balance = await balanceFuture;
      final breakdown = await breakdownFuture;
      final trend = await trendFuture;
      final account = await accountFuture;

      return DashboardSummary(
        range: range,
        totals: totals.current,
        previousTotals: totals.previous,
        totalBalance: balance,
        todaySpend: totals.todaySpend,
        monthSpend: totals.monthSpend,
        breakdown: breakdown,
        trend: trend,
        accountId: accountId,
        accountName: account?.name,
      );
    }, context: 'dashboardSummary');
  }

  /// Long windows are charted by month; short ones day by day.
  Future<List<TrendPoint>> _trendFor(DateRange range, {int? accountId}) async {
    if (range.dayCount > 62) {
      return _dao.monthlyTrend(range, accountId: accountId);
    }
    return AnalyticsDao.fillDailyGaps(
      await _dao.dailyTrend(range, accountId: accountId),
      range,
    );
  }
}
