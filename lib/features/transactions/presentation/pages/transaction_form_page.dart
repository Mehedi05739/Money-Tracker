import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../domain/entities/money_transaction.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/transaction_form_controller.dart';
import '../widgets/picker_sheets.dart';
import '../../../../core/theme/app_spacing.dart';

/// Add / edit transaction.
///
/// Field order follows the fastest path: amount → category → account → date.
class TransactionFormPage extends GetView<TransactionFormController> {
  const TransactionFormPage({super.key});

  /// Opens a blank form for [type]. Returns true when something was saved.
  static Future<bool> open(TransactionType type) async {
    final saved = await Get.toNamed(AppRoutes.transactionForm, arguments: type);
    return saved == true;
  }

  static Future<bool> edit(MoneyTransaction transaction) async {
    final saved = await Get.toNamed(
      AppRoutes.transactionForm,
      arguments: transaction,
    );
    return saved == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.isEditing
                ? 'Edit transaction'
                : 'New ${controller.type.value.label.toLowerCase()}',
          ),
        ),
      ),
      body: Obx(
        () =>
            controller.isLoading.value ? const AppLoader() : const _FormBody(),
      ),
    );
  }
}

/// The form itself.
///
/// A `GetView` with a const constructor, so the loading gate's `Obx` swaps a
/// canonical widget instead of rebuilding every field — each field already
/// owns its own reactive scope.
class _FormBody extends GetView<TransactionFormController> {
  const _FormBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Obx(
                () => AppSegmented<TransactionType>(
                  values: TransactionType.values,
                  selected: controller.type.value,
                  labelOf: (type) => type.label,
                  iconOf: (type) => switch (type) {
                    TransactionType.income => Icons.south_west_rounded,
                    TransactionType.expense => Icons.north_east_rounded,
                    TransactionType.transfer => Icons.swap_horiz_rounded,
                  },
                  colorOf: (type) => switch (type) {
                    TransactionType.income => context.incomeColor,
                    TransactionType.expense => context.expenseColor,
                    TransactionType.transfer => context.transferColor,
                  },
                  onChanged: controller.changeType,
                ),
              ),
              AppSpacing.gapLg,
              Obx(
                () => AmountField(
                  controller: controller.amountField,
                  autofocus: !controller.isEditing,
                  errorText: controller.fieldErrors['amount'],
                ),
              ),
              AppSpacing.gapBase,
              Obx(() {
                if (controller.type.value.isTransfer) {
                  return const SizedBox.shrink();
                }
                final category = controller.category.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AppPickerField(
                    label: 'Category',
                    value: category?.name,
                    errorText: controller.fieldErrors['category'],
                    leading: category == null
                        ? null
                        : CategoryAvatar(
                            icon: category.icon,
                            color: category.color,
                            seed: category.id,
                            size: 26,
                          ),
                    onTap: () async {
                      final picked = await PickerSheets.category(
                        controller.availableCategories,
                        selected: category,
                      );
                      if (picked != null) controller.selectCategory(picked);
                    },
                  ),
                );
              }),
              Obx(
                () => AppPickerField(
                  label: controller.type.value.isTransfer
                      ? 'From account'
                      : 'Account',
                  value: controller.account.value?.name,
                  errorText: controller.fieldErrors['account'],
                  onTap: () async {
                    final picked = await PickerSheets.account(
                      controller.accounts,
                      selected: controller.account.value,
                    );
                    if (picked != null) controller.selectAccount(picked);
                  },
                ),
              ),
              Obx(() {
                if (!controller.type.value.isTransfer) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppPickerField(
                    label: 'To account',
                    value: controller.toAccount.value?.name,
                    errorText: controller.fieldErrors['toAccount'],
                    onTap: () async {
                      final picked = await PickerSheets.account(
                        controller.accounts,
                        selected: controller.toAccount.value,
                        excludeId: controller.account.value?.id,
                        title: 'Transfer to',
                      );
                      if (picked != null) controller.selectToAccount(picked);
                    },
                  ),
                );
              }),
              AppSpacing.gapBase,
              Obx(
                () => AppPickerField(
                  label: 'Date',
                  value: AppDate.formatRelativeDay(controller.date.value),
                  trailingIcon: Icons.calendar_today_rounded,
                  onTap: () => _pickDate(context),
                ),
              ),
              AppSpacing.gapBase,
              AppTextField(
                controller: controller.titleField,
                label: 'Title',
                hint: 'Optional — defaults to the category',
                maxLength: 60,
              ),
              AppSpacing.gapBase,
              Obx(
                () => AppPickerField(
                  label: 'Payment method',
                  value: controller.paymentMethod.value?.label,
                  placeholder: 'Optional',
                  onTap: () async {
                    final picked = await PickerSheets.paymentMethod(
                      selected: controller.paymentMethod.value,
                    );
                    controller.selectPaymentMethod(picked);
                  },
                ),
              ),
              AppSpacing.gapBase,
              AppTextField(
                controller: controller.noteField,
                label: 'Note',
                hint: 'Optional',
                maxLines: 3,
                maxLength: 240,
              ),
            ],
          ),
        ),
        _SubmitBar(controller: controller),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.date.value,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    if (picked != null) controller.selectDate(picked);
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.controller});

  final TransactionFormController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Obx(
        () => FilledButton(
          onPressed: controller.isSubmitting.value
              ? null
              : () async {
                  // Captured before the await: after it, `context` may be gone.
                  final navigator = Navigator.of(context);
                  if (await controller.submit()) navigator.pop(true);
                },
          child: controller.isSubmitting.value
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : Text(controller.submitLabel),
        ),
      ),
    );
  }
}
