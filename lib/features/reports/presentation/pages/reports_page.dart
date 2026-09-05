import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/charts/grouped_bar_chart.dart';
import '../../../../core/widgets/date_range_selector.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../core/widgets/stat_tile.dart';
import '../../../../domain/entities/analytics.dart';
import '../controllers/reports_controller.dart';

class ReportsPage extends GetView<ReportsController> {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Obx(
            () => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DateRangeSelector(
                selected: controller.range.value,
                onChanged: controller.changeRange,
              ),
            ),
          ),
        ),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refreshData,
        child: Obx(() {
          final state = controller.state;

          return switch (state) {
            IdleState() || LoadingState() => const AppLoader(),
            ErrorState(:final message) =>
              AppErrorView(message: message, onRetry: controller.load),
            EmptyState(:final message) => _EmptyReport(message: message),
            LoadedState() => _ReportBody(controller: controller),
          };
        }),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final totals = controller.totals.value;
      if (totals == null) return const AppLoader();

      return ListView(
        padding: const EdgeInsets.only(bottom: 96),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _SummaryCard(
              totals: totals,
              previous: controller.previousTotals.value,
            ),
          ),
          const SectionHeader(title: 'Key numbers'),
          _MetricGrid(controller: controller, totals: totals),
          SectionHeader(
            title: controller.isMonthlyTrend
                ? 'Monthly trend'
                : 'Daily trend',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              child: GroupedBarChart(
                groups: [
                  for (final point in controller.trend)
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
          const SizedBox(height: 12),
          Obx(() {
            final breakdown = controller.breakdown;
            if (breakdown.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AppCard(
                  child: Text(
                    'No ${controller.breakdownType.value.label.toLowerCase()} '
                    'recorded in this period.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              );
            }

            return Column(
              children: [
                for (var i = 0; i < breakdown.length; i++)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _CategoryRow(entry: breakdown[i], seed: i),
                  ),
              ],
            );
          }),
        ],
      );
    });
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totals, required this.previous});

  final PeriodTotals totals;
  final PeriodTotals? previous;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final positive = totals.netSavings >= 0;

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
          const SizedBox(height: 4),
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
          const SizedBox(height: 6),
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
            total: totals.income + totals.expense,
          ),
          const SizedBox(height: 12),
          _FlowRow(
            label: 'Expense',
            amount: totals.expense,
            color: context.expenseColor,
            total: totals.income + totals.expense,
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
  });

  final String label;
  final double amount;
  final Color color;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Text(label, style: theme.textTheme.bodyMedium),
            const Spacer(),
            Text(
              Money.format(amount),
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
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

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.controller, required this.totals});

  final ReportsController controller;
  final PeriodTotals totals;

  @override
  Widget build(BuildContext context) {
    final peak = controller.highestSpendPeriod;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Avg per day',
                  icon: Icons.timeline_outlined,
                  value: Money.compact(totals.averageDailySpend),
                  footnote: '${totals.range.elapsedDays} days elapsed',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Avg spending day',
                  icon: Icons.calendar_today_outlined,
                  value: Money.compact(controller.averageActiveDaySpend),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: 'Top category',
                  icon: Icons.local_fire_department_outlined,
                  value: controller.topCategory?.categoryName ?? '—',
                  footnote: controller.topCategory == null
                      ? null
                      : '${Money.compact(controller.topCategory!.amount)} · '
                          '${controller.topCategory!.share.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  label: 'Highest period',
                  icon: Icons.trending_up_outlined,
                  value: peak == null ? '—' : Money.compact(peak.expense),
                  footnote: peak == null
                      ? null
                      : controller.isMonthlyTrend
                          ? AppDate.formatMonth(peak.date)
                          : AppDate.formatDate(peak.date),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.entry, required this.seed});

  final CategorySpending entry;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryIcons.resolveColor(entry.categoryColor, seed: seed);

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CategoryAvatar(
            icon: entry.categoryIcon,
            color: entry.categoryColor,
            seed: seed,
            size: 38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text(
                      Money.format(entry.amount),
                      style: theme.textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AppProgressBar(
                  value: entry.share / 100,
                  color: color,
                  height: 5,
                  warningThreshold: 2,
                ),
                const SizedBox(height: 5),
                Text(
                  '${entry.share.toStringAsFixed(1)}% · '
                  '${entry.transactionCount} transaction'
                  '${entry.transactionCount == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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
          height: MediaQuery.sizeOf(context).height * 0.6,
          child: AppEmptyView(
            title: 'Nothing to report',
            message: '$message. Record some transactions or pick a different '
                'date range.',
            icon: Icons.insights_outlined,
          ),
        ),
      ],
    );
  }
}
