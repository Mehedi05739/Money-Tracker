import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../core/enums/goal_status.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/financial_goal.dart';
import '../../../../domain/repositories/goal_repository.dart';

class GoalFormController extends GetxController {
  GoalFormController(this._repository, this._events);

  final GoalRepository _repository;
  final AppEvents _events;

  final TextEditingController nameField = TextEditingController();
  final TextEditingController targetField = TextEditingController();
  final TextEditingController noteField = TextEditingController();

  final Rxn<DateTime> targetDate = Rxn<DateTime>();
  final RxnString icon = RxnString('savings');
  final RxnInt color = RxnInt();
  final Rx<GoalStatus> status = GoalStatus.active.obs;

  final RxBool isSubmitting = false.obs;
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  FinancialGoal? _editing;

  bool get isEditing => _editing != null;

  /// Starter goals offered on an empty form, so the first goal is one tap.
  static const List<({String name, String icon})> suggestions = [
    (name: 'Emergency Fund', icon: 'savings'),
    (name: 'New Phone', icon: 'phone'),
    (name: 'Laptop', icon: 'laptop'),
    (name: 'Vacation', icon: 'beach'),
    (name: 'Car', icon: 'car'),
    (name: 'Education', icon: 'school'),
  ];

  @override
  void onInit() {
    super.onInit();

    final argument = Get.arguments;
    if (argument is FinancialGoal) {
      _editing = argument;
      nameField.text = argument.name;
      targetField.text = argument.targetAmount.toStringAsFixed(2);
      noteField.text = argument.note ?? '';
      targetDate.value = argument.targetDate;
      icon.value = argument.icon;
      color.value = argument.color;
      status.value = argument.status;
    } else {
      targetDate.value = DateTime.now().add(const Duration(days: 180));
    }
  }

  @override
  void onClose() {
    nameField.dispose();
    targetField.dispose();
    noteField.dispose();
    super.onClose();
  }

  void applySuggestion(({String name, String icon}) suggestion) {
    nameField.text = suggestion.name;
    icon.value = suggestion.icon;
  }

  void selectTargetDate(DateTime? value) => targetDate.value = value;
  void changeIcon(String? value) => icon.value = value;
  void changeColor(int? value) => color.value = value;
  void changeStatus(GoalStatus value) => status.value = value;

  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    fieldErrors.clear();
    final nameError = Validators.name(nameField.text, field: 'Goal name');
    final targetError = Validators.amount(
      targetField.text,
      field: 'Target amount',
    );

    if (nameError != null) fieldErrors['name'] = nameError;
    if (targetError != null) fieldErrors['targetAmount'] = targetError;
    if (fieldErrors.isNotEmpty) return false;

    isSubmitting.value = true;
    final now = DateTime.now();
    final note = noteField.text.trim();

    final draft = FinancialGoal(
      id: _editing?.id ?? 0,
      name: nameField.text.trim(),
      targetAmount: Validators.normalizeAmount(
        Validators.parseAmount(targetField.text) ?? 0,
      ),
      currentAmount: _editing?.currentAmount ?? 0,
      targetDate: targetDate.value,
      icon: icon.value,
      color: color.value,
      status: status.value,
      note: note.isEmpty ? null : note,
      createdAt: _editing?.createdAt ?? now,
      updatedAt: now,
    );

    final result = isEditing
        ? await _repository.update(draft)
        : await _repository.create(draft);
    isSubmitting.value = false;

    return result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.goals);
        AppSnackbar.success(isEditing ? 'Goal updated' : 'Goal created');
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
