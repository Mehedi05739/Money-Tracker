import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/money_transaction.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/transaction_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';

/// What the form should open with.
///
/// The page reads this from route arguments; the quick-add sheet passes it
/// directly, because a sheet has no route of its own to carry arguments.
class TransactionFormArgs {
  const TransactionFormArgs({
    this.type = TransactionType.expense,
    this.editing,
  });

  factory TransactionFormArgs.fromRouteArguments(Object? arguments) =>
      switch (arguments) {
        MoneyTransaction transaction => TransactionFormArgs(
          type: transaction.type,
          editing: transaction,
        ),
        TransactionType type => TransactionFormArgs(type: type),
        _ => const TransactionFormArgs(),
      };

  final TransactionType type;
  final MoneyTransaction? editing;
}

/// Drives the add/edit transaction form.
///
/// Optimised for speed of entry: the amount field is focused on open, the
/// account is pre-filled from settings, and everything except amount and
/// category has a sensible default — so a expense is four taps.
class TransactionFormController extends GetxController {
  TransactionFormController(
    this._transactions,
    this._accounts,
    this._categories,
    this._settings,
    this._events, {
    this.seed,
  });

  final TransactionRepository _transactions;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final SettingsController _settings;
  final AppEvents _events;

  /// Supplied by the sheet; `null` means "read the route arguments".
  final TransactionFormArgs? seed;

  final TextEditingController amountField = TextEditingController();
  final TextEditingController titleField = TextEditingController();
  final TextEditingController noteField = TextEditingController();

  final Rx<TransactionType> type = TransactionType.expense.obs;
  final Rxn<Account> account = Rxn<Account>();
  final Rxn<Account> toAccount = Rxn<Account>();
  final Rxn<Category> category = Rxn<Category>();
  final Rx<DateTime> date = DateTime.now().obs;
  final Rxn<PaymentMethod> paymentMethod = Rxn<PaymentMethod>();

  final RxList<Account> accounts = <Account>[].obs;
  final RxList<Category> categories = <Category>[].obs;

  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  MoneyTransaction? _editing;

  bool get isEditing => _editing != null;
  String get submitLabel =>
      isEditing ? 'Save changes' : 'Add ${type.value.label.toLowerCase()}';

  /// Categories matching the selected type. Transfers use none.
  List<Category> get availableCategories =>
      categories.where((c) => c.type == type.value).toList();

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  @override
  void onClose() {
    amountField.dispose();
    titleField.dispose();
    noteField.dispose();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    isLoading.value = true;

    final accountFuture = _accounts.getAccounts();
    final categoryFuture = _categories.getCategories();

    accounts.assignAll((await accountFuture).dataOrNull ?? const []);
    categories.assignAll((await categoryFuture).dataOrNull ?? const []);

    final args = seed ?? TransactionFormArgs.fromRouteArguments(Get.arguments);
    final editing = args.editing;

    if (editing != null) {
      _loadForEdit(editing);
    } else {
      type.value = args.type;
      _applyDefaults();
    }

    isLoading.value = false;
  }

  void _applyDefaults() {
    final preferredId = _settings.defaultAccountId.value;
    account.value =
        accounts.firstWhereOrNull((a) => a.id == preferredId) ??
        accounts.firstOrNull;
  }

  void _loadForEdit(MoneyTransaction transaction) {
    _editing = transaction;
    type.value = transaction.type;
    amountField.text = transaction.amount.toStringAsFixed(2);
    titleField.text = transaction.title;
    noteField.text = transaction.note ?? '';
    date.value = transaction.transactionDate;
    paymentMethod.value = transaction.paymentMethod;

    account.value = accounts.firstWhereOrNull(
      (a) => a.id == transaction.accountId,
    );
    toAccount.value = accounts.firstWhereOrNull(
      (a) => a.id == transaction.toAccountId,
    );
    category.value = categories.firstWhereOrNull(
      (c) => c.id == transaction.categoryId,
    );
  }

  void changeType(TransactionType value) {
    if (value == type.value) return;
    type.value = value;
    fieldErrors.clear();

    // The previous category belongs to the previous type's list.
    if (category.value?.type != value) category.value = null;
    if (!value.isTransfer) toAccount.value = null;
  }

  void selectAccount(Account value) {
    account.value = value;
    // Source and destination must differ.
    if (toAccount.value?.id == value.id) toAccount.value = null;
    fieldErrors.remove('account');
  }

