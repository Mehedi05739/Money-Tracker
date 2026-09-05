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

  double get totalBudgeted =>
      statuses.fold(0, (sum, status) => sum + status.limit);

  double get totalSpent =>
      statuses.fold(0, (sum, status) => sum + status.spent);

  int get exceededCount => statuses.where((s) => s.isExceeded).length;

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
    );

    result.fold(
      onSuccess: (data) {
        // Worst-tracking budgets first — that is what needs attention.
        statuses.assignAll(
          [...data]..sort((a, b) => b.usagePercent.compareTo(a.usagePercent)),
        );
        data.isEmpty
            ? setEmpty(
                currentOnly.value
                    ? 'No active budgets for today'
                    : 'No budgets yet',
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
