import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../domain/entities/transaction_entity.dart';
import 'transaction_controller.dart';

/// Owns the form's state only. Persisting delegates to [TransactionController],
/// which remains the single source of truth for the transaction list.
class AddTransactionController extends GetxController {
  AddTransactionController(this._transactionController);

  final TransactionController _transactionController;

  final TextEditingController titleField = TextEditingController();
  final TextEditingController amountField = TextEditingController();
  final TextEditingController categoryField =
      TextEditingController(text: 'General');

  final Rx<TransactionType> type = TransactionType.expense.obs;

  RxBool get isSubmitting => _transactionController.isSubmitting;
  RxMap<String, String> get fieldErrors => _transactionController.fieldErrors;

  void changeType(TransactionType value) => type.value = value;

  Future<void> submit() async {
    final saved = await _transactionController.addTransaction(
      TransactionEntity(
        id: '', // assigned by the backend
        title: titleField.text.trim(),
        amount: double.tryParse(amountField.text.trim()) ?? 0,
        type: type.value,
        date: DateTime.now(),
        category: categoryField.text.trim().isEmpty
            ? 'General'
            : categoryField.text.trim(),
      ),
    );

    if (saved) Get.back();
  }

  @override
  void onClose() {
    titleField.dispose();
    amountField.dispose();
    categoryField.dispose();
    super.onClose();
  }
}
