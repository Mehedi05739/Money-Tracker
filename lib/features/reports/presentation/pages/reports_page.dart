import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/enums/trend_granularity.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/charts/donut_chart.dart';
import '../../../../core/widgets/charts/grouped_bar_chart.dart';
import '../../../../core/widgets/charts/line_trend_chart.dart';
import '../../../../core/widgets/charts/measure_bar_list.dart';
import '../../../../core/widgets/date_range_selector.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/stat_tile.dart';
import '../../../../domain/entities/analytics.dart';
import '../../../../domain/entities/budget_status.dart';
import '../../../../domain/entities/spending_plan_progress.dart';
import '../controllers/reports_controller.dart';

/// The Reports tab.
///
/// Eight reports is more than one scroll can hold legibly, so they are grouped
/// into three tabs by the question they answer: how did the period go, where
/// did the money go, and did it match the plan.
class ReportsPage extends GetView<ReportsController> {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(96),
            child: Column(
              children: [
                Obx(
                  () => DateRangeSelector(
                    selected: controller.range.value,
                    presets: ReportsController.presets,
                    onChanged: controller.changeRange,
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Spending'),
                    Tab(text: 'Plans'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: ContentWidth(
          child: Obx(() {
            final state = controller.state;

            return switch (state) {
              IdleState() || LoadingState() => const AppLoader(),
              ErrorState(:final message) => AppErrorView(
                message: message,
                onRetry: controller.load,
              ),
              // The Plans tab still has something to say when the ledger is
              // empty, so an empty period replaces only the first two tabs.
              EmptyState(:final message) => TabBarView(
                children: [
                  _EmptyReport(message: message),
                  _EmptyReport(message: message),
                  _PlansTab(controller: controller),
                ],
              ),
              LoadedState() => TabBarView(
                children: [
                  _OverviewTab(controller: controller),
                  _SpendingTab(controller: controller),
                  _PlansTab(controller: controller),
                ],
              ),
            };
          }),
        ),
      ),
    );
  }
}

/// Shared scroll shell: pull-to-refresh plus the padding every tab uses.
class _TabList extends StatelessWidget {
  const _TabList({required this.controller, required this.children});

  final ReportsController controller;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator.adaptive(
      onRefresh: controller.refreshData,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.fabClearance),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

// ---------------------------------------------------------------- Overview --

/// Income vs expense, the headline metrics, and the savings trend.
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final snapshot = controller.snapshot.value;
      if (snapshot == null) return const AppLoader();

      return _TabList(
        controller: controller,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _IncomeExpenseCard(snapshot: snapshot),
          ),
          const SectionHeader(title: 'Key numbers'),
          _MetricGrid(controller: controller, snapshot: snapshot),
          const SectionHeader(
            title: 'Savings trend',
            subtitle: 'Running total kept across the period',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              child: LineTrendChart(
                points: [
                  for (final point in snapshot.savingsTrend)
                    LinePoint(label: point.label, value: point.cumulative),
                ],
                color: snapshot.closingSavings >= 0
                    ? context.incomeColor
                    : context.expenseColor,
                emptyMessage: 'Not enough data to plot a trend',
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Report 1: income against expense for the period.
class _IncomeExpenseCard extends StatelessWidget {
  const _IncomeExpenseCard({required this.snapshot});

  final ReportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totals = snapshot.totals;
    final positive = totals.netSavings >= 0;
    final flow = totals.income + totals.expense;

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            positive ? 'Net saved' : 'Net overspend',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          AppSpacing.gapXs,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Money.format(totals.netSavings.abs()),
              style: theme.textTheme.displaySmall?.copyWith(
                color: positive ? context.incomeColor : context.expenseColor,
              ),
            ),
          ),
          AppSpacing.gapSm,
          Text(
            '${totals.savingsRate.toStringAsFixed(0)}% of income kept · '
            '${totals.transactionCount} transactions',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _FlowRow(
            label: 'Income',
            amount: totals.income,
            color: context.incomeColor,
            total: flow,
            changePercent: snapshot.incomeChangePercent,
          ),
          AppSpacing.gapMd,
          _FlowRow(
            label: 'Expense',
            amount: totals.expense,
            color: context.expenseColor,
            total: flow,
            changePercent: snapshot.expenseChangePercent,
          ),
        ],
      ),
    );
  }
}

