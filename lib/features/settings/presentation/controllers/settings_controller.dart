import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/events/app_events.dart';
import '../../../../core/services/app_lock_service.dart';
import '../../../../core/services/currency_formatter.dart';
import '../../../../core/services/daily_reminder.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/utils/result.dart';
import '../../../../domain/entities/account.dart';
import '../../../../domain/entities/category.dart';
import '../../../../domain/repositories/account_repository.dart';
import '../../../../domain/repositories/category_repository.dart';
import '../../../../domain/services/data_transfer_service.dart';
import '../../../../domain/repositories/settings_repository.dart';

/// App-wide preferences: theme and currency.
///
/// Registered permanently and loaded before the first frame so the app never
/// flashes the wrong theme or currency symbol.
class SettingsController extends GetxController {
  SettingsController(
    this._repository,
    this._accountRepository,
    this._categoryRepository,
    this._currency,
    this._lock,
    this._notifications,
    this._dataTransfer,
    this._events,
  );

  final SettingsRepository _repository;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final CurrencyFormatter _currency;
  final AppLockService _lock;
  final NotificationService _notifications;
  final DataTransferService _dataTransfer;
  final AppEvents _events;

  final Rx<ThemeMode> themeMode = ThemeMode.system.obs;
  final Rx<SupportedCurrency> currency = SupportedCurrency.all.first.obs;

  /// The symbol amounts render with, mirrored here so the UI can react to it.
  /// The formatter itself is a plain service with no observable of its own.
  final RxString currencySymbol = ''.obs;
  final RxnInt defaultAccountId = RxnInt();
  final RxnInt defaultCategoryId = RxnInt();
  final RxBool isSaving = false.obs;

  /// The day monthly periods roll over on, 1–28.
  final RxInt firstDayOfMonth = 1.obs;

  /// Reminder toggles, keyed by the reminder they gate.
  final RxMap<ReminderKind, bool> reminders = <ReminderKind, bool>{
    for (final kind in ReminderKind.values) kind: false,
  }.obs;

  /// The daily "record today's spending" reminder.
  final RxBool dailyReminderEnabled = false.obs;
  final Rx<ReminderTime> dailyReminderTime = ReminderTime.defaultTime.obs;

  final RxBool appLockEnabled = false.obs;
  final RxBool preferBiometric = false.obs;

  /// Whether the device can authenticate at all, and whether a biometric is
  /// enrolled. Both are read once so the UI can explain *why* a control is
  /// unavailable instead of silently hiding it.
  final RxBool lockSupported = false.obs;
  final RxBool biometricAvailable = false.obs;

  /// Whether balances are masked on screen. Persisted so the dashboard does
  /// not reveal figures again on the next launch.
  final RxBool balancesHidden = false.obs;

  /// Accounts offered when choosing a default. Loaded on demand rather than
  /// held for the life of the app — settings is a rarely visited screen.
  final RxList<Account> accounts = <Account>[].obs;
  final RxList<Category> categories = <Category>[].obs;

  /// Reads stored preferences and applies them to the formatter.
  /// Failures fall back to defaults rather than blocking startup.
  Future<void> load() async {
    final result = await _repository.getAll();

    result.fold(
      onSuccess: (values) {
        themeMode.value = _parseThemeMode(values[SettingKeys.themeMode]);
        currency.value = SupportedCurrency.byCode(
          values[SettingKeys.currencyCode],
        );
        defaultAccountId.value = int.tryParse(
          values[SettingKeys.defaultAccountId] ?? '',
        );
        defaultCategoryId.value = int.tryParse(
          values[SettingKeys.defaultCategoryId] ?? '',
        );
        balancesHidden.value = values[SettingKeys.balancesHidden] == 'true';

        firstDayOfMonth.value = _parseFirstDay(
          values[SettingKeys.firstDayOfMonth],
        );
        // Applied globally so every monthly boundary agrees — see AppDate.
        AppDate.firstDayOfMonth = firstDayOfMonth.value;

        reminders.assignAll({
          for (final kind in ReminderKind.values)
            kind: values[_reminderKey(kind)] == 'true',
        });

        dailyReminderEnabled.value =
            values[SettingKeys.dailyReminderEnabled] == 'true';
        dailyReminderTime.value = ReminderTime.parse(
          values[SettingKeys.dailyReminderHour],
          values[SettingKeys.dailyReminderMinute],
        );

        appLockEnabled.value = values[SettingKeys.appLockEnabled] == 'true';
        preferBiometric.value = values[SettingKeys.appLockBiometric] == 'true';

        // A custom symbol wins over the currency's default, so someone using
        // "Tk" instead of "৳" keeps it across launches.
        final stored = values[SettingKeys.currencySymbol];
        _applySymbol(
          stored == null || stored.isEmpty ? currency.value.symbol : stored,
        );
        return null;
      },
      onError: (failure) {
        AppLogger.w(
          'Falling back to default settings: ${failure.runtimeType}',
          name: 'SETTINGS',
        );
        _applySymbol(currency.value.symbol);
        return null;
      },
    );
  }