  void selectToAccount(Account value) {
    toAccount.value = value;
    fieldErrors.remove('toAccount');
  }

  void selectCategory(Category value) {
    category.value = value;
    // Category doubles as the title when the user has not typed one, which is
    // what makes single-field entry possible.
    if (titleField.text.trim().isEmpty) titleField.text = value.name;
    fieldErrors.remove('category');
  }

  void selectDate(DateTime value) {
    // Keep the time of day so same-day entries stay in insertion order.
    final now = DateTime.now();
    date.value = DateTime(
      value.year,
      value.month,
      value.day,
      now.hour,
      now.minute,
    );
  }

  void selectPaymentMethod(PaymentMethod? value) => paymentMethod.value = value;

  // ---- Keypad editing -----------------------------------------------------
  // The quick-add sheet drives the amount itself instead of using the system
  // keyboard, so these enforce the same shape `AmountInputFormatter` does.

  /// Longest whole-number part accepted, matching [Validators.maxAmount].
  static const int maxWholeDigits = 9;

  void appendDigit(String digit) {
    final current = amountField.text;

    if (current.contains('.')) {
      final decimals = current.split('.').last;
      if (decimals.length >= 2) return;
    } else if (current.length >= maxWholeDigits) {
      return;
    }

    // A leading zero is a placeholder, not a digit the user meant to keep.
    final next = current == '0' ? digit : '$current$digit';
    _setAmount(next);
  }

  void appendDecimalPoint() {
    final current = amountField.text;
    if (current.contains('.')) return;
    _setAmount(current.isEmpty ? '0.' : '$current.');
  }

  void backspace() {
    final current = amountField.text;
    if (current.isEmpty) return;
    _setAmount(current.substring(0, current.length - 1));
  }

  void clearAmount() => _setAmount('');

  void _setAmount(String value) {
    amountField.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    if (fieldErrors.containsKey('amount')) fieldErrors.remove('amount');
  }

  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    fieldErrors.clear();
    final localErrors = _validateLocally();
    if (localErrors.isNotEmpty) {
      fieldErrors.assignAll(localErrors);
      return false;
    }

    isSubmitting.value = true;
    final draft = _buildTransaction();
    final result = isEditing
        ? await _transactions.update(draft)
        : await _transactions.create(draft);
    isSubmitting.value = false;

    return result.fold(
      onSuccess: (saved) {
        // Every open screen that shows money is now out of date.
        _events.emit(DataChange.transactions);
        AppSnackbar.success(
          isEditing ? 'Transaction updated' : '${saved.type.label} saved',
        );
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

  /// Client-side checks so the user sees errors without a database round trip.
  /// The repository re-validates regardless — this is convenience, not trust.
  Map<String, String> _validateLocally() {
    final errors = <String, String>{};

    final amountError = Validators.amount(amountField.text);
    if (amountError != null) errors['amount'] = amountError;

    if (account.value == null) errors['account'] = 'Choose an account';

    if (type.value.isTransfer) {
      if (toAccount.value == null) {
        errors['toAccount'] = 'Choose a destination account';
      } else if (toAccount.value!.id == account.value?.id) {
        errors['toAccount'] = 'Pick a different account';
      }
    } else if (category.value == null) {
      errors['category'] = 'Choose a category';
    }

    return errors;
  }

  MoneyTransaction _buildTransaction() {
    final now = DateTime.now();
    final amount = Validators.normalizeAmount(
      Validators.parseAmount(amountField.text) ?? 0,
    );
    final title = titleField.text.trim();
    final note = noteField.text.trim();

    return MoneyTransaction(
      id: _editing?.id ?? 0,
      accountId: account.value?.id ?? 0,
      toAccountId: type.value.isTransfer ? toAccount.value?.id : null,
      type: type.value,
      amount: amount,
      categoryId: type.value.isTransfer ? null : category.value?.id,
      title: title.isEmpty ? _fallbackTitle : title,
      transactionDate: date.value,
      paymentMethod: paymentMethod.value,
      note: note.isEmpty ? null : note,
      recurringId: _editing?.recurringId,
      createdAt: _editing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  String get _fallbackTitle => type.value.isTransfer
      ? 'Transfer'
      : (category.value?.name ?? 'Transaction');
}
