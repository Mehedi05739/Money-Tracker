import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/transaction_entity.dart';
import '../controllers/add_transaction_controller.dart';

class AddTransactionPage extends GetView<AddTransactionController> {
  const AddTransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Obx(
              () => SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                    icon: Icon(Icons.arrow_upward_rounded),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('Income'),
                    icon: Icon(Icons.arrow_downward_rounded),
                  ),
                ],
                selected: {controller.type.value},
                onSelectionChanged: (values) =>
                    controller.changeType(values.first),
              ),
            ),
            const SizedBox(height: 20),
            Obx(
              () => TextField(
                controller: controller.titleField,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Title',
                  errorText: controller.fieldErrors['title'],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => TextField(
                controller: controller.amountField,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: '\$ ',
                  errorText: controller.fieldErrors['amount'],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller.categoryField,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 32),
            Obx(
              () => FilledButton(
                onPressed:
                    controller.isSubmitting.value ? null : controller.submit,
                child: controller.isSubmitting.value
                    ? const SizedBox.square(
                        dimension: 20,
                        child:
                            CircularProgressIndicator.adaptive(strokeWidth: 2),
                      )
                    : const Text('Save transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
