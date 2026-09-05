import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/widgets/state_view.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/transaction_controller.dart';
import '../widgets/balance_card.dart';
import '../widgets/transaction_tile.dart';

/// Views stay dumb: read observables, call controller methods, nothing else.
class TransactionListPage extends GetView<TransactionController> {
  const TransactionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Get.toNamed(AppRoutes.addTransaction),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refreshTransactions,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Obx(
                () => BalanceCard(
                  balance: controller.balance,
                  income: controller.totalIncome,
                  expense: controller.totalExpense,
                ),
              ),
            ),
            Expanded(
              child: StateView(
                controller: controller,
                onRetry: controller.loadTransactions,
                emptyAction: FilledButton(
                  onPressed: () => Get.toNamed(AppRoutes.addTransaction),
                  child: const Text('Add your first transaction'),
                ),
                builder: (context) => Obx(
                  () => ListView.separated(
                    padding: const EdgeInsets.only(bottom: 96),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: controller.transactions.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = controller.transactions[index];
                      return TransactionTile(
                        transaction: item,
                        onDelete: () => controller.deleteTransaction(item.id),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