class _FlowRow extends StatelessWidget {
  const _FlowRow({
    required this.label,
    required this.amount,
    required this.color,
    required this.total,
    this.changePercent,
  });

  final String label;
  final double amount;
  final Color color;
  final double total;
  final double? changePercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final change = changePercent;

    return Column(
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            if (change != null) ...[
              const SizedBox(width: 8),
              Text(
                '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Spacer(),
            Text(
              Money.format(amount),
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        AppSpacing.gapSm,
        AppProgressBar(
          value: total <= 0 ? 0 : amount / total,
          color: color,
          height: 6,
          warningThreshold: 2,
        ),
      ],
    );
  }
}

/// The eight headline metrics.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.controller, required this.snapshot});

  final ReportsController controller;
  final ReportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final totals = snapshot.totals;
    final topCategory = snapshot.topCategory;
    final highestDay = snapshot.highestDay;

    return Obx(() {
      // Read reactively so utilization refreshes when a budget changes.
      final budgets = controller.budgetOverview;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _MetricRow(
              left: StatTile(
                label: 'Total income',
                icon: Icons.south_west_rounded,
                value: Money.compact(totals.income),
                valueColor: context.incomeColor,
              ),
              right: StatTile(
                label: 'Total expense',
                icon: Icons.north_east_rounded,
                value: Money.compact(totals.expense),
                valueColor: context.expenseColor,
              ),
            ),
            AppSpacing.gapMd,
            _MetricRow(
              left: StatTile(
                label: 'Net savings',
                icon: Icons.savings_outlined,
                value: Money.compact(totals.netSavings),
                valueColor: totals.netSavings >= 0
                    ? context.incomeColor
                    : context.expenseColor,
              ),
              right: StatTile(
                label: 'Savings rate',
                icon: Icons.percent_rounded,
                value: '${totals.savingsRate.toStringAsFixed(0)}%',
                footnote: 'of income kept',
              ),
            ),
            AppSpacing.gapMd,
            _MetricRow(
              left: StatTile(
                label: 'Avg per day',
                icon: Icons.timeline_outlined,
                value: Money.compact(totals.averageDailySpend),
                footnote: '${totals.range.elapsedDays} days elapsed',
              ),
              right: StatTile(
                label: 'Highest day',
                icon: Icons.calendar_today_outlined,
                value: highestDay == null
                    ? '—'
                    : Money.compact(highestDay.amount),
                footnote: highestDay == null
                    ? null
                    : AppDate.formatDate(highestDay.date),
              ),
            ),
            AppSpacing.gapMd,
            _MetricRow(
              left: StatTile(
                label: 'Top category',
                icon: Icons.local_fire_department_outlined,
                value: topCategory?.categoryName ?? '—',
                footnote: topCategory == null
                    ? null
                    : '${Money.compact(topCategory.amount)} · '
                          '${topCategory.share.toStringAsFixed(0)}%',
              ),
              right: StatTile(
                label: 'Budget used',
                icon: Icons.donut_small_outlined,
                value: budgets.isEmpty
                    ? '—'
                    : '${budgets.usagePercent.toStringAsFixed(0)}%',
                valueColor: budgets.isExceeded
                    ? Theme.of(context).colorScheme.error
                    : null,
                footnote: budgets.isEmpty
                    ? 'No active budgets'
                    : '${Money.compact(budgets.spent)} of '
                          '${Money.compact(budgets.limit)}',
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight so a tile with a footnote and one without still make a
    // level pair. `stretch` alone cannot: inside a scroll view the row has no
    // bounded height to stretch to.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          AppSpacing.hGapMd,
          Expanded(child: right),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Spending --

/// Daily/monthly spending, by category, and by account.
class _SpendingTab extends StatelessWidget {
  const _SpendingTab({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final snapshot = controller.snapshot.value;
      if (snapshot == null) return const AppLoader();

      return _TabList(
        controller: controller,
        children: [
          const SectionHeader(title: 'Spending over time'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppSegmented<TrendGranularity>(
              values: TrendGranularity.values,
              selected: snapshot.granularity,
              labelOf: (value) => value.label,
              onChanged: controller.changeGranularity,
            ),
          ),
          AppSpacing.gapMd,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              child: GroupedBarChart(
                groups: [
                  for (final point in snapshot.trend)
                    BarGroup(
                      label: point.label,
                      income: point.income,
                      expense: point.expense,
                    ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'By category'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Obx(
              () => AppSegmented<TransactionType>(
                values: const [TransactionType.expense, TransactionType.income],
                selected: controller.breakdownType.value,
                labelOf: (type) => type.label,
                colorOf: (type) =>
                    type.isIncome ? context.incomeColor : context.expenseColor,
                onChanged: controller.changeBreakdownType,
              ),
            ),
          ),
          AppSpacing.gapMd,
          _CategoryReport(
            breakdown: snapshot.categoryBreakdown,
            typeLabel: controller.breakdownType.value.label.toLowerCase(),
          ),
          const SectionHeader(
            title: 'By account',
            subtitle: 'Where the spending came from',
          ),
          _AccountReport(breakdown: snapshot.accountBreakdown),
        ],
      );
    });
  }
}

/// Report 4: category spending, as a donut plus ranked bars.
class _CategoryReport extends StatelessWidget {
  const _CategoryReport({required this.breakdown, required this.typeLabel});

  final CategoryBreakdown breakdown;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return _NoDataCard(message: 'No $typeLabel recorded in this period.');
    }

    final entries = breakdown.entries;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: AppCard(
            child: Center(
              child: DonutChart(
                slices: [
                  for (var i = 0; i < entries.length; i++)
                    DonutSlice(
                      label: entries[i].categoryName,
                      value: entries[i].amount,
                      color: CategoryIcons.resolveColor(
                        entries[i].categoryColor,
                        seed: i,
                      ),
                    ),
                  if (breakdown.hasOther)
                    DonutSlice(
                      label: 'Other',
                      value: breakdown.otherAmount,
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                ],
                centerTitle: Money.compact(breakdown.total),
                centerSubtitle: '${breakdown.categoryCount} categories',
              ),
            ),
          ),
        ),
        AppSpacing.gapMd,
        MeasureBarList(
          items: [
            for (var i = 0; i < entries.length; i++)
              MeasureBar(
                label: entries[i].categoryName,
                value: Money.format(entries[i].amount),
                trailingNote: '${entries[i].share.toStringAsFixed(0)}%',
                fraction: entries[i].share / 100,
                color: CategoryIcons.resolveColor(
                  entries[i].categoryColor,
                  seed: i,
                ),
                caption:
                    '${entries[i].transactionCount} transaction'
                    '${entries[i].transactionCount == 1 ? '' : 's'}',
                leading: CategoryAvatar(
                  icon: entries[i].categoryIcon,
                  color: entries[i].categoryColor,
                  seed: i,
                  size: 38,
                ),
              ),
            // The tail of the distribution, so the listed shares stay honest
            // about what they leave out.
            if (breakdown.hasOther)
              MeasureBar(
                label: 'Other',
                value: Money.format(breakdown.otherAmount),
                trailingNote: '${breakdown.otherShare.toStringAsFixed(0)}%',
                fraction: breakdown.otherShare / 100,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                caption:
                    '${breakdown.categoryCount - entries.length} more '
                    'categories',
              ),
          ],
        ),
      ],
    );
  }
}

/// Report 5: which account the spending left.
class _AccountReport extends StatelessWidget {
  const _AccountReport({required this.breakdown});

  final AccountBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) {
      return const _NoDataCard(message: 'No spending recorded in this period.');
    }

    final entries = breakdown.entries;

    return MeasureBarList(
      items: [
        for (var i = 0; i < entries.length; i++)
          MeasureBar(
            label: entries[i].accountName,
            value: Money.format(entries[i].amount),
            trailingNote: '${entries[i].share.toStringAsFixed(0)}%',
            fraction: entries[i].share / 100,
            color: CategoryIcons.resolveColor(entries[i].accountColor, seed: i),
            caption:
                '${entries[i].transactionCount} transaction'
                '${entries[i].transactionCount == 1 ? '' : 's'}',
            leading: CategoryAvatar(
              icon: entries[i].accountIcon ?? 'account_balance_wallet',
              color: entries[i].accountColor,
              seed: i,
              size: 38,
            ),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------- Plans --

/// Budget performance and spending plan performance.
class _PlansTab extends StatelessWidget {
  const _PlansTab({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final budgets = controller.budgetStatuses.toList();
      final plan = controller.planProgress.value;

      return _TabList(
        controller: controller,
        children: [
          const SectionHeader(
            title: 'Budget performance',
            subtitle: 'Each budget against its own period',
          ),
          if (budgets.isEmpty)
            const _NoDataCard(
              message: 'No active budgets. Create one to track it here.',
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.sm),
              child: _BudgetSummaryCard(overview: controller.budgetOverview),
            ),
            MeasureBarList(
              items: [
                for (final status in budgets)
                  MeasureBar(
                    label: status.budget.categoryName ?? 'Overall',
                    value: Money.format(status.spent),
                    trailingNote: '${status.usagePercent.toStringAsFixed(0)}%',
                    fraction: status.usageFraction,
                    color: Theme.of(context).colorScheme.primary,
                    isOver: status.isExceeded,
                    caption: status.isExceeded
                        ? 'Over by ${Money.format(status.overspend)} · '
                              'limit ${Money.format(status.limit)}'
                        : '${Money.format(status.remaining)} left · '
                              '${status.daysRemaining} days',
                  ),
              ],
            ),
          ],
          const SectionHeader(
            title: 'Spending plan performance',
            subtitle: 'Planned against actual, by category',
          ),
          if (plan == null)
            const _NoDataCard(
              message: 'No active spending plan for the current month.',
            )
          else
            _PlanReport(progress: plan),
        ],
      );
    });
  }
}

/// Report 7 headline: every active budget added up.
class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard({required this.overview});

  final BudgetOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Budget utilization',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                '${overview.usagePercent.toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: overview.isExceeded ? theme.colorScheme.error : null,
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          AppProgressBar(
            value: overview.usageFraction,
            color: overview.isExceeded
                ? theme.colorScheme.error
                : theme.colorScheme.primary,
            height: 8,
            warningThreshold: 2,
          ),
          AppSpacing.gapSm,
          Text(
            '${Money.format(overview.spent)} of '
            '${Money.format(overview.limit)} across '
            '${overview.budgetCount} budget'
            '${overview.budgetCount == 1 ? '' : 's'}'
            '${overview.exceededCount > 0 ? ' · ${overview.exceededCount} over' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Report 8: the current spending plan, allocation by allocation.
class _PlanReport extends StatelessWidget {
  const _PlanReport({required this.progress});

  final SpendingPlanProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (progress.items.isEmpty) {
      return const _NoDataCard(
        message: 'This plan has no category allocations yet.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.sm),
          child: AppCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(progress.plan.name, style: theme.textTheme.titleSmall),
                    const Spacer(),
                    Text(
                      '${progress.usagePercent.toStringAsFixed(0)}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: progress.isExceeded
                            ? theme.colorScheme.error
                            : null,
                      ),
                    ),
                  ],
                ),
                AppSpacing.gapSm,
                AppProgressBar(
                  value: progress.usageFraction,
                  color: progress.isExceeded
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  height: 8,
                  warningThreshold: 2,
                ),
                AppSpacing.gapSm,
                Text(
                  '${Money.format(progress.totalSpent)} spent of '
                  '${Money.format(progress.expectedIncome)} expected income',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        MeasureBarList(
          items: [
            for (var i = 0; i < progress.items.length; i++)
              MeasureBar(
                label: progress.items[i].item.categoryName ?? 'Unassigned',
                value: Money.format(progress.items[i].spent),
                trailingNote:
                    '${progress.items[i].usagePercent.toStringAsFixed(0)}%',
                fraction: progress.items[i].usageFraction,
                color: CategoryIcons.resolveColor(
                  progress.items[i].item.categoryColor,
                  seed: i,
                ),
                isOver: progress.items[i].isExceeded,
                caption: progress.items[i].isExceeded
                    ? 'Over by ${Money.format(progress.items[i].overspend)} · '
                          'planned ${Money.format(progress.items[i].planned)}'
                    : '${Money.format(progress.items[i].remaining)} left of '
                          '${Money.format(progress.items[i].planned)}',
                leading: CategoryAvatar(
                  icon: progress.items[i].item.categoryIcon,
                  color: progress.items[i].item.categoryColor,
                  seed: i,
                  size: 38,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ Shared --

class _NoDataCard extends StatelessWidget {
  const _NoDataCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.sm),
      child: AppCard(
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _EmptyReport extends StatelessWidget {
  const _EmptyReport({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: AppEmptyView(
            title: 'Nothing to report',
            message:
                '$message. Record some transactions or pick a different '
                'date range.',
            icon: Icons.insights_outlined,
          ),
        ),
      ],
    );
  }
}
