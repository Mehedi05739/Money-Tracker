/// How the trend charts bucket a period.
///
/// Offered as a user choice rather than inferred from the window alone: "how
/// did I spend day to day this month" and "how do my months compare" are two
/// different questions about the same range.
enum TrendGranularity {
  daily,
  monthly;

  String get label => switch (this) {
    TrendGranularity.daily => 'Daily',
    TrendGranularity.monthly => 'Monthly',
  };

  bool get isDaily => this == TrendGranularity.daily;
}
