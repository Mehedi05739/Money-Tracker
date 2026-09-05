import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/plan_status.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/plan_form_controller.dart';

class PlanFormPage extends GetView<PlanFormController> {
  const PlanFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit plan' : 'New spending plan'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Obx(
                  () => AppTextField(
                    controller: controller.nameField,
                    label: 'Plan name',
                    hint: 'September budget, Holiday trip…',
                    autofocus: !controller.isEditing,
                    maxLength: 60,
                    errorText: controller.fieldErrors['name'],
                  ),
                ),
                AppSpacing.gapBase,
                Obx(
                  () => AmountField(
                    controller: controller.incomeField,
                    label: 'Expected income this month',
                    errorText: controller.fieldErrors['totalLimit'],
                  ),
                ),
                AppSpacing.gapBase,
                Obx(
                  () => AppPickerField(
                    label: 'Month',
                    value: AppDate.formatMonth(controller.selectedMonth),
                    trailingIcon: Icons.calendar_month_rounded,
                    onTap: () => _pickMonth(context),
                  ),
                ),
                // Offered only when there is something to copy.
                Obx(() {
                  final template = controller.template.value;
                  if (template == null || controller.isEditing) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: controller.copyPrevious.value,
                      onChanged: controller.toggleCopyPrevious,
                      title: const Text('Start from the last plan'),
                      subtitle: Text(
                        'Copies the categories and planned amounts from '
                        '${template.name}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }),
                AppSpacing.gapBase,
                if (controller.isEditing)
                  Obx(
                    () => AppPickerField(
                      label: 'Status',
                      value: controller.status.value.label,
                      onTap: () async {
                        final picked = await PickerSheets.options<PlanStatus>(
                          title: 'Plan status',
                          values: PlanStatus.values,
                          labelOf: (status) => status.label,
                          selected: controller.status.value,
                        );
                        if (picked != null) controller.changeStatus(picked);
                      },
                    ),
                  ),
                if (controller.isEditing) AppSpacing.gapBase,
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
                        final saved = await controller.submit();
                        if (saved != null) navigator.pop(saved);
                      },
                child: controller.isSubmitting.value
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        controller.isEditing ? 'Save changes' : 'Create plan',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Month, not an arbitrary range: a plan is only comparable to the next one
  /// if both cover the same kind of period.
  Future<void> _pickMonth(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedMonth,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select any day in the month to plan',
    );
    if (picked != null) controller.selectMonth(picked);
  }
}
