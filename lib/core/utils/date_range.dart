import 'date_utils.dart';

/// Named ranges offered by the dashboard and report filters.
enum DateRangePreset {
  today,
  yesterday,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  allTime,

  /// Rolling windows ending today, used by the report filters. Distinct from
  /// the calendar presets above: "30 days" is the last thirty days wherever
  /// today falls, where "This month" restarts on the 1st.
  last7Days,
  last30Days,
  last3Months,
  last6Months,
  lastYear,

  custom;

  String get label => switch (this) {
    DateRangePreset.today => 'Today',
    DateRangePreset.yesterday => 'Yesterday',
    DateRangePreset.thisWeek => 'This week',
    DateRangePreset.thisMonth => 'This month',
    DateRangePreset.lastMonth => 'Last month',
    DateRangePreset.thisYear => 'This year',
    DateRangePreset.allTime => 'All time',
    DateRangePreset.last7Days => '7 days',
    DateRangePreset.last30Days => '30 days',
    DateRangePreset.last3Months => '3 months',
    DateRangePreset.last6Months => '6 months',
    DateRangePreset.lastYear => '1 year',
    DateRangePreset.custom => 'Custom',
  };
}

/// An inclusive [start]–[end] window plus the preset it came from.
class DateRange {
  const DateRange({
    required this.start,
    required this.end,
    this.preset = DateRangePreset.custom,
  });

  factory DateRange.fromPreset(DateRangePreset preset, {DateTime? now}) {
    final today = now ?? DateTime.now();

    return switch (preset) {
      DateRangePreset.today => DateRange(
        start: AppDate.startOfDay(today),
        end: AppDate.endOfDay(today),
        preset: preset,
      ),
      DateRangePreset.yesterday => () {
        final day = today.subtract(const Duration(days: 1));
        return DateRange(
          start: AppDate.startOfDay(day),
          end: AppDate.endOfDay(day),
          preset: preset,
        );
      }(),
      DateRangePreset.thisWeek => DateRange(
        start: AppDate.startOfWeek(today),
        end: AppDate.endOfWeek(today),
        preset: preset,
      ),
      DateRangePreset.thisMonth => DateRange(
        start: AppDate.startOfMonth(today),
        end: AppDate.endOfMonth(today),
        preset: preset,
      ),
      DateRangePreset.lastMonth => DateRange(
        start: AppDate.startOfMonth(AppDate.addMonths(today, -1)),
        end: AppDate.endOfMonth(AppDate.addMonths(today, -1)),
        preset: preset,
      ),
      DateRangePreset.thisYear => DateRange(
        start: AppDate.startOfYear(today),
        end: AppDate.endOfYear(today),
        preset: preset,
      ),
      DateRangePreset.allTime => DateRange(
        start: DateTime(2000),
        end: AppDate.endOfDay(today),
        preset: preset,
      ),
      DateRangePreset.last7Days => _rollingDays(today, 7, preset),
      DateRangePreset.last30Days => _rollingDays(today, 30, preset),
      DateRangePreset.last3Months => _rollingMonths(today, 3, preset),
      DateRangePreset.last6Months => _rollingMonths(today, 6, preset),
      DateRangePreset.lastYear => _rollingMonths(today, 12, preset),
      DateRangePreset.custom => DateRange(
        start: AppDate.startOfMonth(today),
        end: AppDate.endOfMonth(today),
        preset: preset,
      ),
    };
  }

  /// The window of exactly [days] days ending today, today included — so
  /// "7 days" spans seven days rather than eight.
  static DateRange _rollingDays(
    DateTime today,
    int days,
    DateRangePreset preset,
  ) => DateRange(
    start: AppDate.startOfDay(today.subtract(Duration(days: days - 1))),
    end: AppDate.endOfDay(today),
    preset: preset,
  );

  /// The window of exactly [months] months ending today. The start is nudged a
  /// day forward for the same reason as [_rollingDays]: the day [months] months
  /// ago belongs to the preceding window, not this one.
  static DateRange _rollingMonths(
    DateTime today,
    int months,
    DateRangePreset preset,
  ) => DateRange(
    start: AppDate.startOfDay(
      AppDate.addMonths(today, -months).add(const Duration(days: 1)),
    ),
    end: AppDate.endOfDay(today),
    preset: preset,
  );

  factory DateRange.custom(DateTime start, DateTime end) => DateRange(
    start: AppDate.startOfDay(start),
    end: AppDate.endOfDay(end),
    preset: DateRangePreset.custom,
  );

  final DateTime start;
  final DateTime end;
  final DateRangePreset preset;

  String get startDb => AppDate.toDb(start);
  String get endDb => AppDate.toDb(end);

  int get dayCount => AppDate.daysBetween(start, end) + 1;

  /// Days elapsed so far, clamped to the range — used for pace calculations
  /// so a budget is not judged against a month that has barely started.
  int get elapsedDays {
    final now = DateTime.now();
    if (now.isBefore(start)) return 0;
    if (now.isAfter(end)) return dayCount;
    return AppDate.daysBetween(start, now) + 1;
  }

  bool contains(DateTime value) =>
      !value.isBefore(start) && !value.isAfter(end);

  /// The equivalent window immediately before this one, for period-over-period
  /// comparisons.
  DateRange get previous {
    final length = Duration(days: dayCount);
    return DateRange(
      start: start.subtract(length),
      end: AppDate.endOfDay(start.subtract(const Duration(days: 1))),
    );
  }

  String get label {
    if (preset != DateRangePreset.custom) return preset.label;
    if (AppDate.isSameDay(start, end)) return AppDate.formatDate(start);
    return '${AppDate.formatDate(start)} – ${AppDate.formatDate(end)}';
  }

  @override
  bool operator ==(Object other) =>
      other is DateRange &&
      other.start == start &&
      other.end == end &&
      other.preset == preset;

  @override
  int get hashCode => Object.hash(start, end, preset);
}
