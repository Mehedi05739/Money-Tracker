import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../domain/entities/budget_status.dart';
import '../../../../domain/entities/financial_goal.dart';
import '../../../../domain/entities/money_transaction.dart';
import '../../../../domain/entities/spending_plan_progress.dart';
import '../../../../domain/repositories/analytics_repository.dart';
import '../../../../domain/repositories/budget_repository.dart';
import '../../../../domain/repositories/goal_repository.dart';
import '../../../../domain/repositories/spending_plan_repository.dart';
import '../../../../domain/repositories/transaction_repository.dart';

/// Assembles the dashboard.
///
/// Everything derived — totals, shares, pace — is computed here or in SQL, so
/// the widget tree only formats values it is handed.
class DashboardController extends BaseController {
  DashboardController(
    this._analytics,
    this._transactions,
    this._budgets,
    this._plans,
    this._goals,
    this._events,
  );

  final AnalyticsRepository _analytics;
  final TransactionRepository _transactions;
  final BudgetRepository _budgets;
  final SpendingPlanRepository _plans;
  final GoalRepository _goals;
  final AppEvents _events;

  final Rx<DateRange> range = DateRange.fromPreset(DateRangePreset.thisMonth)
      .obs;

  final Rxn<DashboardSummary> summary = Rxn<DashboardSummary>();
  final RxList<MoneyTransaction> recent = <MoneyTransaction>[].obs;
  final RxList<BudgetStatus> budgets = <BudgetStatus>[].obs;
  final Rxn<SpendingPlanProgress> currentPlan = Rxn<SpendingPlanProgress>();
  final RxList<FinancialGoal> goals = <FinancialGoal>[].obs;

  /// Budgets that need attention, worst first — drives the alert card.
  List<BudgetStatus> get alerts {
    final flagged =
        budgets.where((status) => status.isExceeded || status.isAtRisk).toList()
          ..sort((a, b) => b.usagePercent.compareTo(a.usagePercent));
    return flagged;
  }

  bool get hasData => (summary.value?.totals.transactionCount ?? 0) > 0;

  Worker? _changeWorker;

  @override
  void onInit() {
    super.onInit();
    load();

    // The shell keeps this tab alive, so refresh when data changes elsewhere.
    _changeWorker = _events.listen(const [
      DataChange.transactions,
      DataChange.accounts,
      DataChange.budgets,
      DataChange.plans,
      DataChange.goals,
      DataChange.categories,
    ], () => load(showLoader: false));
  }

  @override
  void onClose() {
    _changeWorker?.dispose();
    super.onClose();
  }

  void changeRange(DateRange value) {
    if (value == range.value) return;
    range.value = value;
    load(showLoader: false);
  }

  /// Named `refreshData` because `GetxController.refresh()` already exists and
  /// means "rebuild listeners", not "reload from the database".
  Future<void> refreshData() => load(showLoader: false);

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    // Started together so the five reads overlap; awaited in order below.
    // The dashboard costs one round trip of wall time, not five.
    final summaryFuture = _analytics.getDashboardSummary(range.value);
    final recentFuture = _transactions.getRecent(
      limit: AppConstants.recentTransactionCount,
    );
    final budgetFuture = _budgets.getStatuses();
    final planFuture = _plans.getCurrentProgress();
    final goalFuture = _goals.getGoals(activeOnly: true);

    final summaryResult = await summaryFuture;
    final recentResult = await recentFuture;
    final budgetResult = await budgetFuture;
    final planResult = await planFuture;
    final goalResult = await goalFuture;

    // The summary is the screen; the rest are supporting cards. If a card's
    // query fails the dashboard still renders, just without that section.
    summaryResult.fold(
      onSuccess: (data) {
        summary.value = data;
        setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );

    if (summaryResult.isError) return;

    recent.assignAll(recentResult.dataOrNull ?? const []);
    budgets.assignAll(budgetResult.dataOrNull ?? const []);
    currentPlan.value = planResult.dataOrNull;
    goals.assignAll(goalResult.dataOrNull ?? const []);
  }
}
