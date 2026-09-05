import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../dashboard/presentation/pages/dashboard_page.dart';
import '../../../more/presentation/pages/more_page.dart';
import '../../../plans/presentation/pages/plans_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../transactions/presentation/pages/transactions_page.dart';
import '../../../transactions/presentation/widgets/quick_add_sheet.dart';
import '../controllers/shell_controller.dart';

/// Navigation host.
///
/// Phones get a bottom bar with a centre action; at [LayoutSize.wide] the bar
/// becomes a side rail so the content column is not squeezed by chrome that
/// only needs to be reachable, not prominent.
class ShellPage extends GetView<ShellController> {
  const ShellPage({super.key});

  static const List<ShellTab> tabs = [
    ShellTab('Dashboard', Icons.dashboard_outlined, Icons.dashboard_rounded),
    ShellTab(
      'Transactions',
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
    ),
    ShellTab('Plans', Icons.savings_outlined, Icons.savings_rounded),
    ShellTab('Reports', Icons.insights_outlined, Icons.insights_rounded),
    ShellTab('More', Icons.more_horiz_outlined, Icons.more_horiz_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final useRail = context.usesNavigationRail;

    return Scaffold(
      body: useRail
          ? _RailLayout(controller: controller)
          : _TabBody(controller: controller),
      floatingActionButton: useRail
          ? null
          : FloatingActionButton(
              onPressed: QuickAddSheet.show,
              tooltip: 'Add transaction',
              child: const Icon(Icons.add_rounded, size: 28),
            ),
      bottomNavigationBar: useRail
          ? null
          : Obx(
              () => NavigationBar(
                selectedIndex: controller.currentIndex.value,
                onDestinationSelected: controller.changeTab,
                destinations: [
                  for (final tab in tabs)
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
}

class _RailLayout extends StatelessWidget {
  const _RailLayout({required this.controller});

  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Obx(
          () => NavigationRail(
            selectedIndex: controller.currentIndex.value,
            onDestinationSelected: controller.changeTab,
            // The primary action rides at the top of the rail, where a FAB
            // would sit on a phone.
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: FloatingActionButton(
                onPressed: QuickAddSheet.show,
                tooltip: 'Add transaction',
                child: const Icon(Icons.add_rounded, size: 28),
              ),
            ),
            destinations: [
              for (final tab in ShellPage.tabs)
                NavigationRailDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: Text(tab.label),
                ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _TabBody(controller: controller)),
      ],
    );
  }
}

/// Keeps visited tabs alive so switching back does not re-run their queries.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.controller});

  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => IndexedStack(
        index: controller.currentIndex.value,
        children: [
          for (var index = 0; index < ShellPage.tabs.length; index++)
            // An unvisited tab renders nothing and runs no queries.
            if (controller.isVisited(index))
              _bodyFor(index)
            else
              const SizedBox.shrink(),
        ],
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

class ShellTab {
  const ShellTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