  void _applySymbol(String symbol) {
    _currency.useSymbol(symbol);
    currencySymbol.value = symbol;
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
    _applySymbol(value.symbol);

    await _persist(SettingKeys.currencyCode, value.code);
    await _persist(SettingKeys.currencySymbol, value.symbol);

    // Amounts are rendered from raw values, so a symbol change means every
    // visible figure must repaint.
    Get.forceAppUpdate();
  }

  /// Loads the accounts the default-account picker offers.
  ///
  /// The page used to call the repository itself, which put a database read
  /// inside a widget and skipped this layer entirely.
  Future<List<Account>> loadAccounts() async {
    final result = await _accountRepository.getAccounts();
    accounts.assignAll(result.dataOrNull ?? const []);
    return accounts;
  }

  Account? get defaultAccount => accounts.firstWhereOrNull(
    (account) => account.id == defaultAccountId.value,
  );

  Future<void> setBalancesHidden(bool hidden) async {
    balancesHidden.value = hidden;
    await _persist(SettingKeys.balancesHidden, '$hidden');
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

  /// Overrides the symbol amounts render with, without changing the currency.
  ///
  /// An empty value restores the currency's own symbol rather than blanking it.
  Future<void> setCurrencySymbol(String symbol) async {
    final trimmed = symbol.trim();
    final effective = trimmed.isEmpty ? currency.value.symbol : trimmed;
    _applySymbol(effective);
    await _persist(SettingKeys.currencySymbol, effective);
    Get.forceAppUpdate();
  }

  Future<List<Category>> loadCategories() async {
    final result = await _categoryRepository.getCategories();
    categories.assignAll(result.dataOrNull ?? const []);
    return categories;
  }

  Category? get defaultCategory => categories.firstWhereOrNull(
    (category) => category.id == defaultCategoryId.value,
  );

  Future<void> setDefaultCategory(int? categoryId) async {
    defaultCategoryId.value = categoryId;
    if (categoryId == null) {
      await _repository.remove(SettingKeys.defaultCategoryId);
      return;
    }
    await _persist(SettingKeys.defaultCategoryId, '$categoryId');
  }

  /// Moves every monthly boundary in the app to [day].
  Future<void> setFirstDayOfMonth(int day) async {
    final clamped = day.clamp(1, AppDate.maxFirstDayOfMonth);
    firstDayOfMonth.value = clamped;
    AppDate.firstDayOfMonth = clamped;
    await _persist(SettingKeys.firstDayOfMonth, '$clamped');
    // Budget periods, plans and "this month" all shift, so every screen holding
    // a computed range has to recompute it.
    Get.forceAppUpdate();
  }

  /// Turns a reminder on or off.
  ///
  /// Turning one on asks for notification permission first and reports back
  /// whether it was granted, so the UI can say the toggle did not take rather
  /// than showing an "on" switch that will never fire.
  Future<bool> setReminder(ReminderKind kind, bool enabled) async {
    if (!enabled) {
      reminders[kind] = false;
      await _notifications.cancel(kind);
      await _persist(_reminderKey(kind), 'false');
      return true;
    }

    final granted = await _notifications.ensurePermission();
    if (!granted) {
      reminders[kind] = false;
      return false;
    }

    reminders[kind] = true;
    await _persist(_reminderKey(kind), 'true');
    return true;
  }

  /// Live view of what the OS permits, refreshed whenever Settings is shown.
  final Rxn<NotificationDiagnostics> notificationStatus =
      Rxn<NotificationDiagnostics>();

  Future<void> refreshNotificationStatus() async {
    notificationStatus.value = await _notifications.diagnose();
  }

  /// Turns the daily reminder on or off.
  ///
  /// Permission is the only thing that can stop it being switched on. How
  /// precisely the OS will deliver it is reported separately: a device that
  /// only allows approximate alarms should still get its reminder, and
  /// refusing to enable the feature there — as this used to — leaves the user
  /// with no way to turn on something that would have worked.
  Future<ReminderOutcome> setDailyReminder(bool enabled) async {
    if (!enabled) {
      dailyReminderEnabled.value = false;
      await _notifications.cancelDailyReminder();
      await _persist(SettingKeys.dailyReminderEnabled, 'false');
      await refreshNotificationStatus();
      return ReminderOutcome.disabled;
    }

    if (!await _notifications.ensurePermission()) {
      dailyReminderEnabled.value = false;
      await refreshNotificationStatus();
      return ReminderOutcome.permissionDenied;
    }

    final precision = await _notifications.scheduleDailyReminder(
      dailyReminderTime.value,
    );
    await refreshNotificationStatus();

    if (precision == DeliveryPrecision.none) {
      dailyReminderEnabled.value = false;
      return ReminderOutcome.scheduleFailed;
    }

    dailyReminderEnabled.value = true;
    await _persist(SettingKeys.dailyReminderEnabled, 'true');

    return precision == DeliveryPrecision.exact
        ? ReminderOutcome.scheduledExactly
        : ReminderOutcome.scheduledInexactly;
  }

  /// Asks for the "Alarms & reminders" permission and re-schedules with it.
  ///
  /// Android 14 and later withhold it from apps targeting API 34+, so a
  /// reminder that was only approximate can be upgraded once the user grants
  /// it — without this there is no route from "arrives late" to "arrives on
  /// time" inside the app.
  Future<bool> upgradeToExactAlarms() async {
    final granted = await _notifications.requestExactAlarms();
    if (granted && dailyReminderEnabled.value) {
      await _notifications.scheduleDailyReminder(dailyReminderTime.value);
    }
    await refreshNotificationStatus();
    return granted;
  }

  /// Posts a reminder immediately, to prove delivery works on this device.
  Future<bool> sendTestReminder() => _notifications.sendTestReminder();

  /// Moves the reminder to a new time, re-scheduling if it is on.
  Future<void> setDailyReminderTime(ReminderTime time) async {
    dailyReminderTime.value = time;
    await _persist(SettingKeys.dailyReminderHour, '${time.hour}');
    await _persist(SettingKeys.dailyReminderMinute, '${time.minute}');

    if (dailyReminderEnabled.value) {
      await _notifications.scheduleDailyReminder(time);
    }
  }

  /// Re-queues the reminder every launch, if it is switched on.
  ///
  /// Deliberately unconditional. The plugin can report a reminder as "pending"
  /// from its own persisted list long after Android has dropped the actual
  /// alarm — a force-stop or reboot clears the alarm but not the list — so
  /// checking first made the repair skip exactly when it was needed, and the
  /// reminder silently stopped arriving. Re-scheduling is idempotent: the same
  /// notification id replaces whatever was queued.
  Future<void> ensureDailyReminderScheduled() async {
    if (!dailyReminderEnabled.value) return;
    await _notifications.scheduleDailyReminder(dailyReminderTime.value);
  }

  /// Reads what the device can actually do, so Security can be shown honestly.
  Future<void> refreshLockCapabilities() async {
    lockSupported.value = await _lock.isSupported();
    biometricAvailable.value = await _lock.hasBiometrics();
  }

  /// Enabling asks for authentication first: the user must prove they can get
  /// back in *before* the door is locked behind them.
  Future<bool> setAppLock(bool enabled) async {
    final result = await _lock.authenticate(
      reason: enabled
          ? 'Confirm it is you before turning on the app lock'
          : 'Confirm it is you to turn off the app lock',
    );
    if (result != UnlockResult.granted) return false;

    appLockEnabled.value = enabled;
    await _persist(SettingKeys.appLockEnabled, '$enabled');
    return true;
  }

  Future<void> setPreferBiometric(bool value) async {
    preferBiometric.value = value;
    await _persist(SettingKeys.appLockBiometric, '$value');
  }

  /// Prompts for unlock at launch. Returns true when the app may proceed.
  Future<bool> unlock() async {
    if (!appLockEnabled.value) return true;
    final result = await _lock.authenticate(
      reason: 'Unlock Money Tracker',
      biometricOnly: false,
    );
    // An unavailable authenticator must not lock the user out of their own
    // ledger — a device whose biometrics were removed still has to open.
    return result != UnlockResult.denied;
  }

  static String _reminderKey(ReminderKind kind) => switch (kind) {
    ReminderKind.budget => SettingKeys.notifyBudget,
    ReminderKind.plan => SettingKeys.notifyPlan,
    ReminderKind.goal => SettingKeys.notifyGoal,
    ReminderKind.recurring => SettingKeys.notifyRecurring,
  };

  static int _parseFirstDay(String? value) {
    final parsed = int.tryParse(value ?? '') ?? 1;
    return parsed.clamp(1, AppDate.maxFirstDayOfMonth);
  }

  /// Wipes every record and reseeds the defaults.
  ///
  /// Confirmed by the caller before it reaches here — see `DangerDialog`.
  Future<bool> clearAllData() async {
    isSaving.value = true;
    try {
      await _dataTransfer.clearAll();
      for (final change in DataChange.values) {
        _events.emit(change);
      }
      // The wipe removed the stored preferences too, so the in-memory copies
      // have to fall back rather than keep claiming values that no longer
      // exist.
      await load();
      return true;
    } catch (error) {
      AppLogger.w(
        'Could not clear data: ${error.runtimeType}',
        name: 'SETTINGS',
      );
      return false;
    } finally {
      isSaving.value = false;
    }
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
