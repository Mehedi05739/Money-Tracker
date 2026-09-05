import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/charts/grouped_bar_chart.dart';
import '../../../../core/widgets/date_range_selector.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/stat_tile.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../routes/app_routes.dart';
import '../../../shell/presentation/controllers/shell_controller.dart';
import '../../../transactions/presentation/pages/transaction_form_page.dart';
import '../../../transactions/presentation/widgets/quick_add_sheet.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/balance_header.dart';
import '../widgets/budget_summary_card.dart';
import '../widgets/category_breakdown_card.dart';
import '../widgets/goal_progress_strip.dart';
import '../widgets/plan_progress_card.dart';

/// The dashboard answers, in order: what do I have, what came in and went out,
/// am I saving, am I within budget, where is it going, and what happened
/// recently. Anything that does not serve one of those questions is a tap away
/// rather than on this screen.
class DashboardPage extends GetView<DashboardController> {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            tooltip: 'Accounts',
            onPressed: () => Get.toNamed(AppRoutes.accounts),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Get.toNamed(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refreshData,
        child: Obx(() {
          final state = controller.state;

          if (state is ErrorState) {
            return AppErrorView(
              message: state.message,
              onRetry: controller.load,
            );
          }

          final summary = controller.summary.value;
          if (state is LoadingState || state is IdleState || summary == null) {
            return const AppLoader();
          }

          return ContentWidth(
            child: _DashboardBody(summary: summary, controller: controller),
          );
        }),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary, required this.controller});

  final DashboardSummary summary;
  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.fabClearance),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // 1 — balance, with income and expense beneath it.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.base,
            AppSpacing.md,
          ),
          child: BalanceHeader(summary: summary),
        ),
        Obx(
          () => DateRangeSelector(
            selected: controller.range.value,
            onChanged: controller.changeRange,
          ),
        ),
        AppSpacing.gapBase,

        // 2 — savings, and what today has cost so far.
        _MetricRow(summary: summary),

        // 3 — budget status.
        Obx(() {
          final overview = controller.budgetOverview;
          if (overview.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.base,
              AppSpacing.base,
              AppSpacing.base,
              0,
            ),
            child: BudgetSummaryCard(
              overview: overview,
              onTap: () => Get.toNamed(AppRoutes.budgets),
            ),
          );
        }),

        // 4 — spending overview.
        const SectionHeader(title: 'Where your money goes'),
        Padding(
          padding: AppSpacing.screenH,
          child: CategoryBreakdownCard(breakdown: summary.breakdown),
        ),
        const SectionHeader(title: 'Income vs expense'),
        Padding(
          padding: AppSpacing.screenH,
          child: AppCard(
            child: GroupedBarChart(
              groups: [
                for (final point in summary.trend)
                  BarGroup(
                    label: point.label,
                    income: point.income,
                    expense: point.expense,
                  ),
              ],
            ),
          ),
        ),

        // 5 — recent activity.
        SectionHeader(
          title: 'Recent activity',
          actionLabel: 'See all',
          // Switch tabs rather than navigate: pushing the shell route from
          // inside the shell stacked a second copy of the whole app on top.
          onAction: () =>
              Get.find<ShellController>().changeTab(ShellTabs.transactions),
        ),
        Obx(() {
          final recent = controller.recent;
          if (recent.isEmpty) {
            return AppEmptyView(
              title: 'No transactions yet',
              message: 'Record your first expense to see your money at work.',
              icon: Icons.receipt_long_outlined,
              action: FilledButton.icon(
                onPressed: QuickAddSheet.show,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a transaction'),
              ),
            );
          }
          return Column(
            children: [
              for (final transaction in recent)
                TransactionTile(
                  transaction: transaction,
                  dense: true,
                  onTap: () => TransactionFormPage.edit(transaction),
                ),
            ],
          );
        }),

        // Secondary: plans and goals, below the questions above.
        Obx(() {
          final plan = controller.currentPlan.value;
          if (plan == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Spending plan'),
              Padding(
                padding: AppSpacing.screenH,
                child: PlanProgressCard(
                  progress: plan,
                  onTap: () => Get.toNamed(
                    AppRoutes.spendingPlanDetail,
                    arguments: plan.plan.id,
                  ),
                ),
              ),
            ],
          );
        }),
        Obx(() {
          final goals = controller.goals;
          if (goals.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(
                title: 'Goals',
                actionLabel: 'View all',
                onAction: () => Get.toNamed(AppRoutes.goals),
              ),
              GoalProgressStrip(
                goals: goals,
                onTapGoal: (goal) =>
                    Get.toNamed(AppRoutes.goalDetail, arguments: goal.id),
              ),
            ],
          );
        }),
      ],
    );
  }
}

/// Savings and today's spend. Monthly totals and averages live in Reports —
/// repeating them here is what turns a dashboard into a wall of numbers.
class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final totals = summary.totals;
    final positive = totals.netSavings >= 0;

    final tiles = <Widget>[
      StatTile(
        label: positive ? 'Saved' : 'Overspent',
        icon: Icons.savings_outlined,
        value: Money.compact(totals.netSavings.abs()),
        valueColor: positive ? context.incomeColor : context.expenseColor,
        footnote: '${totals.savingsRate.toStringAsFixed(0)}% of income kept',
      ),
      StatTile(
        label: 'Spent today',
        icon: Icons.today_outlined,
        value: Money.compact(summary.todaySpend),
        footnote: summary.highestCategory == null
            ? null
            : 'Top: ${summary.highestCategory!.categoryName}',
      ),
    ];

    return Padding(
      padding: AppSpacing.screenH,
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) AppSpacing.hGapMd,
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}
