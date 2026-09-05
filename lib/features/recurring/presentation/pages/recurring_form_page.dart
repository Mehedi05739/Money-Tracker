import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/recurrence_frequency.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/recurring_form_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class RecurringFormPage extends GetView<RecurringFormController> {
  const RecurringFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit schedule' : 'New schedule'),
      ),
      body: Obx(() {
        if (controller.isLoading.value) return const AppLoader();

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Obx(
                    () => AppSegmented<TransactionType>(
                      values: RecurringFormController.allowedTypes,
                      selected: controller.type.value,
                      labelOf: (type) => type.label,
                      iconOf: (type) => type.isIncome
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      colorOf: (type) => type.isIncome
                          ? context.incomeColor
                          : context.expenseColor,
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
                    final category = controller.category.value;
                    return AppPickerField(
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
                    );
                  }),
                  AppSpacing.gapBase,
                  Obx(
                    () => AppPickerField(
                      label: 'Account',
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
                  AppSpacing.gapBase,
                  AppTextField(
                    controller: controller.titleField,
                    label: 'Title',
                    hint: 'Rent, Salary, Netflix…',
                    maxLength: 60,
                  ),
                  AppSpacing.gapXl,
                  Text('Schedule', style: theme.textTheme.titleMedium),
                  AppSpacing.gapMd,
                  Obx(
                    () => AppPickerField(
                      label: 'Repeats',
                      value: controller.frequency.value.label,
                      onTap: () async {
                        final picked =
                            await PickerSheets.options<RecurrenceFrequency>(
                              title: 'How often?',
                              values: RecurrenceFrequency.values,
                              labelOf: (frequency) => frequency.label,
                              selected: controller.frequency.value,
                            );
                        if (picked != null) controller.changeFrequency(picked);
                      },
                    ),
                  ),
                  AppSpacing.gapBase,
                  Obx(
                    () => AppTextField(
                      controller: controller.intervalField,
                      label: 'Every N periods',
                      hint: '1 = every period, 2 = every other',
                      keyboardType: TextInputType.number,
                      maxLength: 2,
                      errorText: controller.fieldErrors['interval'],
                    ),
                  ),
                  AppSpacing.gapBase,
                  Obx(
                    () => AppPickerField(
                      label: 'Starts on',
                      value: AppDate.formatDate(controller.startDate.value),
                      trailingIcon: Icons.calendar_today_rounded,
                      onTap: () => _pickStart(context),
                    ),
                  ),
                  AppSpacing.gapBase,
                  Obx(
                    () => AppPickerField(
                      label: 'Ends on',
                      value: controller.endDate.value == null
                          ? null
                          : AppDate.formatDate(controller.endDate.value!),
                      placeholder: 'Never',
                      errorText: controller.fieldErrors['endDate'],
                      trailingIcon: Icons.event_busy_rounded,
                      onTap: () => _pickEnd(context),
                    ),
                  ),
                  AppSpacing.gapSm,
                  Obx(
                    () => SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.autoPost.value,
                      onChanged: controller.toggleAutoPost,
                      title: const Text('Record automatically'),
                      subtitle: Text(
                        'Occurrences are added when you open the app. '
                        'Turn off to only be reminded.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Obx(
                    () => SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.isActive.value,
                      onChanged: controller.toggleActive,
                      title: const Text('Active'),
                    ),
                  ),
                  AppSpacing.gapSm,
                  AppTextField(
                    controller: controller.noteField,
                    label: 'Note',
                    hint: 'Optional',
                    maxLines: 2,
                    maxLength: 240,
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
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          controller.isEditing
                              ? 'Save changes'
                              : 'Create schedule',
                        ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.startDate.value,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) controller.selectStartDate(picked);
  }

  Future<void> _pickEnd(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.endDate.value ?? controller.startDate.value,
      firstDate: controller.startDate.value,
      lastDate: DateTime(now.year + 20),
    );
    controller.selectEndDate(picked);
  }
}
