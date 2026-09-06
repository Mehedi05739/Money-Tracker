import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/enums/trend_granularity.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../domain/entities/budget_status.dart';
import '../../../../domain/entities/spending_plan_progress.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import '../../../../domain/repositories/budget_repository.dart';
import '../../../../domain/repositories/spending_plan_repository.dart';

/// Reports tab.
///
/// Holds no derived arithmetic of its own: every figure on screen comes from a
/// SQL aggregate, either through [ReportSnapshot] or through the budget and
/// plan repositories, which already join their spend in one pass.
class ReportsController extends BaseController {
  ReportsController(this._analytics, this._budgets, this._plans, this._events);

  final AnalyticsRepository _analytics;
  final BudgetRepository _budgets;
  final SpendingPlanRepository _plans;
  final AppEvents _events;

  final Rx<DateRange> range = DateRange.fromPreset(DateRangePreset.last30Days)
      .obs;
  final Rx<TransactionType> breakdownType = TransactionType.expense.obs;
  final Rx<TrendGranularity> granularity = TrendGranularity.daily.obs;

  final Rxn<ReportSnapshot> snapshot = Rxn<ReportSnapshot>();
  final RxList<BudgetStatus> budgetStatuses = <BudgetStatus>[].obs;
  final Rxn<SpendingPlanProgress> planProgress = Rxn<SpendingPlanProgress>();

  /// Budget totals across every active budget — the "budget utilization"
  /// headline.
  BudgetOverview get budgetOverview => BudgetOverview.from(budgetStatuses);

  /// Presets the report filter offers, in the order the brief lists them.
  static const List<DateRangePreset> presets = [
    DateRangePreset.last7Days,
    DateRangePreset.last30Days,
    DateRangePreset.last3Months,
    DateRangePreset.last6Months,
    DateRangePreset.lastYear,
  ];

  Worker? _changeWorker;

  @override
  void onInit() {
    super.onInit();
    load();

    // The shell keeps this tab alive, so refresh when data changes elsewhere.
    _changeWorker = _events.listen(const [
      DataChange.transactions,
      DataChange.categories,
      DataChange.budgets,
      DataChange.plans,
      DataChange.accounts,
    ], () => load(showLoader: false));
  }

  @override
  void onClose() {
    _changeWorker?.dispose();
    super.onClose();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final snapshotFuture = _analytics.getReportSnapshot(
      range.value,
      granularity: granularity.value,
      breakdownType: breakdownType.value,
    );
    // Budgets and plans carry their own periods, so they are fetched whole
    // rather than clipped to the report window.
    final budgetFuture = _budgets.getStatuses(includePaused: false);
    final planFuture = _plans.getCurrentProgress();

    final snapshotResult = await snapshotFuture;
    budgetStatuses.assignAll((await budgetFuture).dataOrNull ?? const []);
    planProgress.value = (await planFuture).dataOrNull;

    snapshotResult.fold(
      onSuccess: (data) {
        snapshot.value = data;
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
    // A year of daily bars is unreadable; long windows open on months.
    if (value.dayCount > 92 && granularity.value.isDaily) {
      granularity.value = TrendGranularity.monthly;
    }
    load(showLoader: false);
  }

  void changeBreakdownType(TransactionType type) {
    if (type == breakdownType.value) return;
    breakdownType.value = type;
    load(showLoader: false);
  }

  void changeGranularity(TrendGranularity value) {
    if (value == granularity.value) return;
    granularity.value = value;
    load(showLoader: false);
  }
}
