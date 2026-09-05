import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../routes/app_routes.dart';
import '../../../../core/theme/app_radius.dart';

/// Hub for the modules that do not warrant a permanent tab.
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  static const List<_Destination> _destinations = [
    _Destination(
      route: AppRoutes.accounts,
      icon: Icons.account_balance_wallet_outlined,
      title: 'Accounts & wallets',
      subtitle: 'Cash, bank, cards and their balances',
    ),
    _Destination(
      route: AppRoutes.categories,
      icon: Icons.label_outline_rounded,
      title: 'Categories',
      subtitle: 'Organise where your money goes',
    ),
    _Destination(
      route: AppRoutes.budgets,
      icon: Icons.pie_chart_outline_rounded,
      title: 'Budgets',
      subtitle: 'Set limits and track them as you spend',
    ),
    _Destination(
      route: AppRoutes.goals,
      icon: Icons.flag_outlined,
      title: 'Financial goals',
      subtitle: 'Save towards the things you are planning',
    ),
    _Destination(
      route: AppRoutes.recurring,
      icon: Icons.autorenew_rounded,
      title: 'Recurring transactions',
      subtitle: 'Rent, salary and subscriptions on a schedule',
    ),
    _Destination(
      route: AppRoutes.settings,
      icon: Icons.settings_outlined,
      title: 'Settings',
      subtitle: 'Theme, currency and data tools',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.base,
            AppSpacing.sm,
            AppSpacing.base,
            AppSpacing.fabClearance,
          ),
          children: [
            for (final destination in _destinations) ...[
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                onTap: () => Get.toNamed(destination.route),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: AppRadius.smAll,
                      ),
                      child: Icon(
                        destination.icon,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            destination.title,
                            style: theme.textTheme.titleSmall,
                          ),
                          AppSpacing.gapXxs,
                          Text(
                            destination.subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapSm,
            ],
            AppSpacing.gapMd,
            Center(
              child: Text(
                '${AppConstants.appName} · your data stays on this device',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination {
  const _Destination({
    required this.route,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String route;
  final IconData icon;
  final String title;
  final String subtitle;
}
