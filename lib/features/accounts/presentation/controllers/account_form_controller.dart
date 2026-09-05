import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../core/enums/account_type.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';

class AccountFormController extends GetxController {
  AccountFormController(this._repository, this._settings, this._events);

  final AccountRepository _repository;
  final SettingsController _settings;
  final AppEvents _events;

  final TextEditingController nameField = TextEditingController();
  final TextEditingController openingBalanceField = TextEditingController();

  final Rx<AccountType> type = AccountType.cash.obs;
  final RxnString icon = RxnString('wallet');
  final RxnInt color = RxnInt();
  final RxBool isSubmitting = false.obs;
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  Account? _editing;

  bool get isEditing => _editing != null;

  /// The opening balance is locked once transactions exist against it: changing
  /// it would silently rewrite every historical balance.
  bool get canEditOpeningBalance => !isEditing;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is Account) _loadForEdit(argument);
  }

  @override
  void onClose() {
    nameField.dispose();
    openingBalanceField.dispose();
    super.onClose();
  }

  void _loadForEdit(Account account) {
    _editing = account;
    nameField.text = account.name;
    openingBalanceField.text = account.openingBalance.toStringAsFixed(2);
    type.value = account.type;
    icon.value = account.icon;
    color.value = account.color;
  }

  void changeType(AccountType value) => type.value = value;
  void changeIcon(String? value) => icon.value = value;
  void changeColor(int? value) => color.value = value;

  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    fieldErrors.clear();
    final nameError = Validators.name(nameField.text, field: 'Account name');
    final balanceError =
        Validators.nonNegativeAmount(openingBalanceField.text.isEmpty
            ? '0'
            : openingBalanceField.text, field: 'Opening balance');

    if (nameError != null) fieldErrors['name'] = nameError;
    if (balanceError != null) fieldErrors['openingBalance'] = balanceError;
    if (fieldErrors.isNotEmpty) return false;

    isSubmitting.value = true;
    final draft = _build();
    final result =
        isEditing ? await _repository.update(draft) : await _repository.create(draft);
    isSubmitting.value = false;

    return result.fold(
      onSuccess: (saved) {
        _events.emit(DataChange.accounts);
        AppSnackbar.success(isEditing ? 'Account updated' : 'Account added');
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

  Account _build() {
    final now = DateTime.now();
    final opening = Validators.normalizeAmount(
      Validators.parseAmount(openingBalanceField.text) ?? 0,
    );

    return Account(
      id: _editing?.id ?? 0,
      name: nameField.text.trim(),
      type: type.value,
      openingBalance: opening,
      currentBalance: _editing?.currentBalance ?? opening,
      currency: _settings.currency.value.code,
      icon: icon.value,
      color: color.value,
      isArchived: _editing?.isArchived ?? false,
      sortOrder: _editing?.sortOrder ?? 0,
      createdAt: _editing?.createdAt ?? now,
      updatedAt: now,
    );
  }
}
