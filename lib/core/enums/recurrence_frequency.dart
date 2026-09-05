enum RecurrenceFrequency {
  daily,
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly;

  static RecurrenceFrequency fromName(String? value) => values.firstWhere(
    (e) => e.name == value,
    orElse: () => RecurrenceFrequency.monthly,
  );

  String get label => switch (this) {
    RecurrenceFrequency.daily => 'Daily',
    RecurrenceFrequency.weekly => 'Weekly',
    RecurrenceFrequency.biweekly => 'Every 2 weeks',
    RecurrenceFrequency.monthly => 'Monthly',
    RecurrenceFrequency.quarterly => 'Every 3 months',
    RecurrenceFrequency.yearly => 'Yearly',
  };
}
