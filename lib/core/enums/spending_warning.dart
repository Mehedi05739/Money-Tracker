/// How close spending is to what was planned.
///
/// The thresholds are fixed rather than configurable because they are the
/// point of a plan: a single "at risk" flag tells the user they are close,
/// where these tell them *how* close while there is still time to act.
enum SpendingWarning {
  /// Under 70% — nothing to say.
  none,

  /// 70% or more consumed.
  approaching,

  /// 90% or more consumed.
  critical,

  /// The whole amount is spent, but not overspent.
  atLimit,

  /// Spending has passed what was planned.
  exceeded;

  static const double approachingAt = 70;
  static const double criticalAt = 90;
  static const double limitAt = 100;

  /// Classifies a 0–unbounded consumption percentage.
  factory SpendingWarning.fromPercent(double percent) {
    if (percent > limitAt) return SpendingWarning.exceeded;
    if (percent >= limitAt) return SpendingWarning.atLimit;
    if (percent >= criticalAt) return SpendingWarning.critical;
    if (percent >= approachingAt) return SpendingWarning.approaching;
    return SpendingWarning.none;
  }

  bool get isExceeded => this == SpendingWarning.exceeded;

  /// True once the user should be told something.
  bool get shouldWarn => this != SpendingWarning.none;

  /// Past this point there is nothing left to spend.
  bool get isSpent => this == SpendingWarning.atLimit || isExceeded;

  String get label => switch (this) {
    SpendingWarning.none => 'On track',
    SpendingWarning.approaching => 'Over 70% used',
    SpendingWarning.critical => 'Over 90% used',
    SpendingWarning.atLimit => 'Fully spent',
    SpendingWarning.exceeded => 'Over plan',
  };

  /// Short form for a chip beside an amount.
  String get shortLabel => switch (this) {
    SpendingWarning.none => 'On track',
    SpendingWarning.approaching => '70%+',
    SpendingWarning.critical => '90%+',
    SpendingWarning.atLimit => 'Spent',
    SpendingWarning.exceeded => 'Over',
  };
}
