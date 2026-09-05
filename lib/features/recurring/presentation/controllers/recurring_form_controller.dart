import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../core/enums/payment_method.dart';
import '../../../../core/enums/recurrence_frequency.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/entities/recurring_transaction.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/recurring_repository.dart';

class RecurringFormController extends GetxController {
  RecurringFormController(
    this._repository,
    this._accounts,
    this._categories,
    this._events,
  );

  final RecurringRepository _repository;
  final AccountRepository _accounts;
  final CategoryRepository _categories;
  final AppEvents _events;

  final TextEditingController titleField = TextEditingController();
  final TextEditingController amountField = TextEditingController();
  final TextEditingController noteField = TextEditingController();
  final TextEditingController intervalField = TextEditingController(text: '1');

  final Rx<TransactionType> type = TransactionType.expense.obs;
  final Rx<RecurrenceFrequency> frequency = RecurrenceFrequency.monthly.obs;
  final Rxn<Account> account = Rxn<Account>();
  final Rxn<Category> category = Rxn<Category>();
  final Rxn<PaymentMethod> paymentMethod = Rxn<PaymentMethod>();
  final Rx<DateTime> startDate = AppDate.startOfDay(DateTime.now()).obs;
  final Rxn<DateTime> endDate = Rxn<DateTime>();
  final RxBool isActive = true.obs;
  final RxBool autoPost = true.obs;

  final RxList<Account> accounts = <Account>[].obs;
  final RxList<Category> categories = <Category>[].obs;

  final RxBool isLoading = true.obs;
  final RxBool isSubmitting = false.obs;
  final RxMap<String, String> fieldErrors = <String, String>{}.obs;

  RecurringTransaction? _editing;

  bool get isEditing => _editing != null;

  List<Category> get availableCategories =>
      categories.where((c) => c.type == type.value).toList();

  /// Transfers are excluded — a schedule that moves money between two of the
  /// user's own accounts has no effect on income or spending.
  static const List<TransactionType> allowedTypes = [
    TransactionType.expense,
    TransactionType.income,
  ];

  @override
  void onInit() {
    super.onInit();
    _bootstrap();
  }

  @override
  void onClose() {
    titleField.dispose();
    amountField.dispose();
    noteField.dispose();
    intervalField.dispose();
    super.onClose();
  }

  Future<void> _bootstrap() async {
    final accountFuture = _accounts.getAccounts();
    final categoryFuture = _categories.getCategories();

    accounts.assignAll((await accountFuture).dataOrNull ?? const []);
    categories.assignAll((await categoryFuture).dataOrNull ?? const []);

    final argument = Get.arguments;
    if (argument is RecurringTransaction) {
      _loadForEdit(argument);
    } else {
      account.value = accounts.firstOrNull;
    }

    isLoading.value = false;
  }

  void _loadForEdit(RecurringTransaction rule) {
    _editing = rule;
    titleField.text = rule.title;
    amountField.text = rule.amount.toStringAsFixed(2);
    noteField.text = rule.note ?? '';
    intervalField.text = '${rule.intervalCount}';
    type.value = rule.type;
    frequency.value = rule.frequency;
    startDate.value = rule.startDate;
    endDate.value = rule.endDate;
    isActive.value = rule.isActive;
    autoPost.value = rule.autoPost;
    paymentMethod.value = rule.paymentMethod;
    account.value = accounts.firstWhereOrNull((a) => a.id == rule.accountId);
    category.value = categories.firstWhereOrNull(
      (c) => c.id == rule.categoryId,
    );
  }

  void changeType(TransactionType value) {
    type.value = value;
    if (category.value?.type != value) category.value = null;
  }

  void changeFrequency(RecurrenceFrequency value) => frequency.value = value;
  void selectAccount(Account value) => account.value = value;
  void selectCategory(Category value) {
    category.value = value;
    if (titleField.text.trim().isEmpty) titleField.text = value.name;
    fieldErrors.remove('category');
  }

  void selectPaymentMethod(PaymentMethod? value) => paymentMethod.value = value;
  void selectStartDate(DateTime value) =>
      startDate.value = AppDate.startOfDay(value);
  void selectEndDate(DateTime? value) =>
      endDate.value = value == null ? null : AppDate.endOfDay(value);
  void toggleActive(bool value) => isActive.value = value;
  void toggleAutoPost(bool value) => autoPost.value = value;

  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    fieldErrors.clear();
    final amountError = Validators.amount(amountField.text);
    if (amountError != null) fieldErrors['amount'] = amountError;
    if (account.value == null) fieldErrors['account'] = 'Choose an account';
    if (category.value == null) fieldErrors['category'] = 'Choose a category';

    final interval = int.tryParse(intervalField.text.trim()) ?? 0;
    if (interval < 1) fieldErrors['interval'] = 'Must be at least 1';

    final end = endDate.value;
    if (end != null && end.isBefore(startDate.value)) {
      fieldErrors['endDate'] = 'End date must be after the start date';
    }
    if (fieldErrors.isNotEmpty) return false;

    isSubmitting.value = true;
    final now = DateTime.now();
    final note = noteField.text.trim();
    final title = titleField.text.trim();

    final draft = RecurringTransaction(
      id: _editing?.id ?? 0,
      accountId: account.value!.id,
      categoryId: category.value?.id,
      type: type.value,
      amount: Validators.normalizeAmount(
        Validators.parseAmount(amountField.text) ?? 0,
      ),
      title: title.isEmpty ? (category.value?.name ?? 'Recurring') : title,
      note: note.isEmpty ? null : note,
      paymentMethod: paymentMethod.value,
      frequency: frequency.value,
      intervalCount: interval,
      startDate: startDate.value,
      endDate: endDate.value,
      // Editing keeps the schedule cursor so past occurrences are not reposted.
      nextRunDate: _editing?.nextRunDate ?? startDate.value,
      lastRunDate: _editing?.lastRunDate,
      isActive: isActive.value,
      autoPost: autoPost.value,
      createdAt: _editing?.createdAt ?? now,
      updatedAt: now,
    );

    final result = isEditing
        ? await _repository.update(draft)
        : await _repository.create(draft);
    isSubmitting.value = false;

    return result.fold(
      onSuccess: (_) {
        _events.emit(DataChange.recurring);
        AppSnackbar.success(
          isEditing ? 'Schedule updated' : 'Schedule created',
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
}
