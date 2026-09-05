import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/budget_period.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/budget_form_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class BudgetFormPage extends GetView<BudgetFormController> {
  const BudgetFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit budget' : 'New budget'),
      ),
      body: Obx(
        () => controller.isLoading.value
            ? const AppLoader()
            : const _BudgetFormBody(),
      ),
    );
  }
}

/// The form itself.
///
/// Split out so the loading gate's `Obx` swaps a `const` widget instead of
/// rebuilding the whole form: a reactive scope wrapped around an entire screen
/// re-runs everything under it, and each field already has its own `Obx`.
class _BudgetFormBody extends GetView<BudgetFormController> {
  const _BudgetFormBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Obx(
                () => AmountField(
                  controller: controller.amountField,
                  label: 'Budget limit',
                  autofocus: !controller.isEditing,
                  errorText: controller.fieldErrors['amount'],
                ),
              ),
              AppSpacing.gapLg,
              Obx(
                () => SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: controller.isOverall.value,
                  onChanged: controller.toggleOverall,
                  title: const Text('Budget all expenses'),
                  subtitle: Text(
                    'Track every expense category against one limit',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Obx(() {
                if (controller.isOverall.value) {
                  return const SizedBox.shrink();
                }
                final category = controller.category.value;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
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
                        controller.categories,
                        selected: category,
                      );
                      if (picked != null) controller.selectCategory(picked);
                    },
                  ),
                );
              }),
              AppSpacing.gapBase,
              Obx(
                () => AppPickerField(
                  label: 'Period',
                  value: controller.period.value.label,
                  onTap: () async {
                    final picked = await PickerSheets.options<BudgetPeriod>(
                      title: 'Budget period',
                      values: BudgetPeriod.values,
                      labelOf: (period) => period.label,
                      selected: controller.period.value,
                    );
                    if (picked != null) controller.changePeriod(picked);
                  },
                ),
              ),
              AppSpacing.gapBase,
              Obx(
                () => AppPickerField(
                  label: 'Date range',
                  value:
                      '${AppDate.formatDate(controller.startDate.value)}'
                      ' – ${AppDate.formatDate(controller.endDate.value)}',
                  trailingIcon: Icons.date_range_rounded,
                  onTap: () => _pickRange(context),
                ),
              ),
              AppSpacing.gapBase,
              Obx(
                () => AppTextField(
                  controller: controller.alertField,
                  label: 'Alert at (%)',
                  hint: 'Warn when spending reaches this share',
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  errorText: controller.fieldErrors['alertPercentage'],
                ),
              ),
              AppSpacing.gapSm,
              Obx(
                () => SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: controller.isActive.value,
                  onChanged: controller.toggleActive,
                  title: const Text('Active'),
                  subtitle: Text(
                    'Inactive budgets stop appearing in alerts',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
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
                      final navigator = Navigator.of(context);
                      if (await controller.submit()) navigator.pop(true);
                    },
              child: controller.isSubmitting.value
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : Text(
                      controller.isEditing ? 'Save changes' : 'Create budget',
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: DateTimeRange(
        start: controller.startDate.value,
        end: controller.endDate.value,
      ),
    );
    if (picked != null) controller.selectRange(picked.start, picked.end);
  }
}
