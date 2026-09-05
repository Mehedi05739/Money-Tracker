import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../domain/repositories/analytics_repository.dart';

/// Reports tab: totals, trend and category breakdowns for a chosen window.
class ReportsController extends BaseController {
  ReportsController(this._analytics, this._events);

  final AnalyticsRepository _analytics;
  final AppEvents _events;

  final Rx<DateRange> range = DateRange.fromPreset(DateRangePreset.thisMonth)
      .obs;
  final Rx<TransactionType> breakdownType = TransactionType.expense.obs;

  final Rxn<PeriodTotals> totals = Rxn<PeriodTotals>();
  final Rxn<PeriodTotals> previousTotals = Rxn<PeriodTotals>();
  final RxList<CategorySpending> breakdown = <CategorySpending>[].obs;
  final RxList<TrendPoint> trend = <TrendPoint>[].obs;

  /// Charted by month for long windows, by day for short ones.
  bool get isMonthlyTrend => range.value.dayCount > 62;

  CategorySpending? get topCategory =>
      breakdown.isEmpty ? null : breakdown.first;

  /// Average spend across days that actually had spending — a better sense of
  /// "a typical spending day" than dividing by every calendar day.
  double get averageActiveDaySpend {
    final activeDays = trend.where((point) => point.expense > 0).toList();
    if (activeDays.isEmpty) return 0;
    final total = activeDays.fold<double>(
      0,
      (sum, point) => sum + point.expense,
    );
    return total / activeDays.length;
  }

  TrendPoint? get highestSpendPeriod {
    if (trend.isEmpty) return null;
    return trend.reduce((a, b) => a.expense >= b.expense ? a : b);
  }

  Worker? _changeWorker;

  @override
  void onInit() {
    super.onInit();
    load();

    // The shell keeps this tab alive, so refresh when data changes elsewhere.
    _changeWorker = _events.listen(const [
      DataChange.transactions,
      DataChange.categories,
    ], () => load(showLoader: false));
  }

  @override
  void onClose() {
    _changeWorker?.dispose();
    super.onClose();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final totalsFuture = _analytics.getTotals(range.value);
    final previousFuture = _analytics.getTotals(range.value.previous);
    final breakdownFuture = _analytics.getCategoryBreakdown(
      range.value,
      type: breakdownType.value,
    );
    final trendFuture = isMonthlyTrend
        ? _analytics.getMonthlyTrend(range.value)
        : _analytics.getDailyTrend(range.value);

    final totalsResult = await totalsFuture;
    previousTotals.value = (await previousFuture).dataOrNull;
    breakdown.assignAll((await breakdownFuture).dataOrNull ?? const []);
    trend.assignAll((await trendFuture).dataOrNull ?? const []);

    totalsResult.fold(
      onSuccess: (data) {
        totals.value = data;
        data.isEmpty ? setEmpty('No transactions in this period') : setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  void changeRange(DateRange value) {
    if (value == range.value) return;
    range.value = value;
    load(showLoader: false);
  }

  void changeBreakdownType(TransactionType type) {
    if (type == breakdownType.value) return;
    breakdownType.value = type;
    load(showLoader: false);
  }
}
