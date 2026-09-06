import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/base/view_state.dart';
import '../../../../core/utils/app_navigation.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loader.dart';
import '../../../../core/widgets/amount_text.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../domain/entities/account.dart';
import '../../../../routes/app_routes.dart';
import '../controllers/accounts_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class AccountsPage extends GetView<AccountsController> {
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          Obx(
            () => IconButton(
              tooltip: controller.showArchived.value
                  ? 'Hide archived'
                  : 'Show archived',
              onPressed: controller.toggleArchived,
              icon: Icon(
                controller.showArchived.value
                    ? Icons.visibility_off_outlined
                    : Icons.archive_outlined,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Account'),
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: controller.refreshData,
        child: Obx(() {
          final state = controller.state;

          return switch (state) {
            IdleState() || LoadingState() => const AppLoader(),
            ErrorState(:final message) => AppErrorView(
              message: message,
              onRetry: controller.load,
            ),
            EmptyState(:final message) => AppEmptyView(
              title: 'No accounts',
              message: message,
              icon: Icons.account_balance_wallet_outlined,
              action: FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add account'),
              ),
            ),
            LoadedState() => _AccountsList(controller: controller),
          };
        }),
      ),
    );
  }

  Future<void> _openForm([Account? account]) async {
    final saved = await Get.toNamed(AppRoutes.accountForm, arguments: account);
    if (saved == true) await controller.load(showLoader: false);
  }
}

class _AccountsList extends StatelessWidget {
  const _AccountsList({required this.controller});

  final AccountsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Obx(
          () => AppCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total balance',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.gapXs,
                      AmountText.signed(
                        amount: controller.totalBalance.value,
                        style: theme.textTheme.headlineMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.account_balance_wallet_rounded,
                  color: theme.colorScheme.primary,
                  size: 30,
                ),
              ],
            ),
          ),
        ),
        AppSpacing.gapBase,
        Obx(
          () => Column(
            children: [
              for (final account in controller.accounts) ...[
                _AccountTile(account: account, controller: controller),
                AppSpacing.gapSm,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account, required this.controller});

  final Account account;
  final AccountsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: () async {
        final saved = await Get.toNamed(
          AppRoutes.accountForm,
          arguments: account,
        );
        if (saved == true) await controller.load(showLoader: false);
      },
      child: Row(
        children: [
          CategoryAvatar(
            icon: account.icon,
            color: account.color,
            seed: account.id,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    if (account.isArchived) ...[
                      AppSpacing.hGapSm,
                      Icon(
                        Icons.archive_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                AppSpacing.gapXxs,
                Text(
                  account.type.label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AmountText.signed(
                amount: account.currentBalance,
                style: theme.textTheme.titleSmall,
              ),
              AppSpacing.gapXxs,
              Text(
                'Opened ${Money.compact(account.openingBalance)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            onSelected: (action) => _handle(action, context),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'transactions',
                child: Text('View transactions'),
              ),
              PopupMenuItem(
                value: 'archive',
                child: Text(account.isArchived ? 'Restore' : 'Archive'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handle(String action, BuildContext context) async {
    if (action == 'transactions') {
      controller.viewTransactions(account);
      popToRoot(context);
      return;
    }

    if (action == 'archive') {
      await controller.setArchived(account, !account.isArchived);
      return;
    }

    final confirmed = await ConfirmDialog.show(
      title: 'Delete ${account.name}?',
      message:
          'Every transaction in this account will be deleted too. '
          'Archive it instead if you want to keep your history.',
    );
    if (confirmed) await controller.delete(account);
  }
}
