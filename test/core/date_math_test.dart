import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/core/utils/date_utils.dart';

/// `addMonths` used to divide with `~/`, which truncates toward zero rather
/// than flooring. Any backwards step across January kept the year and wrapped
/// the month forward, so "last month" viewed in January resolved to December of
/// the year *ahead* — and every rolling report window inherited it.
void main() {
  group('addMonths', () {
    test('steps back across January into the previous year', () {
      expect(
        AppDate.addMonths(DateTime(2026, 1, 15), -1),
        DateTime(2025, 12, 15),
      );
      expect(
        AppDate.addMonths(DateTime(2026, 2, 10), -3),
        DateTime(2025, 11, 10),
      );
    });

    test('steps back a whole year', () {
      expect(
        AppDate.addMonths(DateTime(2026, 9, 6), -12),
        DateTime(2025, 9, 6),
      );
    });

    test('still steps forward correctly', () {
      expect(AppDate.addMonths(DateTime(2026, 9, 6), 6), DateTime(2027, 3, 6));
      expect(AppDate.addMonths(DateTime(2026, 12, 6), 1), DateTime(2027, 1, 6));
    });

    test('still clamps a day that overflows the target month', () {
      expect(
        AppDate.addMonths(DateTime(2026, 3, 31), -1),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('rolling report windows', () {
    test('start before they end, in every month of the year', () {
      for (var month = 1; month <= 12; month++) {
        final now = DateTime(2026, month, 15, 12);
        for (final preset in const [
          DateRangePreset.last7Days,
          DateRangePreset.last30Days,
          DateRangePreset.last3Months,
          DateRangePreset.last6Months,
          DateRangePreset.lastYear,
        ]) {
          final range = DateRange.fromPreset(preset, now: now);
          expect(
            range.start.isBefore(range.end),
            isTrue,
            reason: '${preset.label} in month $month ran backwards',
          );
          expect(
            range.contains(now),
            isTrue,
            reason: '${preset.label} in month $month excluded today',
          );
        }
      }
    });

    test('a one-year window spans a year', () {
      final range = DateRange.fromPreset(
        DateRangePreset.lastYear,
        now: DateTime(2026, 9, 6, 12),
      );
      expect(range.start.year, 2025);
      expect(range.start.month, 9);
      expect(range.dayCount, inInclusiveRange(365, 366));
    });

    test('"last month" in January is the previous December', () {
      final range = DateRange.fromPreset(
        DateRangePreset.lastMonth,
        now: DateTime(2026, 1, 20, 12),
      );
      expect(range.start.year, 2025);
      expect(range.start.month, 12);
      expect(range.end.month, 12);
    });
  });
}
