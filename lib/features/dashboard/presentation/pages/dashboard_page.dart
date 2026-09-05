import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/charts/grouped_bar_chart.dart';
import '../../../../core/widgets/date_range_selector.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/stat_tile.dart';
import '../../../../core/base/view_state.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../routes/app_routes.dart';
import '../../../transactions/presentation/pages/transaction_form_page.dart';
import '../../../transactions/presentation/widgets/transaction_tile.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/balance_header.dart';
import '../widgets/budget_alert_card.dart';
import '../widgets/category_breakdown_card.dart';
import '../widgets/goal_progress_strip.dart';
import '../widgets/plan_progress_card.dart';

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

          if (state is LoadingState || state is IdleState) {
            return const AppLoader();
          }
          if (state is ErrorState) {
            return AppErrorView(
              message: state.message,
              onRetry: controller.load,
            );
          }

          final summary = controller.summary.value;
          if (summary == null) return const AppLoader();

          return _DashboardBody(summary: summary, controller: controller);
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
      padding: const EdgeInsets.only(bottom: 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: BalanceHeader(summary: summary),
        ),
        Obx(
          () => DateRangeSelector(
            selected: controller.range.value,
            onChanged: controller.changeRange,
          ),
        ),
        const SizedBox(height: 16),
        _MetricGrid(summary: summary),
        Obx(() {
          final alerts = controller.alerts;
          if (alerts.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: BudgetAlertCard(
              alerts: alerts,
              onTap: () => Get.toNamed(AppRoutes.budgets),
            ),
          );
        }),
        Obx(() {
          final plan = controller.currentPlan.value;
          if (plan == null) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Spending plan'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                onTapGoal: (goal) => Get.toNamed(
                  AppRoutes.goalDetail,
                  arguments: goal.id,
                ),
              ),
            ],
          );
        }),
        const SectionHeader(title: 'Income vs expense'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TrendCard(trend: summary.trend),
        ),
        const SectionHeader(title: 'Where your money goes'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CategoryBreakdownCard(categories: summary.topCategories),
        ),
        SectionHeader(
          title: 'Recent activity',
          actionLabel: 'See all',
          onAction: () => Get.find<DashboardController>().hasData
              ? Get.toNamed(AppRoutes.shell)
              : null,
        ),
        Obx(() {
          final recent = controller.recent;
          if (recent.isEmpty) {
            return AppEmptyView(
              title: 'No transactions yet',
              message: 'Record your first expense to see your money at work.',
              icon: Icons.receipt_long_outlined,
              action: FilledButton.icon(
                onPressed: () =>
                    TransactionFormPage.open(TransactionType.expense),
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
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final totals = summary.totals;
    final savingsPositive = totals.netSavings >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Net savings',
                  icon: Icons.savings_outlined,
                  value: Money.compact(totals.netSavings),
                  valueColor: savingsPositive
                      ? context.incomeColor
                      : context.expenseColor,
                  footnote:
                      '${totals.savingsRate.toStringAsFixed(0)}% of income',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Spent today',
                  icon: Icons.today_outlined,
                  value: Money.compact(summary.todaySpend),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'This month',
                  icon: Icons.calendar_month_outlined,
                  value: Money.compact(summary.monthSpend),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Avg / day',
                  icon: Icons.timeline_outlined,
                  value: Money.compact(totals.averageDailySpend),
                  footnote: summary.highestCategory == null
                      ? null
                      : 'Top: ${summary.highestCategory!.categoryName}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});

  final List<TrendPoint> trend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: GroupedBarChart(
          groups: [
            for (final point in trend)
              BarGroup(
                label: point.label,
                income: point.income,
                expense: point.expense,
              ),
          ],
        ),
      ),
    );
  }
}
