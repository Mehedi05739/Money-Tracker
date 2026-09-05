import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../domain/entities/budget_status.dart';
import '../../../../domain/entities/financial_goal.dart';
import '../../../../domain/entities/money_transaction.dart';
import '../../../../domain/entities/spending_plan_progress.dart';
import '../../../../domain/repositories/dashboard_repository.dart';

/// Owns dashboard state. It holds one repository and no query logic of its own.
class DashboardController extends BaseController {
  DashboardController(this._repository, this._events);

  final DashboardRepository _repository;
  final AppEvents _events;

  final Rx<DateRange> range = DateRange.fromPreset(DateRangePreset.thisMonth)
      .obs;

  final Rxn<DashboardSummary> summary = Rxn<DashboardSummary>();
  final RxList<MoneyTransaction> recent = <MoneyTransaction>[].obs;
  final RxList<BudgetStatus> budgetStatuses = <BudgetStatus>[].obs;
  final Rxn<SpendingPlanProgress> currentPlan = Rxn<SpendingPlanProgress>();
  final RxList<FinancialGoal> goals = <FinancialGoal>[].obs;

  Worker? _changeWorker;

  /// Budget roll-up, computed here rather than in the card that draws it.
  BudgetOverview get budgetOverview => BudgetOverview.from(budgetStatuses);

  bool get hasData => (summary.value?.totals.transactionCount ?? 0) > 0;

  @override
  void onInit() {
    super.onInit();
    load();

    // The shell keeps this tab alive, so data can change while it is off
    // screen. Each kind reloads only the sections it actually invalidates —
    // editing a goal must not re-query the ledger.
    _changeWorker = _events.onChange(DataChange.values, _onDataChanged);
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

  Future<void> refreshData() => load(showLoader: false);

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final result = await _repository.load(range.value);

    result.fold(
      onSuccess: (data) {
        summary.value = data.summary;
        recent.assignAll(data.recent);
        budgetStatuses.assignAll(data.budgets);
        currentPlan.value = data.currentPlan;
        goals.assignAll(data.goals);
        setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  /// Maps a change to the sections it invalidates.
  ///
  /// Reloading everything on every event was measurably wasteful: adding a
  /// transaction re-queried goals, and saving a goal re-queried the ledger,
  /// budgets and the spending plan.
  void _onDataChanged(DataChange change) {
    switch (change) {
      case DataChange.transactions:
        // Money moved: totals, the recent list, budget spend and plan
        // progress are all derived from transactions.
        _reloadSummary();
        _reloadRecent();
        _reloadBudgets();
        _reloadPlan();
      case DataChange.accounts:
        // Balances feed the header; account names are joined into rows.
        _reloadSummary();
        _reloadRecent();
      case DataChange.categories:
        // Category names and colours are joined into the breakdown and rows.
        _reloadSummary();
        _reloadRecent();
      case DataChange.budgets:
        _reloadBudgets();
      case DataChange.plans:
        _reloadPlan();
      case DataChange.goals:
        _reloadGoals();
      case DataChange.recurring:
        // Editing a schedule shows nothing here until it posts, and posting
        // emits DataChange.transactions.
        break;
    }
  }

  Future<void> _reloadSummary() async {
    final result = await _repository.getSummary(range.value);
    final data = result.dataOrNull;
    if (data != null) summary.value = data;
  }

  Future<void> _reloadRecent() async {
    final result = await _repository.getRecent();
    final data = result.dataOrNull;
    if (data != null) recent.assignAll(data);
  }

  Future<void> _reloadBudgets() async {
    final result = await _repository.getBudgetStatuses();
    final data = result.dataOrNull;
    if (data != null) budgetStatuses.assignAll(data);
  }

  Future<void> _reloadPlan() async {
    final result = await _repository.getCurrentPlan();
    if (result.isSuccess) currentPlan.value = result.dataOrNull;
  }

  Future<void> _reloadGoals() async {
    final result = await _repository.getActiveGoals();
    final data = result.dataOrNull;
    if (data != null) goals.assignAll(data);
  }
}
