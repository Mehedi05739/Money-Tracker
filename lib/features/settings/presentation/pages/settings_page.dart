import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/danger_dialog.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../transactions/presentation/widgets/picker_sheets.dart';
import '../controllers/settings_controller.dart';
import 'data_page.dart';
import 'info_page.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Read on build rather than at startup: whether the device can
    // authenticate can change between launches — a user may enrol a
    // fingerprint or remove their screen lock while the app is installed.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => controller.refreshLockCapabilities(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const SectionHeader(
              title: 'Appearance',
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
            ),
            _Group(
              children: [
                Obx(
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
              ],
            ),

            const SectionHeader(title: 'Currency'),
            _Group(
              children: [
                Obx(
                  () => _Tile(
                    icon: Icons.payments_outlined,
                    title: 'Default currency',
                    subtitle:
                        '${controller.currency.value.name} '
                        '(${controller.currency.value.code})',
                    onTap: _pickCurrency,
                  ),
                ),
                Obx(
                  () => _Tile(
                    icon: Icons.attach_money_rounded,
                    title: 'Currency symbol',
                    subtitle:
                        'Amounts show as '
                        '${controller.currencySymbol.value}1,234.50',
                    onTap: () => _editSymbol(context),
                  ),
                ),
              ],
            ),

            const SectionHeader(title: 'Financial'),
            _Group(
              children: [
                _Tile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Default account',
                  subtitle: 'Pre-selected when adding a transaction',
                  onTap: _pickDefaultAccount,
                ),
                _Tile(
                  icon: Icons.label_outline_rounded,
                  title: 'Default category',
                  subtitle: 'Pre-selected for new expenses',
                  onTap: _pickDefaultCategory,
                ),
                Obx(
                  () => _Tile(
                    icon: Icons.event_repeat_outlined,
                    title: 'First day of month',
                    subtitle: _firstDaySubtitle(
                      controller.firstDayOfMonth.value,
                    ),
                    onTap: _pickFirstDay,
                  ),
                ),
              ],
            ),

            const SectionHeader(
              title: 'Notifications',
              subtitle: 'Reminders are scheduled on this device only',
            ),
            _Group(
              children: [
                for (final kind in ReminderKind.values)
                  Obx(
                    () => SwitchListTile.adaptive(
                      value: controller.reminders[kind] ?? false,
                      onChanged: (value) => _toggleReminder(kind, value),
                      title: Text(_reminderTitle(kind)),
                      subtitle: Text(
                        _reminderSubtitle(kind),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      dense: true,
                    ),
                  ),
              ],
            ),

            const SectionHeader(title: 'Security'),
            _Group(
              children: [
                Obx(
                  () => SwitchListTile.adaptive(
                    value: controller.appLockEnabled.value,
                    // Disabled rather than hidden when the device cannot
                    // authenticate, so the subtitle can say why.
                    onChanged: controller.lockSupported.value
                        ? _toggleAppLock
                        : null,
                    title: const Text('App lock'),
                    subtitle: Text(
                      controller.lockSupported.value
                          ? 'Ask for authentication when the app opens'
                          : 'Set a screen lock on this device to use this',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    dense: true,
                  ),
                ),
                Obx(
                  () => SwitchListTile.adaptive(
                    value:
                        controller.preferBiometric.value &&
                        controller.biometricAvailable.value,
                    onChanged:
                        controller.appLockEnabled.value &&
                            controller.biometricAvailable.value
                        ? controller.setPreferBiometric
                        : null,
                    title: const Text('Biometric unlock'),
                    subtitle: Text(
                      !controller.biometricAvailable.value
                          ? 'No fingerprint or face is enrolled on this device'
                          : !controller.appLockEnabled.value
                          ? 'Turn on the app lock to use this'
                          : 'Use your fingerprint or face instead of a PIN',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    dense: true,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(
                'Your PIN and biometrics stay with your device. This app never '
                'sees or stores them.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SectionHeader(title: 'Data'),
            _Group(
              children: [
                _Tile(
                  icon: Icons.folder_outlined,
                  title: 'Export, backup and restore',
                  subtitle: 'Save a copy of your data, or put one back',
                  onTap: () => Get.to(() => const DataPage()),
                ),
                _Tile(
                  icon: Icons.calculate_outlined,
                  title: 'Recalculate balances',
                  subtitle:
                      'Rebuilds every account balance from your transaction '
                      'history',
                  onTap: _recalculate,
                  trailing: Obx(
                    () => controller.isSaving.value
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator.adaptive(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                  ),
                ),
                _Tile(
                  icon: Icons.delete_forever_outlined,
                  title: 'Clear all data',
                  subtitle: 'Permanently delete every record on this device',
                  destructive: true,
                  onTap: _clearAll,
                ),
              ],
            ),

            const SectionHeader(title: 'About'),
            _Group(
              children: [
                _Tile(
                  icon: Icons.info_outline_rounded,
                  title: AppConstants.appName,
                  subtitle: 'Version ${AppConstants.appVersion}',
                  trailing: const SizedBox.shrink(),
                ),
                _Tile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Privacy policy',
                  onTap: () => Get.to(
                    () => const InfoPage(
                      title: 'Privacy policy',
                      sections: AppLegalText.privacy,
                    ),
                  ),
                ),
                _Tile(
                  icon: Icons.description_outlined,
                  title: 'Terms of use',
                  onTap: () => Get.to(
                    () => const InfoPage(
                      title: 'Terms of use',
                      sections: AppLegalText.terms,
                    ),
                  ),
                ),
                _Tile(
                  icon: Icons.mail_outline_rounded,
                  title: 'Contact support',
                  subtitle: AppConstants.supportEmail,
                  trailing: const Icon(Icons.copy_rounded, size: 18),
                  onTap: _copySupportEmail,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Appearance

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'System default',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  // --------------------------------------------------------------- Currency

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

  Future<void> _editSymbol(BuildContext context) async {
    final field = TextEditingController(text: controller.currencySymbol.value);
    final picked = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Currency symbol'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shown before every amount. Leave empty to use the currency’s '
              'own symbol.',
              style: Theme.of(dialogContext).textTheme.bodySmall,
            ),
            AppSpacing.gapMd,
            TextField(
              controller: field,
              autofocus: true,
              inputFormatters: [LengthLimitingTextInputFormatter(4)],
              decoration: const InputDecoration(hintText: 'e.g. Tk'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(field.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    field.dispose();
    if (picked != null) await controller.setCurrencySymbol(picked);
  }

  // -------------------------------------------------------------- Financial

  Future<void> _pickDefaultAccount() async {
    final accounts = await controller.loadAccounts();
    if (accounts.isEmpty) {
      AppSnackbar.info('Add an account first');
      return;
    }

    final picked = await PickerSheets.account(
      accounts,
      selected: controller.defaultAccount,
      title: 'Default account',
    );
    if (picked != null) await controller.setDefaultAccount(picked.id);
  }

  Future<void> _pickDefaultCategory() async {
    final categories = await controller.loadCategories();
    final expenses = categories.where((c) => c.type.isExpense).toList();
    if (expenses.isEmpty) {
      AppSnackbar.info('Add a category first');
      return;
    }

    final picked = await PickerSheets.category(
      expenses,
      selected: controller.defaultCategory,
    );
    if (picked != null) await controller.setDefaultCategory(picked.id);
  }

  Future<void> _pickFirstDay() async {
    final picked = await PickerSheets.options<int>(
      title: 'First day of month',
      values: List.generate(AppDate.maxFirstDayOfMonth, (i) => i + 1),
      labelOf: _firstDaySubtitle,
      selected: controller.firstDayOfMonth.value,
    );
    if (picked != null) await controller.setFirstDayOfMonth(picked);
  }

  static String _firstDaySubtitle(int day) {
    if (day == 1) return 'The 1st — calendar months';
    return 'The ${_ordinal(day)} — months run ${_ordinal(day)} to '
        '${_ordinal(day == 1 ? 28 : day - 1)}';
  }

  static String _ordinal(int day) {
    if (day >= 11 && day <= 13) return '${day}th';
    return switch (day % 10) {
      1 => '${day}st',
      2 => '${day}nd',
      3 => '${day}rd',
      _ => '${day}th',
    };
  }

  // ----------------------------------------------------------- Notifications

  static String _reminderTitle(ReminderKind kind) => switch (kind) {
    ReminderKind.budget => 'Budget warnings',
    ReminderKind.plan => 'Spending plan warnings',
    ReminderKind.goal => 'Goal reminders',
    ReminderKind.recurring => 'Recurring transaction reminders',
  };

  static String _reminderSubtitle(ReminderKind kind) => switch (kind) {
    ReminderKind.budget => 'When a budget is close to or over its limit',
    ReminderKind.plan => 'When a plan category is close to or over its amount',
    ReminderKind.goal => 'Progress towards your savings goals',
    ReminderKind.recurring => 'When a scheduled payment is due',
  };

  Future<void> _toggleReminder(ReminderKind kind, bool value) async {
    final applied = await controller.setReminder(kind, value);
    if (!applied) {
      AppSnackbar.info(
        'Allow notifications for Money Tracker in your device settings to use '
        'reminders',
      );
    }
  }

  // --------------------------------------------------------------- Security

  Future<void> _toggleAppLock(bool value) async {
    final applied = await controller.setAppLock(value);
    if (!applied) {
      AppSnackbar.info('Authentication was not completed, so nothing changed');
      return;
    }
    AppSnackbar.success(value ? 'App lock is on' : 'App lock is off');
  }

  // ------------------------------------------------------------------- Data

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

  Future<void> _clearAll() async {
    final confirmed = await DangerDialog.show(
      title: 'Clear all data?',
      message:
          'Every account, transaction, budget, spending plan, goal and '
          'schedule on this device will be permanently deleted. Exports and '
          'backups you have already saved are kept.',
      confirmWord: 'DELETE',
      confirmLabel: 'Delete everything',
    );
    if (!confirmed) return;

    final ok = await controller.clearAllData();
    ok
        ? AppSnackbar.success('All data cleared')
        : AppSnackbar.error('Could not clear data');
  }

  // ------------------------------------------------------------------ About

  Future<void> _copySupportEmail() async {
    await Clipboard.setData(
      const ClipboardData(text: AppConstants.supportEmail),
    );
    AppSnackbar.success('Support address copied');
  }
}

/// A card holding a run of settings rows, divided.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 56),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One settings row.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = destructive ? theme.colorScheme.error : null;

    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: tint ?? theme.colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(color: tint),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                )),
    );
  }
}
