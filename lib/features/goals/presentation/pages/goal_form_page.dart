import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/goal_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/goal_form_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class GoalFormPage extends GetView<GoalFormController> {
  const GoalFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit goal' : 'New goal'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (!controller.isEditing) ...[
                  Text(
                    'Quick start',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  AppSpacing.gapSm,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final suggestion in GoalFormController.suggestions)
                        ActionChip(
                          avatar: Icon(
                            CategoryIcons.resolve(suggestion.icon),
                            size: 16,
                          ),
                          label: Text(suggestion.name),
                          onPressed: () =>
                              controller.applySuggestion(suggestion),
                        ),
                    ],
                  ),
                  AppSpacing.gapLg,
                ],
                Obx(
                  () => AppTextField(
                    controller: controller.nameField,
                    label: 'Goal name',
                    maxLength: 60,
                    errorText: controller.fieldErrors['name'],
                  ),
                ),
                AppSpacing.gapBase,
                Obx(
                  () => AmountField(
                    controller: controller.targetField,
                    label: 'Target amount',
                    errorText: controller.fieldErrors['targetAmount'],
                  ),
                ),
                AppSpacing.gapBase,
                Obx(
                  () => AppPickerField(
                    label: 'Target date',
                    value: controller.targetDate.value == null
                        ? null
                        : AppDate.formatDate(controller.targetDate.value!),
                    placeholder: 'Optional',
                    trailingIcon: Icons.calendar_today_rounded,
                    errorText: controller.fieldErrors['targetDate'],
                    onTap: () => _pickDate(context),
                  ),
                ),
                AppSpacing.gapBase,
                if (controller.isEditing)
                  Obx(
                    () => AppPickerField(
                      label: 'Status',
                      value: controller.status.value.label,
                      onTap: () async {
                        final picked = await PickerSheets.options<GoalStatus>(
                          title: 'Goal status',
                          values: GoalStatus.values,
                          labelOf: (status) => status.label,
                          selected: controller.status.value,
                        );
                        if (picked != null) controller.changeStatus(picked);
                      },
                    ),
                  ),
                if (controller.isEditing) AppSpacing.gapBase,
                Obx(
                  () => AppPickerField(
                    label: 'Icon',
                    value: controller.icon.value ?? 'Default',
                    leading: Icon(
                      CategoryIcons.resolve(controller.icon.value),
                      size: 22,
                    ),
                    onTap: () async {
                      final picked = await PickerSheets.icon(
                        selected: controller.icon.value,
                      );
                      if (picked != null) controller.changeIcon(picked);
                    },
                  ),
                ),
                AppSpacing.gapBase,
                Text(
                  'Colour',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                AppSpacing.gapSm,
                Obx(
                  () => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final color in AppColors.chartPalette)
                        GestureDetector(
                          onTap: () => controller.changeColor(color.toARGB32()),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    controller.color.value == color.toARGB32()
                                    ? theme.colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: controller.color.value == color.toARGB32()
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        ),
                    ],
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
                        controller.isEditing ? 'Save changes' : 'Create goal',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          controller.targetDate.value ?? now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) controller.selectTargetDate(picked);
  }
}
