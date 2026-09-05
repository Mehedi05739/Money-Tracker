enum AccountType {
  cash,
  bank,
  card,
  wallet,
  savings,
  investment;

  static AccountType fromName(String? value) =>
      values.firstWhere((e) => e.name == value, orElse: () => AccountType.cash);

  String get label => switch (this) {
    AccountType.cash => 'Cash',
    AccountType.bank => 'Bank account',
    AccountType.card => 'Credit / debit card',
    AccountType.wallet => 'Mobile wallet',
    AccountType.savings => 'Savings',
    AccountType.investment => 'Investment',
  };
}
