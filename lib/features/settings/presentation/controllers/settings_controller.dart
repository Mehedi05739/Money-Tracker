import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/result.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/settings_repository.dart';

/// App-wide preferences: theme and currency.
///
/// Registered permanently and loaded before the first frame so the app never
/// flashes the wrong theme or currency symbol.
class SettingsController extends GetxController {
  SettingsController(this._repository, this._accountRepository);

  final SettingsRepository _repository;
  final AccountRepository _accountRepository;

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final Rx<SupportedCurrency> currency =
      SupportedCurrency.all.first.obs;
  final RxnInt defaultAccountId = RxnInt();
  final RxBool isSaving = false.obs;

  /// Reads stored preferences and applies them to the formatter.
  /// Failures fall back to defaults rather than blocking startup.
  Future<void> load() async {
    final result = await _repository.getAll();

    result.fold(
      onSuccess: (values) {
        themeMode.value = _parseThemeMode(values[SettingKeys.themeMode]);
        currency.value =
            SupportedCurrency.byCode(values[SettingKeys.currencyCode]);
        defaultAccountId.value =
            int.tryParse(values[SettingKeys.defaultAccountId] ?? '');
        Money.configure(currency.value.symbol);
        return null;
      },
      onError: (failure) {
        AppLogger.w(
          'Falling back to default settings: ${failure.runtimeType}',
          name: 'SETTINGS',
        );
        Money.configure(currency.value.symbol);
        return null;
      },
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == themeMode.value) return;
    themeMode.value = mode;
    Get.changeThemeMode(mode);
    await _persist(SettingKeys.themeMode, mode.name);
  }

  Future<void> setCurrency(SupportedCurrency value) async {
    if (value.code == currency.value.code) return;
    currency.value = value;
    Money.configure(value.symbol);

    await _persist(SettingKeys.currencyCode, value.code);
    await _persist(SettingKeys.currencySymbol, value.symbol);

    // Amounts are rendered from raw values, so a symbol change means every
    // visible figure must repaint.
    Get.forceAppUpdate();
  }

  Future<void> setDefaultAccount(int? accountId) async {
    defaultAccountId.value = accountId;
    if (accountId == null) {
      await _repository.remove(SettingKeys.defaultAccountId);
      return;
    }
    await _persist(SettingKeys.defaultAccountId, '$accountId');
  }

  /// Repairs balances by replaying the ledger. Offered in settings because a
  /// restored backup or a manual database edit can leave them stale.
  Future<bool> recalculateBalances() async {
    isSaving.value = true;
    final result = await _accountRepository.recalculateBalances();
    isSaving.value = false;
    return result.isSuccess;
  }

  Future<void> _persist(String key, String value) async {
    final result = await _repository.set(key, value);
    if (result case Failed<void>(:final failure)) {
      AppLogger.w(
        'Could not persist $key: ${failure.runtimeType}',
        name: 'SETTINGS',
      );
    }
  }

  static ThemeMode _parseThemeMode(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
