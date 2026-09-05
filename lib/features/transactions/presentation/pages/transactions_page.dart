import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/enums/transaction_type.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/date_range_selector.dart';
import '../controllers/transactions_controller.dart';
import '../widgets/transaction_filter_sheet.dart';
import '../widgets/transaction_tile.dart';
import 'transaction_form_page.dart';

class TransactionsPage extends GetView<TransactionsController> {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          Obx(
            () => Badge(
              isLabelVisible: controller.activeFilterCount > 0,
              label: Text('${controller.activeFilterCount}'),
              child: IconButton(
                tooltip: 'Filter',
                onPressed: () => _openFilters(),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: TextField(
                  onChanged: controller.search,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search transactions',
                    prefixIcon: Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                  ),
                ),
              ),
              Obx(
                () => DateRangeSelector(
                  selected: controller.range.value,
                  onChanged: controller.changeRange,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Obx(() {
            if (controller.state is! LoadedState) {
              return const SizedBox.shrink();
            }
            return _SummaryStrip(controller: controller);
          }),
          Expanded(
            child: RefreshIndicator.adaptive(
              onRefresh: controller.refreshData,
              child: Obx(() {
                final state = controller.state;

                return switch (state) {
                  IdleState() || LoadingState() => const AppLoader(),
                  ErrorState(:final message) => AppErrorView(
                      message: message,
                      onRetry: controller.load,
                    ),
                  EmptyState(:final message) => _EmptyLedger(
                      message: message,
                      hasFilters: controller.activeFilterCount > 0,
                      onClear: controller.clearFilters,
                    ),
                  LoadedState() => _LedgerList(controller: controller),
                };
              }),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters() async {
    final applied = await TransactionFilterSheet.show(
      initial: controller.filter.value,
      categories: controller.categories,
      accounts: controller.accounts,
    );
    if (applied != null) controller.applyFilter(applied);
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.controller});

  final TransactionsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      final count = controller.totalCount.value;
      final loaded = controller.transactions.length;

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Row(
          children: [
            Text(
              count == loaded
                  ? '$count transaction${count == 1 ? '' : 's'}'
                  : 'Showing $loaded of $count',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (controller.activeFilterCount > 0)
              TextButton(
                onPressed: controller.clearFilters,
                child: const Text('Clear filters'),
              ),
          ],
        ),
      );
    });
  }
}

class _LedgerList extends StatelessWidget {
  const _LedgerList({required this.controller});

  final TransactionsController controller;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      // Prefetch the next page before the user reaches the end, so scrolling
      // stays continuous.
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 400) {
          controller.loadMore();
        }
        return false;
      },
      child: Obx(() {
        final groups = controller.groups;

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 96),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: groups.length + 1,
          itemBuilder: (context, index) {
            if (index == groups.length) {
              return _ListFooter(controller: controller);
            }

            final group = groups[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TransactionDateHeader(date: group.date, net: group.net),
                for (final transaction in group.transactions)
                  Dismissible(
                    key: ValueKey(transaction.id),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (_) => ConfirmDialog.show(
                      title: 'Delete transaction?',
                      message:
                          'This will remove "${transaction.title}" and adjust '
                          'your account balance. This cannot be undone.',
                    ),
                    onDismissed: (_) =>
                        controller.deleteTransaction(transaction),
                    background: _DismissBackground(),
                    child: TransactionTile(
                      transaction: transaction,
                      showDate: true,
                      // The list refreshes itself through AppEvents.
                      onTap: () => TransactionFormPage.edit(transaction),
                    ),
                  ),
              ],
            );
          },
        );
      }),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final TransactionsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Obx(() {
      if (controller.isLoadingMore.value) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
          ),
        );
      }
      if (controller.hasMore.value) return const SizedBox(height: 24);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'End of ${controller.range.value.label.toLowerCase()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    });
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: theme.colorScheme.error,
      child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.onError),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger({
    required this.message,
    required this.hasFilters,
    required this.onClear,
  });

  final String message;
  final bool hasFilters;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: AppEmptyView(
            title: 'Nothing here',
            message: message,
            icon: Icons.receipt_long_outlined,
            action: hasFilters
                ? OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
                    label: const Text('Clear filters'),
                  )
                : FilledButton.icon(
                    onPressed: () =>
                        TransactionFormPage.open(TransactionType.expense),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add a transaction'),
                  ),
          ),
        ),
      ],
    );
  }
}
