import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/spending_plan.dart';
import '../../../../domain/entities/spending_plan_progress.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/spending_plan_repository.dart';

/// One plan with its allocations and live actuals.
class PlanDetailController extends BaseController {
  PlanDetailController(this._repository, this._categories, this._events);

  final SpendingPlanRepository _repository;
  final CategoryRepository _categories;
  final AppEvents _events;

  final Rxn<SpendingPlanProgress> progress = Rxn<SpendingPlanProgress>();
  final RxList<Category> categories = <Category>[].obs;
  final RxBool isSaving = false.obs;

  late final int planId;

  /// Categories not yet allocated in this plan — one line per category.
  List<Category> get unallocatedCategories {
    final used =
        progress.value?.items
            .map((item) => item.item.categoryId)
            .whereType<int>()
            .toSet() ??
        const <int>{};
    return categories.where((c) => !used.contains(c.id)).toList();
  }

  @override
  void onInit() {
    super.onInit();
    planId = Get.arguments is int ? Get.arguments as int : 0;
    load();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final progressFuture = _repository.getProgress(planId);
    final categoryFuture = _categories.getCategories(
      type: TransactionType.expense,
    );

    final progressResult = await progressFuture;
    categories.assignAll((await categoryFuture).dataOrNull ?? const []);

    progressResult.fold(
      onSuccess: (data) {
        progress.value = data;
        setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  Future<bool> addAllocation({
    required Category category,
    required double amount,
  }) async {
    final plan = progress.value?.plan;
    if (plan == null) return false;

    isSaving.value = true;
    final now = DateTime.now();
    final result = await _repository.upsertItem(
      SpendingPlanItem(
        id: 0,
        planId: plan.id,
        categoryId: category.id,
        plannedAmount: Validators.normalizeAmount(amount),
        createdAt: now,
        updatedAt: now,
      ),
    );
    isSaving.value = false;

    return result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.plans);
        AppSnackbar.success('Allocation added');
        load(showLoader: false);
        return true;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return false;
      },
    );
  }

  Future<bool> updateAllocation(SpendingPlanItem item, double amount) async {
    isSaving.value = true;
    final result = await _repository.upsertItem(
      item.copyWith(plannedAmount: Validators.normalizeAmount(amount)),
    );
    isSaving.value = false;

    return result.fold(
      onSuccess: (_) {
        load(showLoader: false);
        return true;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return false;
      },
    );
  }

  Future<void> removeAllocation(SpendingPlanItem item) async {
    final result = await _repository.deleteItem(item.id);
    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.plans);
        AppSnackbar.success('Allocation removed');
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
