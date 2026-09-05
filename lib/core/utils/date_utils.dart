/// Date helpers shared by filters, reports and recurrence scheduling.
///
/// Dates are persisted as ISO-8601 **local** strings (no timezone suffix), so
/// lexicographic ordering in SQLite matches chronological ordering and a day
/// can be extracted with `substr(column, 1, 10)`.
class AppDate {
  const AppDate._();

  static const List<String> monthsShort = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static const List<String> monthsLong = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  static const List<String> weekdaysShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  /// Serialises for storage. Always strips any UTC marker.
  static String toDb(DateTime value) => value.toLocal().toIso8601String();

  static DateTime fromDb(String value) => DateTime.parse(value).toLocal();

  static DateTime? fromDbOrNull(String? value) =>
      (value == null || value.isEmpty) ? null : fromDb(value);

  /// `yyyy-MM-dd` — the form used for day grouping and range boundaries.
  static String toDayKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static DateTime startOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  static DateTime startOfWeek(DateTime value) {
    final day = startOfDay(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  static DateTime endOfWeek(DateTime value) =>
      endOfDay(startOfWeek(value).add(const Duration(days: 6)));

  static DateTime startOfMonth(DateTime value) =>
      DateTime(value.year, value.month);

  static DateTime endOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1, 0, 23, 59, 59, 999);

  static DateTime startOfYear(DateTime value) => DateTime(value.year);

  static DateTime endOfYear(DateTime value) =>
      DateTime(value.year, 12, 31, 23, 59, 59, 999);

  /// Calendar-aware month arithmetic that clamps overflowing days:
  /// 31 Jan + 1 month → 28/29 Feb, not 2/3 Mar.
  static DateTime addMonths(DateTime value, int months) {
    final targetMonth = value.month + months;
    final year = value.year + (targetMonth - 1) ~/ 12;
    final month = (targetMonth - 1) % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(
      year,
      month,
      value.day > lastDay ? lastDay : value.day,
      value.hour,
      value.minute,
    );
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime value) => isSameDay(value, DateTime.now());

  static int daysBetween(DateTime from, DateTime to) =>
      startOfDay(to).difference(startOfDay(from)).inDays;

  /// `05 Sep 2026`
  static String formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')} '
      '${monthsShort[value.month - 1]} ${value.year}';

  /// `05 Sep 2026, 2:30 PM`
  static String formatDateTime(DateTime value) =>
      '${formatDate(value)}, ${formatTime(value)}';

  static String formatTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour < 12 ? 'AM' : 'PM'}';
  }

  /// `Sep 2026`
  static String formatMonth(DateTime value) =>
      '${monthsShort[value.month - 1]} ${value.year}';

  /// Human labels for transaction list headers.
  static String formatRelativeDay(DateTime value) {
    final today = startOfDay(DateTime.now());
    final target = startOfDay(value);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return formatDate(value);
  }
}
