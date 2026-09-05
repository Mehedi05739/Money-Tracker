import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/transaction_type.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../plans/presentation/pages/plans_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../transactions/presentation/pages/transaction_form_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../more/presentation/pages/more_page.dart';
import '../controllers/shell_controller.dart';

/// Bottom-navigation host. The centre action opens the expense form, which is
/// the action users perform most.
class ShellPage extends GetView<ShellController> {
  const ShellPage({super.key});

  static const List<_Tab> _tabs = [
    _Tab('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
    _Tab('Transactions', Icons.receipt_long_outlined, Icons.receipt_long_rounded),
    _Tab('Plans', Icons.savings_outlined, Icons.savings_rounded),
    _Tab('Reports', Icons.insights_outlined, Icons.insights_rounded),
    _Tab('More', Icons.more_horiz_outlined, Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => IndexedStack(
          index: controller.currentIndex.value,
          children: [
            for (var index = 0; index < _tabs.length; index++)
              // Deferred: an unvisited tab renders nothing and runs no queries.
              if (controller.isVisited(index))
                _bodyFor(index)
              else
                const SizedBox.shrink(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => TransactionFormPage.open(TransactionType.expense),
        tooltip: 'Add expense',
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      bottomNavigationBar: Obx(
        () => NavigationBar(
          selectedIndex: controller.currentIndex.value,
          onDestinationSelected: controller.changeTab,
          destinations: [
            for (final tab in _tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.selectedIcon),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }

  Widget _bodyFor(int index) => switch (index) {
        0 => const DashboardPage(),
        1 => const TransactionsPage(),
        2 => const PlansPage(),
        3 => const ReportsPage(),
        _ => const MorePage(),
      };
}

class _Tab {
  const _Tab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
