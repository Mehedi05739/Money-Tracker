import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../core/enums/plan_status.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/date_range.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/spending_plan.dart';
import '../../../../domain/repositories/spending_plan_repository.dart';

class PlanFormController extends GetxController {
  PlanFormController(this._repository, this._events);

  final SpendingPlanRepository _repository;
  final AppEvents _events;

  final TextEditingController nameField = TextEditingController();
  final TextEditingController incomeField = TextEditingController();
  final TextEditingController noteField = TextEditingController();

  final Rx<DateTime> startDate = DateTime.now().obs;
  final Rx<DateTime> endDate = DateTime.now().obs;
  final Rx<PlanStatus> status = PlanStatus.active.obs;

  final RxBool isSubmitting = false.obs;
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  SpendingPlan? _editing;

  bool get isEditing => _editing != null;

  @override
  void onInit() {
    super.onInit();
    _loadTemplate();

    final argument = Get.arguments;
    if (argument is SpendingPlan) {
      _editing = argument;
      nameField.text = argument.name;
      incomeField.text = argument.expectedIncome.toStringAsFixed(2);
      noteField.text = argument.note ?? '';
      startDate.value = argument.startDate;
      endDate.value = argument.endDate;
      status.value = argument.status;
    } else {
      final range = DateRange.fromPreset(DateRangePreset.thisMonth);
      startDate.value = range.start;
      endDate.value = range.end;
    }
  }

  /// Looks for the most recent finished plan so its allocations can be reused.
  Future<void> _loadTemplate() async {
    final result = await _repository.getPreviousPlan(startDate.value);
    template.value = result.dataOrNull;
  }

  @override
  void onClose() {
    nameField.dispose();
    incomeField.dispose();
    noteField.dispose();
    super.onClose();
  }

  /// Plans run for a calendar month, so the form picks a month rather than an
  /// arbitrary range — "1st to the 30th" is the only range that makes a
  /// monthly plan comparable to the next one.
  void selectMonth(DateTime month) {
    startDate.value = AppDate.startOfMonth(month);
    endDate.value = AppDate.endOfMonth(month);
  }

  DateTime get selectedMonth => startDate.value;

  /// Whether a plan already exists for the chosen month, to warn before a
  /// second overlapping plan is created.
  final RxnString monthConflict = RxnString();

  /// The previous plan offered as a starting point, if there is one.
  final Rxn<SpendingPlan> template = Rxn<SpendingPlan>();

  /// Copy last month's allocations into the new plan when saving.
  final RxBool copyPrevious = false.obs;

  void toggleCopyPrevious(bool value) => copyPrevious.value = value;

  void changeStatus(PlanStatus value) => status.value = value;

  Future<SpendingPlan?> submit() async {
    if (isSubmitting.value) return null;

    fieldErrors.clear();
    final nameError = Validators.name(nameField.text, field: 'Plan name');
    final incomeError = Validators.amount(
      incomeField.text,
      field: 'Expected income',
    );

    if (nameError != null) fieldErrors['name'] = nameError;
    if (incomeError != null) fieldErrors['expectedIncome'] = incomeError;
    if (fieldErrors.isNotEmpty) return null;

    isSubmitting.value = true;
    final now = DateTime.now();
    final note = noteField.text.trim();

    final draft = SpendingPlan(
      id: _editing?.id ?? 0,
      name: nameField.text.trim(),
      expectedIncome: Validators.normalizeAmount(
        Validators.parseAmount(incomeField.text) ?? 0,
      ),
      startDate: startDate.value,
      endDate: endDate.value,
      status: status.value,
      note: note.isEmpty ? null : note,
      createdAt: _editing?.createdAt ?? now,
      updatedAt: now,
    );

    final source = template.value;
    final result = isEditing
        ? await _repository.update(draft)
        : (copyPrevious.value && source != null)
        ? await _repository.createFromTemplate(
            plan: draft,
            sourcePlanId: source.id,
          )
        : await _repository.create(draft);
    isSubmitting.value = false;

    return result.fold(
      onSuccess: (saved) {
        _events.emit(DataChange.plans);
        AppSnackbar.success(isEditing ? 'Plan updated' : 'Plan created');
        return saved;
      },
      onError: (failure) {
        if (failure case ValidationFailure(fieldErrors: final errors)
            when errors.isNotEmpty) {
          fieldErrors.assignAll(errors);
        }
        AppSnackbar.error(failure.message);
        return null;
      },
    );
  }
}
