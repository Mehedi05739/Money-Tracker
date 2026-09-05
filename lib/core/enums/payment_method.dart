enum PaymentMethod {
  cash,
  card,
  bankTransfer,
  mobileWallet,
  cheque,
  other;

  static PaymentMethod? fromName(String? value) {
    if (value == null) return null;
    for (final method in values) {
      if (method.name == value) return method;
    }
    return null;
  }

  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.card => 'Card',
        PaymentMethod.bankTransfer => 'Bank transfer',
        PaymentMethod.mobileWallet => 'Mobile wallet',
        PaymentMethod.cheque => 'Cheque',
        PaymentMethod.other => 'Other',
      };
}
