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
