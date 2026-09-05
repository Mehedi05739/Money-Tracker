import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/repositories/category_repository.dart';

class CategoryFormController extends GetxController {
  CategoryFormController(this._repository, this._events);

  final CategoryRepository _repository;
  final AppEvents _events;

  final TextEditingController nameField = TextEditingController();
  final Rx<TransactionType> type = TransactionType.expense.obs;
  final RxnString icon = RxnString();
  final RxnInt color = RxnInt();
  final RxBool isSubmitting = false.obs;
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  Category? _editing;

  bool get isEditing => _editing != null;

  /// A default category's type cannot change: existing transactions are
  /// already filed under it.
  bool get canChangeType => !isEditing;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is Category) {
      _editing = argument;
      nameField.text = argument.name;
      type.value = argument.type;
      icon.value = argument.icon;
      color.value = argument.color;
    } else if (argument is TransactionType) {
      type.value = argument;
    }
  }

  @override
  void onClose() {
    nameField.dispose();
    super.onClose();
  }

  void changeType(TransactionType value) => type.value = value;
  void changeIcon(String? value) => icon.value = value;
  void changeColor(int? value) => color.value = value;

  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    fieldErrors.clear();
    final nameError = Validators.name(nameField.text, field: 'Category name');
    if (nameError != null) {
      fieldErrors['name'] = nameError;
      return false;
    }

    isSubmitting.value = true;
    final draft = Category(
      id: _editing?.id ?? 0,
      name: nameField.text.trim(),
      type: type.value,
      icon: icon.value,
      color: color.value,
      isDefault: _editing?.isDefault ?? false,
      isArchived: _editing?.isArchived ?? false,
      createdAt: _editing?.createdAt ?? DateTime.now(),
    );

    final result =
        isEditing ? await _repository.update(draft) : await _repository.create(draft);
    isSubmitting.value = false;

    return result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.categories);
        AppSnackbar.success(isEditing ? 'Category updated' : 'Category added');
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
