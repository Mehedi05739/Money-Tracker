import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/budget_status.dart';
import '../../../../domain/repositories/budget_repository.dart';

class BudgetsController extends BaseController {
  BudgetsController(this._repository, this._events);

  final BudgetRepository _repository;
  final AppEvents _events;

  final RxList<BudgetStatus> statuses = <BudgetStatus>[].obs;
  final RxBool currentOnly = true.obs;

  /// Paused budgets are shown but excluded from the roll-up: a budget the
  /// user has switched off should not count toward what they have committed.
  List<BudgetStatus> get activeStatuses =>
      statuses.where((status) => !status.isPaused).toList();

  double get totalBudgeted =>
      activeStatuses.fold(0, (sum, status) => sum + status.limit);

  double get totalSpent =>
      activeStatuses.fold(0, (sum, status) => sum + status.spent);

  int get exceededCount => activeStatuses.where((s) => s.isExceeded).length;

  int get pausedCount => statuses.where((s) => s.isPaused).length;

  Worker? _changeWorker;

  @override
  void onInit() {
    super.onInit();
    load();

    // The shell keeps this tab alive, so refresh when data changes elsewhere.
    _changeWorker = _events.listen(const [
      DataChange.budgets,
      DataChange.transactions,
    ], () => load(showLoader: false));
  }

  @override
  void onClose() {
    _changeWorker?.dispose();
    super.onClose();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final result = await _repository.getStatuses(
      currentOnly: currentOnly.value,
      // Paused budgets stay on this screen: one the user cannot see is one
      // they cannot resume.
      includePaused: true,
    );

    result.fold(
      onSuccess: (data) {
        // Worst-tracking budgets first — that is what needs attention.
        statuses.assignAll(
          // Worst-tracking first, with paused budgets after the live ones.
          [...data]..sort((a, b) {
            if (a.isPaused != b.isPaused) return a.isPaused ? 1 : -1;
            return b.usagePercent.compareTo(a.usagePercent);
          }),
        );
        data.isEmpty
            ? setEmpty(
                currentOnly.value ? 'No budgets for today' : 'No budgets yet',
              )
            : setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  void toggleScope() {
    currentOnly.toggle();
    load(showLoader: false);
  }

  /// Pauses or resumes a budget from the list, without opening the form.
  Future<void> setActive(BudgetStatus status, bool active) async {
    final result = await _repository.setActive(status.budget.id, active);

    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.budgets);
        AppSnackbar.success(active ? 'Budget resumed' : 'Budget paused');
        load(showLoader: false);
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }

  Future<void> delete(BudgetStatus status) async {
    final result = await _repository.delete(status.budget.id);
    result.fold(
      onSuccess: (_) {
        statuses.removeWhere((item) => item.budget.id == status.budget.id);
        if (statuses.isEmpty) setEmpty('No budgets yet');
        _events.emit(DataChange.budgets);
        AppSnackbar.success('Budget deleted');
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }
}
