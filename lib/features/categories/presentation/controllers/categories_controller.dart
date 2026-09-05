import 'package:get/get.dart';

import '../../../../core/base/base_controller.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/repositories/category_repository.dart';

class CategoriesController extends BaseController {
  CategoriesController(this._repository, this._events);

  final CategoryRepository _repository;
  final AppEvents _events;

  final RxList<Category> categories = <Category>[].obs;
  final Rx<TransactionType> selectedType = TransactionType.expense.obs;
  final RxBool showArchived = false.obs;

  List<Category> get visible =>
      categories.where((c) => c.type == selectedType.value).toList();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool showLoader = true}) async {
    if (showLoader) setLoading();

    final result =
        await _repository.getCategories(includeArchived: showArchived.value);

    result.fold(
      onSuccess: (data) {
        categories.assignAll(data);
        visible.isEmpty ? setEmpty('No categories yet') : setLoaded();
        return null;
      },
      onError: (failure) {
        setError(failure);
        return null;
      },
    );
  }

  Future<void> refreshData() => load(showLoader: false);

  void changeType(TransactionType type) {
    if (type == selectedType.value) return;
    selectedType.value = type;
    // Reuses the already-loaded list; only the empty state may change.
    visible.isEmpty ? setEmpty('No categories yet') : setLoaded();
  }

  void toggleArchived() {
    showArchived.toggle();
    load(showLoader: false);
  }

  Future<void> setArchived(Category category, bool archived) async {
    final result = await _repository.setArchived(category.id, archived);
    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.categories);
        AppSnackbar.success(archived ? 'Category archived' : 'Category restored');
        load(showLoader: false);
        return null;
      },
      onError: (failure) {
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }

  Future<void> delete(Category category) async {
    final result = await _repository.delete(category.id);
    result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.categories);
        AppSnackbar.success('Category deleted');
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
