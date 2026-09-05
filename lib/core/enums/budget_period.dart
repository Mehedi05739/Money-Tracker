enum BudgetPeriod {
  weekly,
  monthly,
  quarterly,
  yearly,
  custom;

  static BudgetPeriod fromName(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => BudgetPeriod.monthly,
  );

  String get label => switch (this) {
    BudgetPeriod.weekly => 'Weekly',
    BudgetPeriod.monthly => 'Monthly',
    BudgetPeriod.quarterly => 'Quarterly',
    BudgetPeriod.yearly => 'Yearly',
    BudgetPeriod.custom => 'Custom range',
  };

  /// Number of days used to pro-rate a budget into a daily allowance.
  /// `null` for [custom], where the explicit end date decides.
  int? get approximateDays => switch (this) {
    BudgetPeriod.weekly => 7,
    BudgetPeriod.monthly => 30,
    BudgetPeriod.quarterly => 91,
    BudgetPeriod.yearly => 365,
    BudgetPeriod.custom => null,
  };
}
