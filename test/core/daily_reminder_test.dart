import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker/core/services/daily_reminder.dart';

void main() {
  group('next occurrence', () {
    const tenPm = ReminderTime(22, 0);

    test('is today when the time has not passed', () {
      final next = tenPm.nextOccurrence(from: DateTime(2026, 9, 6, 18, 30));
      expect(next, DateTime(2026, 9, 6, 22, 0));
    });

    test('is tomorrow once the time has gone by', () {
      final next = tenPm.nextOccurrence(from: DateTime(2026, 9, 6, 23, 15));
      expect(next, DateTime(2026, 9, 7, 22, 0));
    });

    test('is tomorrow at exactly the reminder time', () {
      // Not "now": scheduling an instant that has already arrived makes some
      // Android versions fire it straight away.
      final next = tenPm.nextOccurrence(from: DateTime(2026, 9, 6, 22, 0));
      expect(next, DateTime(2026, 9, 7, 22, 0));
    });

    test('rolls over a month end', () {
      final next = tenPm.nextOccurrence(from: DateTime(2026, 9, 30, 23, 0));
      expect(next, DateTime(2026, 10, 1, 22, 0));
    });

    test('rolls over a year end', () {
      final next = tenPm.nextOccurrence(from: DateTime(2026, 12, 31, 23, 0));
      expect(next, DateTime(2027, 1, 1, 22, 0));
    });

    test('is always in the future, for every minute of the day', () {
      const time = ReminderTime(7, 45);
      for (var hour = 0; hour < 24; hour++) {
        final from = DateTime(2026, 9, 6, hour, 45);
        expect(
          time.nextOccurrence(from: from).isAfter(from),
          isTrue,
          reason: 'from ${from.hour}:45 the reminder was not in the future',
        );
      }
    });
  });

  group('stored time', () {
    test('falls back to 10pm when unset or unreadable', () {
      expect(ReminderTime.parse(null, null), ReminderTime.defaultTime);
      expect(ReminderTime.parse('nonsense', '0'), ReminderTime.defaultTime);
      expect(ReminderTime.defaultTime, const ReminderTime(22, 0));
    });

    test('clamps values outside a real clock', () {
      expect(ReminderTime.parse('99', '99'), const ReminderTime(23, 59));
      expect(ReminderTime.parse('-4', '-1'), const ReminderTime(0, 0));
    });

    test('reads back what was stored', () {
      expect(ReminderTime.parse('7', '5'), const ReminderTime(7, 5));
    });
  });

  group('time label', () {
    test('reads as a 12-hour clock', () {
      expect(const ReminderTime(22, 0).label, '10:00 PM');
      expect(const ReminderTime(9, 5).label, '9:05 AM');
      expect(const ReminderTime(0, 0).label, '12:00 AM');
      expect(const ReminderTime(12, 30).label, '12:30 PM');
    });
  });

  group('amount typed into the notification', () {
    test('accepts a plain number', () {
      expect(QuickAmount.parse('250'), 250);
      expect(QuickAmount.parse('12.50'), 12.5);
    });

    test('tolerates how people actually type money', () {
      expect(QuickAmount.parse(' 250 '), 250);
      expect(QuickAmount.parse('৳250'), 250);
      expect(QuickAmount.parse('\$1,250.75'), 1250.75);
      expect(QuickAmount.parse('250 taka'), 250);
    });

    test('rounds to two places rather than storing a long fraction', () {
      expect(QuickAmount.parse('10.129'), 10.13);
    });

    test('rejects anything that is not a usable amount', () {
      for (final input in [
        null,
        '',
        '   ',
        'abc',
        '0',
        '-50',
        '9999999999999',
      ]) {
        expect(
          QuickAmount.parse(input),
          isNull,
          reason: 'accepted ${input ?? 'null'}',
        );
      }
    });

    test('rejects rather than guesses at a half-typed number', () {
      expect(QuickAmount.parse('.'), isNull);
      expect(QuickAmount.parse('-'), isNull);
    });
  });
}
