import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/spending_plan.dart';
import '../../../../domain/entities/spending_plan_progress.dart';
import '../../../../domain/repositories/spending_plan_repository.dart';

/// The Plans tab: the plan covering today, plus every other plan.
class PlansController extends BaseController {
  PlansController(this._repository, this._events);

  final SpendingPlanRepository _repository;
  final AppEvents _events;

  final RxList<SpendingPlan> plans = <SpendingPlan>[].obs;
  final Rxn<SpendingPlanProgress> current = Rxn<SpendingPlanProgress>();

  /// Plans other than the one already shown as the current plan.
  List<SpendingPlan> get otherPlans => plans
      .where((plan) => plan.id != current.value?.plan.id)
      .toList();

  Worker? _changeWorker;

  @override
  void onInit() {
    super.onInit();
    load();

    // The shell keeps this tab alive, so refresh when data changes elsewhere.
    _changeWorker =
        _events.listen(const [DataChange.plans, DataChange.transactions], () => load(showLoader: false));
  }

  @override
  void onClose() {
    _changeWorker?.dispose();
    super.onClose();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final plansFuture = _repository.getPlans();
    final currentFuture = _repository.getCurrentProgress();

    final plansResult = await plansFuture;
    current.value = (await currentFuture).dataOrNull;

    plansResult.fold(
      onSuccess: (data) {
        plans.assignAll(data);
        data.isEmpty ? setEmpty('No spending plans yet') : setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  Future<void> delete(SpendingPlan plan) async {
    final result = await _repository.delete(plan.id);
    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.plans);
        AppSnackbar.success('Plan deleted');
        load(showLoader: false);
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }
}
