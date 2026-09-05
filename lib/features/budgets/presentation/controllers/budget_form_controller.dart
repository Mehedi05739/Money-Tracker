import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../core/enums/budget_period.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/budget.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/repositories/budget_repository.dart';
import '../../../../domain/repositories/category_repository.dart';

class BudgetFormController extends GetxController {
  BudgetFormController(this._repository, this._categories, this._events);

  final BudgetRepository _repository;
  final CategoryRepository _categories;
  final AppEvents _events;

  final TextEditingController amountField = TextEditingController();
  final TextEditingController alertField = TextEditingController(text: '80');

  final Rxn<Category> category = Rxn<Category>();
  final Rx<BudgetPeriod> period = BudgetPeriod.monthly.obs;
  final Rx<DateTime> startDate =
      DateTime.now().obs;
  final Rx<DateTime> endDate = DateTime.now().obs;
  final RxBool isActive = true.obs;
  final RxBool isOverall = false.obs;

  final RxList<Category> categories = <Category>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  Budget? _editing;

  bool get isEditing => _editing != null;

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  @override
  void onClose() {
    amountField.dispose();
    alertField.dispose();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    final result =
        await _categories.getCategories(type: TransactionType.expense);
    categories.assignAll(result.dataOrNull ?? const []);

    final argument = Get.arguments;
    if (argument is Budget) {
      _loadForEdit(argument);
    } else {
      _applyPeriod(BudgetPeriod.monthly);
    }

    isLoading.value = false;
  }

  void _loadForEdit(Budget budget) {
    _editing = budget;
    amountField.text = budget.amount.toStringAsFixed(2);
    alertField.text = '${budget.alertPercentage}';
    period.value = budget.period;
    startDate.value = budget.startDate;
    endDate.value = budget.endDate;
    isActive.value = budget.isActive;
    isOverall.value = budget.categoryId == null;
    category.value =
        categories.firstWhereOrNull((c) => c.id == budget.categoryId);
  }

  void changePeriod(BudgetPeriod value) {
    period.value = value;
    if (value != BudgetPeriod.custom) _applyPeriod(value);
  }

  /// Derives the date window from the chosen period, anchored on today.
  void _applyPeriod(BudgetPeriod value) {
    final now = DateTime.now();

    switch (value) {
      case BudgetPeriod.weekly:
        startDate.value = AppDate.startOfWeek(now);
        endDate.value = AppDate.endOfWeek(now);
      case BudgetPeriod.monthly:
        final range = DateRange.fromPreset(DateRangePreset.thisMonth);
        startDate.value = range.start;
        endDate.value = range.end;
      case BudgetPeriod.quarterly:
        startDate.value = AppDate.startOfMonth(now);
        endDate.value = AppDate.endOfMonth(AppDate.addMonths(now, 2));
      case BudgetPeriod.yearly:
        startDate.value = AppDate.startOfYear(now);
        endDate.value = AppDate.endOfYear(now);
      case BudgetPeriod.custom:
        break;
    }
  }

  void selectCategory(Category value) {
    category.value = value;
    isOverall.value = false;
    fieldErrors.remove('category');
  }

  void toggleOverall(bool value) {
    isOverall.value = value;
    if (value) category.value = null;
  }

  void selectRange(DateTime start, DateTime end) {
    period.value = BudgetPeriod.custom;
    startDate.value = AppDate.startOfDay(start);
    endDate.value = AppDate.endOfDay(end);
  }

  void toggleActive(bool value) => isActive.value = value;

  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    fieldErrors.clear();
    final amountError = Validators.amount(amountField.text, field: 'Budget');
    final alertError = Validators.percentage(alertField.text, field: 'Alert');

    if (amountError != null) fieldErrors['amount'] = amountError;
    if (alertError != null) fieldErrors['alertPercentage'] = alertError;
    if (!isOverall.value && category.value == null) {
      fieldErrors['category'] = 'Choose a category or budget all expenses';
    }
    if (fieldErrors.isNotEmpty) return false;

    isSubmitting.value = true;
    final now = DateTime.now();
    final draft = Budget(
      id: _editing?.id ?? 0,
      categoryId: isOverall.value ? null : category.value?.id,
      amount: Validators.normalizeAmount(
        Validators.parseAmount(amountField.text) ?? 0,
      ),
      period: period.value,
      startDate: startDate.value,
      endDate: endDate.value,
      alertPercentage: int.tryParse(alertField.text.trim()) ?? 80,
      isActive: isActive.value,
      createdAt: _editing?.createdAt ?? now,
      updatedAt: now,
    );

    final result =
        isEditing ? await _repository.update(draft) : await _repository.create(draft);
    isSubmitting.value = false;

    return result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.budgets);
        AppSnackbar.success(isEditing ? 'Budget updated' : 'Budget created');
        return true;
      },
      onError: (failure) {
        if (failure case ValidationFailure(fieldErrors: final errors)
            when errors.isNotEmpty) {
          fieldErrors.assignAll(errors);
        }
        AppSnackbar.error(failure.message);
        return false;
      },
    );
  }
}
