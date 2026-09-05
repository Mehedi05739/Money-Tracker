class AppConstants {
  const AppConstants._();

  static const String appName = 'Money Tracker';
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
