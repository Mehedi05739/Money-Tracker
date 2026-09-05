import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/category_form_controller.dart';

class CategoryFormPage extends GetView<CategoryFormController> {
  const CategoryFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit category' : 'New category'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                if (controller.canChangeType)
                  Obx(
                    () => AppSegmented<TransactionType>(
                      values: const [
                        TransactionType.expense,
                        TransactionType.income,
                      ],
                      selected: controller.type.value,
                      labelOf: (type) => type.label,
                      colorOf: (type) => type.isIncome
                          ? context.incomeColor
                          : context.expenseColor,
                      onChanged: controller.changeType,
                    ),
                  ),
                if (controller.canChangeType) const SizedBox(height: 20),
                Obx(
                  () => AppTextField(
                    controller: controller.nameField,
                    label: 'Category name',
                    autofocus: !controller.isEditing,
                    maxLength: 60,
                    errorText: controller.fieldErrors['name'],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Appearance', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
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
                const SizedBox(height: 16),
                Text(
                  'Colour',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
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
                                color: controller.color.value == color.toARGB32()
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
                        child:
                            CircularProgressIndicator.adaptive(strokeWidth: 2),
                      )
                    : Text(
                        controller.isEditing ? 'Save changes' : 'Add category',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
