import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/financial_goal.dart';
import '../../../../domain/repositories/goal_repository.dart';

class GoalsController extends BaseController {
  GoalsController(this._repository, this._events);

  final GoalRepository _repository;
  final AppEvents _events;

  final RxList<FinancialGoal> goals = <FinancialGoal>[].obs;

  double get totalSaved =>
      goals.fold(0, (sum, goal) => sum + goal.currentAmount);

  double get totalTarget =>
      goals.fold(0, (sum, goal) => sum + goal.targetAmount);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final result = await _repository.getGoals();

    result.fold(
      onSuccess: (data) {
        goals.assignAll(data);
        data.isEmpty ? setEmpty('No goals yet') : setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  Future<void> delete(FinancialGoal goal) async {
    final result = await _repository.delete(goal.id);
    result.fold(
      onSuccess: (_) {
        goals.removeWhere((item) => item.id == goal.id);
        if (goals.isEmpty) setEmpty('No goals yet');
        _events.emit(DataChange.goals);
        AppSnackbar.success('Goal deleted');
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }
}
