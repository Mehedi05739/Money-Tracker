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
  final TextEditingController limitField = TextEditingController();
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

    final argument = Get.arguments;
    if (argument is SpendingPlan) {
      _editing = argument;
      nameField.text = argument.name;
      limitField.text = argument.totalLimit.toStringAsFixed(2);
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

  @override
  void onClose() {
    nameField.dispose();
    limitField.dispose();
    noteField.dispose();
    super.onClose();
  }

  void selectRange(DateTime start, DateTime end) {
    startDate.value = AppDate.startOfDay(start);
    endDate.value = AppDate.endOfDay(end);
  }

  void changeStatus(PlanStatus value) => status.value = value;

  Future<SpendingPlan?> submit() async {
    if (isSubmitting.value) return null;

    fieldErrors.clear();
    final nameError = Validators.name(nameField.text, field: 'Plan name');
    final limitError =
        Validators.amount(limitField.text, field: 'Spending limit');

    if (nameError != null) fieldErrors['name'] = nameError;
    if (limitError != null) fieldErrors['totalLimit'] = limitError;
    if (fieldErrors.isNotEmpty) return null;

    isSubmitting.value = true;
    final now = DateTime.now();
    final note = noteField.text.trim();

    final draft = SpendingPlan(
      id: _editing?.id ?? 0,
      name: nameField.text.trim(),
      totalLimit: Validators.normalizeAmount(
        Validators.parseAmount(limitField.text) ?? 0,
      ),
      startDate: startDate.value,
      endDate: endDate.value,
      status: status.value,
      note: note.isEmpty ? null : note,
      createdAt: _editing?.createdAt ?? now,
      updatedAt: now,
    );

    final result =
        isEditing ? await _repository.update(draft) : await _repository.create(draft);
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
