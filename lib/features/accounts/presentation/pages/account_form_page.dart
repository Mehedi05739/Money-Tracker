import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/account_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/account_form_controller.dart';

class AccountFormPage extends GetView<AccountFormController> {
  const AccountFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit account' : 'New account'),
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
                    label: 'Account name',
                    hint: 'Cash, Salary account, Visa…',
                    autofocus: !controller.isEditing,
                    maxLength: 60,
                    errorText: controller.fieldErrors['name'],
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => AppPickerField(
                    label: 'Account type',
                    value: controller.type.value.label,
                    onTap: () async {
                      final picked = await PickerSheets.options<AccountType>(
                        title: 'Account type',
                        values: AccountType.values,
                        labelOf: (type) => type.label,
                        selected: controller.type.value,
                      );
                      if (picked != null) controller.changeType(picked);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => AmountField(
                    controller: controller.openingBalanceField,
                    label: 'Opening balance',
                    errorText: controller.fieldErrors['openingBalance'],
                    textStyle: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Obx(() {
                  if (controller.canEditOpeningBalance) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Changing the opening balance shifts this account’s '
                      'current balance by the same amount.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }),
                const SizedBox(height: 20),
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
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
                Obx(
                  () => _ColorPicker(
                    selected: controller.color.value,
                    onChanged: controller.changeColor,
                  ),
                ),
              ],
            ),
          ),
          _SubmitBar(controller: controller),
        ],
      ),
    );
  }
}

/// Swatch row backed by the shared chart palette, so account colours and chart
/// colours stay in the same family.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Colour',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in AppColors.chartPalette)
              GestureDetector(
                onTap: () => onChanged(color.toARGB32()),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected == color.toARGB32()
                          ? theme.colorScheme.onSurface
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: selected == color.toARGB32()
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 18)
                      : null,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.controller});

  final AccountFormController controller;

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
                  final navigator = Navigator.of(context);
                  if (await controller.submit()) navigator.pop(true);
                },
          child: controller.isSubmitting.value
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                )
              : Text(controller.isEditing ? 'Save changes' : 'Add account'),
        ),
      ),
    );
  }
}
