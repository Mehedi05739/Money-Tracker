import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/settings_controller.dart';
import '../../../../core/theme/app_spacing.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SectionHeader(
            title: 'Appearance',
            padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Obx(
                () => Column(
                  children: [
                    for (final mode in ThemeMode.values)
                      RadioListTile<ThemeMode>(
                        value: mode,
                        // ignore: deprecated_member_use
                        groupValue: controller.themeMode.value,
                        // ignore: deprecated_member_use
                        onChanged: (value) {
                          if (value != null) controller.setThemeMode(value);
                        },
                        title: Text(_themeLabel(mode)),
                        dense: true,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SectionHeader(title: 'Currency'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Obx(
              () => AppCard(
                onTap: _pickCurrency,
                child: Row(
                  children: [
                    Text(
                      controller.currency.value.symbol,
                      style: theme.textTheme.headlineSmall,
                    ),
                    AppSpacing.hGapMd,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            controller.currency.value.name,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            controller.currency.value.code,
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
            ),
          ),
          const SectionHeader(title: 'Defaults'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              onTap: _pickDefaultAccount,
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Default account',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          'Pre-selected when adding a transaction',
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
          ),
          const SectionHeader(title: 'Data'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              onTap: _recalculate,
              child: Row(
                children: [
                  Icon(
                    Icons.calculate_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  AppSpacing.hGapMd,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recalculate balances',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          'Rebuilds every account balance from your '
                          'transaction history',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Obx(
                    () => controller.isSaving.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader(title: 'About'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      AppSpacing.hGapSm,
                      Text(
                        'Your data stays on this device',
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  AppSpacing.gapSm,
                  Text(
                    '${AppConstants.appName} stores everything in a local '
                    'database. Nothing is uploaded, synced or shared.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Match system',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  Future<void> _pickCurrency() async {
    final picked = await PickerSheets.options<SupportedCurrency>(
      title: 'Choose currency',
      values: SupportedCurrency.all,
      labelOf: (currency) =>
          '${currency.symbol}  ${currency.name} (${currency.code})',
      selected: controller.currency.value,
    );
    if (picked != null) await controller.setCurrency(picked);
  }

  Future<void> _pickDefaultAccount() async {
    final result = await Get.find<AccountRepository>().getAccounts();
    final accounts = result.dataOrNull ?? const <Account>[];

    if (accounts.isEmpty) {
      AppSnackbar.info('Add an account first');
      return;
    }

    final picked = await PickerSheets.account(
      accounts,
      selected: accounts.firstWhereOrNull(
        (account) => account.id == controller.defaultAccountId.value,
      ),
      title: 'Default account',
    );
    if (picked != null) await controller.setDefaultAccount(picked.id);
  }

  Future<void> _recalculate() async {
    final confirmed = await ConfirmDialog.show(
      title: 'Recalculate balances?',
      message:
          'Every account balance is rebuilt from its opening balance plus '
          'all recorded transactions. Nothing is deleted.',
      confirmLabel: 'Recalculate',
      destructive: false,
    );
    if (!confirmed) return;

    final ok = await controller.recalculateBalances();
    ok
        ? AppSnackbar.success('Balances recalculated')
        : AppSnackbar.error('Could not recalculate balances');
  }
}
