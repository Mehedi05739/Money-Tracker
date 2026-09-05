import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_navigation.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/category_avatar.dart';
import '../../../../domain/entities/account.dart';

/// What the dashboard is scoped to.
///
/// A wrapper rather than a bare `int?`, because "the user chose All accounts"
/// and "the user dismissed the sheet" are different outcomes and both would
/// otherwise be null.
class AccountScope {
  const AccountScope(this.accountId);

  const AccountScope.all() : accountId = null;

  final int? accountId;

  bool get isAll => accountId == null;
}

/// Picks the account the dashboard reports on.
class AccountScopeSheet extends StatelessWidget {
  const AccountScopeSheet({super.key, required this.accounts, this.selectedId});

  final List<Account> accounts;
  final int? selectedId;

  static Future<AccountScope?> show({
    required List<Account> accounts,
    int? selectedId,
  }) {
    final context = Get.context;
    if (context == null) return Future<AccountScope?>.value();

    return showModalBottomSheet<AccountScope>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          AccountScopeSheet(accounts: accounts, selectedId: selectedId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = accounts.fold<double>(
      0,
      (sum, account) => sum + account.currentBalance,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Text(
                'Show figures for',
                style: theme.textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                children: [
                  _ScopeTile(
                    title: 'All accounts',
                    subtitle: Money.format(total),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.14,
                      ),
                      child: Icon(
                        Icons.all_inclusive_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    isSelected: selectedId == null,
                    onTap: () => popRoute(context, const AccountScope.all()),
                  ),
                  for (final account in accounts)
                    _ScopeTile(
                      title: account.name,
                      subtitle: Money.format(account.currentBalance),
                      leading: CategoryAvatar(
                        icon: account.icon,
                        color: account.color,
                        seed: account.id,
                        size: 40,
                      ),
                      isSelected: account.id == selectedId,
                      onTap: () => popRoute(context, AccountScope(account.id)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.title,
    required this.subtitle,
    required this.leading,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget leading;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: leading,
      title: Text(title, style: theme.textTheme.bodyLarge),
      subtitle: Text(subtitle),
      selected: isSelected,
      trailing: isSelected
          ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
          : null,
    );
  }
}
