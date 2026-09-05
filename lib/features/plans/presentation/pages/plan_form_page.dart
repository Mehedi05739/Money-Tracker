import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/plan_status.dart';
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
                const SizedBox(height: 16),
                Obx(
                  () => AmountField(
                    controller: controller.limitField,
                    label: 'Total spending limit',
                    errorText: controller.fieldErrors['totalLimit'],
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => AppPickerField(
                    label: 'Plan period',
                    value: '${AppDate.formatDate(controller.startDate.value)}'
                        ' – ${AppDate.formatDate(controller.endDate.value)}',
                    trailingIcon: Icons.date_range_rounded,
                    onTap: () => _pickRange(context),
                  ),
                ),
                const SizedBox(height: 16),
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
                if (controller.isEditing) const SizedBox(height: 16),
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
                        child:
                            CircularProgressIndicator.adaptive(strokeWidth: 2),
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
