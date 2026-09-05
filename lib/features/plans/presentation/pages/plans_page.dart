import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../domain/entities/spending_plan.dart';
import '../../../../routes/app_routes.dart';
import '../../../dashboard/presentation/widgets/plan_progress_card.dart';
import '../controllers/plans_controller.dart';

class PlansPage extends GetView<PlansController> {
  const PlansPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending plans'),
        actions: [
          IconButton(
            tooltip: 'Budgets',
            onPressed: () => Get.toNamed(AppRoutes.budgets),
            icon: const Icon(Icons.pie_chart_outline_rounded),
          ),
          IconButton(
            tooltip: 'Goals',
            onPressed: () => Get.toNamed(AppRoutes.goals),
            icon: const Icon(Icons.flag_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Plan'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refreshData,
        child: Obx(() {
          final state = controller.state;

          return switch (state) {
            IdleState() || LoadingState() => const AppLoader(),
            ErrorState(:final message) =>
              AppErrorView(message: message, onRetry: controller.load),
            EmptyState() => AppEmptyView(
                title: 'No spending plans',
                message: 'A plan sets a total limit for a period, then splits '
                    'it across categories so you know what is left.',
                icon: Icons.savings_outlined,
                action: FilledButton.icon(
                  onPressed: _openForm,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create a plan'),
                ),
              ),
            LoadedState() => _PlansBody(controller: controller),
          };
        }),
      ),
    );
  }

  Future<void> _openForm() async {
    final saved = await Get.toNamed(AppRoutes.spendingPlanForm);
    if (saved != null) await controller.load(showLoader: false);
  }
}

class _PlansBody extends StatelessWidget {
  const _PlansBody({required this.controller});

  final PlansController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Obx(() {
          final current = controller.current.value;
          if (current == null) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Current plan',
                padding: EdgeInsets.fromLTRB(16, 16, 8, 8),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: PlanProgressCard(
                  progress: current,
                  onTap: () => _openDetail(current.plan.id),
                ),
              ),
            ],
          );
        }),
        Obx(() {
          final others = controller.otherPlans;
          if (others.isEmpty) return const SizedBox.shrink();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'All plans'),
              for (final plan in others)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _PlanTile(plan: plan, controller: controller),
                ),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _openDetail(int planId) async {
    await Get.toNamed(AppRoutes.spendingPlanDetail, arguments: planId);
    await controller.load(showLoader: false);
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({required this.plan, required this.controller});

  final SpendingPlan plan;
  final PlansController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      onTap: () async {
        await Get.toNamed(AppRoutes.spendingPlanDetail, arguments: plan.id);
        await controller.load(showLoader: false);
      },
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${AppDate.formatDate(plan.startDate)} – '
                  '${AppDate.formatDate(plan.endDate)} · ${plan.status.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(Money.compact(plan.totalLimit), style: theme.textTheme.titleSmall),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onSelected: (_) => _confirmDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await ConfirmDialog.show(
      title: 'Delete ${plan.name}?',
      message: 'The plan and its category allocations will be removed. '
          'Your transactions are not affected.',
    );
    if (confirmed) await controller.delete(plan);
  }
}
