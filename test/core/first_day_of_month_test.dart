import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/utils/date_range.dart';
import 'package:money_tracker/core/utils/date_utils.dart';

/// Someone paid on the 25th thinks in cycles that run 25th to 24th. The setting
/// only means something if every monthly boundary in the app moves with it, so
/// these tests check the shared helpers the budgets, plans and "this month"
/// range are all built on.
void main() {
  tearDown(() => AppDate.firstDayOfMonth = 1);

  group('default (the 1st)', () {
    test('is an ordinary calendar month', () {
      final start = AppDate.startOfMonth(DateTime(2026, 9, 17));
      final end = AppDate.endOfMonth(DateTime(2026, 9, 17));

      expect(start, DateTime(2026, 9, 1));
      expect(end.year, 2026);
      expect(end.month, 9);
      expect(end.day, 30);
    });
  });

  group('a custom first day', () {
    setUp(() => AppDate.firstDayOfMonth = 25);

    test('a date after the anchor belongs to the period that just opened', () {
      expect(
        AppDate.startOfMonth(DateTime(2026, 9, 26)),
        DateTime(2026, 9, 25),
      );
      expect(AppDate.endOfMonth(DateTime(2026, 9, 26)).day, 24);
      expect(AppDate.endOfMonth(DateTime(2026, 9, 26)).month, 10);
    });

    test('a date before the anchor still belongs to the previous period', () {
      expect(AppDate.startOfMonth(DateTime(2026, 9, 6)), DateTime(2026, 8, 25));
      expect(AppDate.endOfMonth(DateTime(2026, 9, 6)).day, 24);
      expect(AppDate.endOfMonth(DateTime(2026, 9, 6)).month, 9);
    });

    test('the anchor day itself opens the new period', () {
      expect(
        AppDate.startOfMonth(DateTime(2026, 9, 25)),
        DateTime(2026, 9, 25),
      );
    });

    test('periods are contiguous with no gap or overlap', () {
      final end = AppDate.endOfMonth(DateTime(2026, 9, 26));
      final nextStart = AppDate.startOfMonth(
        end.add(const Duration(milliseconds: 1)),
      );
      expect(nextStart, DateTime(2026, 10, 25));
    });

    test('crosses the year boundary', () {
      expect(
        AppDate.startOfMonth(DateTime(2027, 1, 3)),
        DateTime(2026, 12, 25),
      );
    });

    test('"This month" follows the setting', () {
      final range = DateRange.fromPreset(
        DateRangePreset.thisMonth,
        now: DateTime(2026, 9, 6, 12),
      );
      expect(range.start, DateTime(2026, 8, 25));
      expect(range.contains(DateTime(2026, 9, 6)), isTrue);
      expect(
        range.contains(DateTime(2026, 8, 24)),
        isFalse,
        reason: 'that day belongs to the period before',
      );
    });
  });

  test('is capped at 28 so the anchor exists in February', () {
    AppDate.firstDayOfMonth = 31;
    final start = AppDate.startOfMonth(DateTime(2026, 3, 5));
    expect(start.day, AppDate.maxFirstDayOfMonth);
    expect(start.month, 2, reason: 'February has a 28th in every year');
  });
}
