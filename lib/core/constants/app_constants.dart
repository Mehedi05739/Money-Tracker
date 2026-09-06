class AppConstants {
  const AppConstants._();

  static const String appName = 'Money Tracker';

  /// Shown in About. Kept in step with `version:` in pubspec.yaml by hand —
  /// reading the real package version needs a plugin, and this app deliberately
  /// carries no dependency it does not need.
  static const String appVersion = '1.0.0';

  /// Where support requests go. Shown for copying rather than opened directly,
  /// since launching a mail client would mean another dependency.
  static const String supportEmail = 'support@moneytracker.app';
  static const String databaseFile = 'money_tracker.db';

  /// Transactions fetched per page in the ledger list.
  static const int pageSize = 25;

  /// Rows shown in the dashboard's "recent activity" card.
  static const int recentTransactionCount = 5;

  static const Duration splashDelay = Duration(milliseconds: 600);
  static const Duration searchDebounce = Duration(milliseconds: 300);
}

/// Keys for the `app_settings` table. Preferences only — never credentials.
class SettingKeys {
  const SettingKeys._();

  static const String themeMode = 'theme_mode';
  static const String currencySymbol = 'currency_symbol';
  static const String currencyCode = 'currency_code';
  static const String defaultAccountId = 'default_account_id';
  static const String lastRecurringRun = 'last_recurring_run';
  static const String onboardingComplete = 'onboarding_complete';
  static const String balancesHidden = 'balances_hidden';

  // Financial
  static const String defaultCategoryId = 'default_category_id';
  static const String firstDayOfMonth = 'first_day_of_month';

  // Notifications
  static const String notifyBudget = 'notify_budget';
  static const String notifyPlan = 'notify_plan';
  static const String notifyGoal = 'notify_goal';
  static const String notifyRecurring = 'notify_recurring';

  // Security. Only the *preference* is stored — the credential itself stays
  // with the operating system, so nothing sensitive reaches SQLite.
  static const String appLockEnabled = 'app_lock_enabled';
  static const String appLockBiometric = 'app_lock_biometric';

  /// Daily "did you record today's spending?" reminder.
  static const String dailyReminderEnabled = 'daily_reminder_enabled';
  static const String dailyReminderHour = 'daily_reminder_hour';
  static const String dailyReminderMinute = 'daily_reminder_minute';
}

/// Currencies offered in settings. Symbol is what every amount renders with.
class SupportedCurrency {
  const SupportedCurrency(this.code, this.symbol, this.name);

  final String code;
  final String symbol;
  final String name;

  static const List<SupportedCurrency> all = [
    SupportedCurrency('USD', r'$', 'US Dollar'),
    SupportedCurrency('EUR', '€', 'Euro'),
    SupportedCurrency('GBP', '£', 'British Pound'),
    SupportedCurrency('BDT', '৳', 'Bangladeshi Taka'),
    SupportedCurrency('INR', '₹', 'Indian Rupee'),
    SupportedCurrency('JPY', '¥', 'Japanese Yen'),
    SupportedCurrency('AUD', r'A$', 'Australian Dollar'),
    SupportedCurrency('CAD', r'C$', 'Canadian Dollar'),
    SupportedCurrency('AED', 'د.إ', 'UAE Dirham'),
    SupportedCurrency('SAR', '﷼', 'Saudi Riyal'),
  ];

  static SupportedCurrency byCode(String? code) => all.firstWhere(
    (currency) => currency.code == code,
    orElse: () => all.first,
  );
}
