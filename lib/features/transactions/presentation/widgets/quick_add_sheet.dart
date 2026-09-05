import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/amount_keypad.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/repositories/transaction_repository.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../controllers/transaction_form_controller.dart';
import 'category_grid.dart';
import 'picker_sheets.dart';

/// The fastest path to recording money.
///
/// A sheet rather than a route: pushing a full screen for the app's most
/// frequent action costs a transition each way and buries the amount field
/// below an app bar. Here the keypad is up on open and the whole entry —
/// amount, category, account, date — is one surface.
class QuickAddSheet extends StatelessWidget {
  const QuickAddSheet({super.key, required this.controller});

  final TransactionFormController controller;

  /// Registered under a tag so a sheet opened while the full edit page is
  /// alive cannot clobber that page's controller.
  static const String _tag = 'quick-add';

  static Future<bool> show({
    TransactionType type = TransactionType.expense,
  }) async {
    final context = Get.context;
    if (context == null) return false;

    final controller = Get.put(
      TransactionFormController(
        Get.find<TransactionRepository>(),
        Get.find<AccountRepository>(),
        Get.find<CategoryRepository>(),
        Get.find<SettingsController>(),
        Get.find<AppEvents>(),
        seed: TransactionFormArgs(type: type),
      ),
      tag: _tag,
    );

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuickAddSheet(controller: controller),
    );

    await Get.delete<TransactionFormController>(tag: _tag);
    return saved ?? false;
  }

  @override
  Widget build(BuildContext context) {
    // No system keyboard is involved, so the sheet keeps a stable height
    // instead of resizing around an IME.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Obx(
          () => controller.isLoading.value
              ? const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
            : _Body(controller: controller),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final TransactionFormController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          // Top gap clears the drag handle and the amount field's floating
          // label, which draws above its border.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.base,
            AppSpacing.base,
          ),
          child: Obx(
            () => AppSegmented<TransactionType>(
              values: const [
                TransactionType.expense,
                TransactionType.income,
                TransactionType.transfer,
              ],
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
        ),
        Padding(
          padding: AppSpacing.screenH,
          child: Obx(
            () => AmountDisplay(
              controller: controller.amountField,
              errorText: controller.fieldErrors['amount'],
            ),
          ),
        ),
        Obx(
          () => controller.type.value.isTransfer
              ? const SizedBox.shrink()
              : Flexible(child: _CategorySection(controller: controller)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.md,
            AppSpacing.base,
            AppSpacing.md,
          ),
          child: _ChipRow(controller: controller),
        ),
        Padding(
          padding: AppSpacing.screenH,
          child: AmountKeypad(
            onDigit: controller.appendDigit,
            onDecimal: controller.appendDecimalPoint,
            onBackspace: controller.backspace,
            onClear: controller.clearAmount,
          ),
        ),
        _SaveBar(controller: controller),
      ],
    );
  }
}

/// Account and date as chips: both have a sensible default, so they are
/// adjustments rather than steps.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.controller});

  final TransactionFormController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          _InlineChip(
            icon: Icons.account_balance_wallet_outlined,
            label: controller.account.value?.name ?? 'Account',
            isError: controller.fieldErrors.containsKey('account'),
            onTap: () async {
              final picked = await PickerSheets.account(
                controller.accounts,
                selected: controller.account.value,
              );
              if (picked != null) controller.selectAccount(picked);
            },
          ),
          if (controller.type.value.isTransfer)
            _InlineChip(
              icon: Icons.arrow_forward_rounded,
              label: controller.toAccount.value?.name ?? 'To account',
              isError: controller.fieldErrors.containsKey('toAccount'),
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
          _InlineChip(
            icon: Icons.calendar_today_rounded,
            label: AppDate.formatRelativeDay(controller.date.value),
            onTap: () => _pickDate(context),
          ),
        ],
      ),
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

class _InlineChip extends StatelessWidget {
  const _InlineChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isError = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isError ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;

    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: theme.textTheme.bodyMedium),
      side: BorderSide(
        color: isError ? theme.colorScheme.error : theme.dividerColor,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.controller});

  final TransactionFormController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.base,
            AppSpacing.md,
          ),
          child: Obx(() {
            final error = controller.fieldErrors['category'];
            return Row(
              children: [
                Text('Category', style: theme.textTheme.titleMedium),
                if (error != null) ...[
                  AppSpacing.hGapSm,
                  Expanded(
                    child: Text(
                      error,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ],
            );
          }),
        ),
        Flexible(
          child: Obx(
            () => CategoryGrid(
              categories: controller.availableCategories,
              selectedId: controller.category.value?.id,
              onSelected: controller.selectCategory,
              shrinkWrap: false,
              padding: AppSpacing.screenH,
            ),
          ),
        ),
      ],
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({required this.controller});

  final TransactionFormController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.base,
        AppSpacing.md,
        AppSpacing.base,
        AppSpacing.md + MediaQuery.viewPaddingOf(context).bottom,
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
