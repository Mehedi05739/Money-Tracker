/// When the daily "record today's spending" reminder fires.
///
/// A value object rather than two loose ints so the default, the clamping and
/// the next-occurrence arithmetic all live in one place — the scheduler, the
/// settings screen and the tests share exactly one definition of "10pm".
class ReminderTime {
  const ReminderTime(this.hour, this.minute);

  /// Late enough that the day's spending has happened, early enough that the
  /// user is still awake to act on it.
  static const ReminderTime defaultTime = ReminderTime(22, 0);

  final int hour;
  final int minute;

  /// Reads a stored pair, falling back to the default rather than throwing —
  /// a corrupt preference should not stop reminders working.
  factory ReminderTime.parse(String? hour, String? minute) {
    final h = int.tryParse(hour ?? '');
    final m = int.tryParse(minute ?? '');
    if (h == null || m == null) return defaultTime;
    return ReminderTime(h.clamp(0, 23), m.clamp(0, 59));
  }

  /// The next time this reminder is due, strictly in the future.
  ///
  /// Today's slot if it has not passed, otherwise tomorrow's. Strictly in the
  /// future matters: scheduling for an instant that has already gone by makes
  /// some Android versions fire immediately, which would nag the user the
  /// moment they picked a time earlier than now.
  DateTime nextOccurrence({DateTime? from}) {
    final now = from ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isAfter(now) ? today : today.add(const Duration(days: 1));
  }

  /// 12-hour label for display, e.g. "10:00 PM".
  String get label {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

/// Reads an amount typed into the notification's reply box.
///
/// Deliberately forgiving about how people actually type money — a currency
/// symbol, a comma, stray spaces — but strict about the result: anything that
/// is not a positive, sane number is rejected rather than guessed at, because
/// the alternative is silently recording the wrong figure in someone's ledger.
class QuickAmount {
  const QuickAmount._();

  /// Matches the app's own validation ceiling.
  static const double maxAmount = 999999999;

  static double? parse(String? input) {
    if (input == null) return null;

    // Keep digits, separators and a leading minus; drop symbols and spaces.
    final cleaned = input.replaceAll(RegExp(r'[^0-9.,\-]'), '').trim();
    if (cleaned.isEmpty) return null;

    // A comma is a thousands separator here; the app's own fields use a dot.
    final normalised = cleaned.replaceAll(',', '');
    final value = double.tryParse(normalised);

    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value <= 0 || value > maxAmount) return null;

    // Money has two decimal places; a longer reply is a typo, not precision.
    return double.parse(value.toStringAsFixed(2));
  }
}

/// Why switching the daily reminder on succeeded or failed.
///
/// A bare bool made every failure look the same, so the toggle flipped back
/// with a message that did not say which step went wrong — or, worse, said
/// permission was refused when it had just been granted.
enum ReminderOutcome {
  /// Scheduled, and it will arrive at the minute asked for.
  scheduledExactly,

  /// Scheduled, but the OS withholds exact alarms, so it may arrive late.
  scheduledInexactly,

  /// The user has not allowed notifications.
  permissionDenied,

  /// Permission is held but the OS refused the schedule.
  scheduleFailed,

  /// Turned off.
  disabled;

  bool get isOn => this == scheduledExactly || this == scheduledInexactly;
}

/// How precisely the OS will deliver a scheduled reminder.
enum DeliveryPrecision {
  /// Fires on the minute asked for.
  exact,

  /// Batched by the OS, so it may arrive minutes late.
  approximate,

  /// Could not be scheduled at all.
  none,
}

/// What the operating system currently permits, read fresh from the device.
///
/// Every field is something a user can change outside the app, and each one
/// independently stops reminders arriving. Reading them together is what lets
/// Settings say *which* is wrong instead of "notifications are not working".
class NotificationDiagnostics {
  const NotificationDiagnostics({
    required this.pluginReady,
    required this.permissionGranted,
    required this.channelEnabled,
    required this.canScheduleExactly,
    required this.timeZone,
    required this.offsetMatchesDevice,
  });

  const NotificationDiagnostics.unavailable()
    : pluginReady = false,
      permissionGranted = false,
      channelEnabled = false,
      canScheduleExactly = false,
      timeZone = 'unknown',
      offsetMatchesDevice = false;

  /// Whether the notification plugin initialised at all.
  final bool pluginReady;

  /// Whether the OS lets this app post notifications.
  final bool permissionGranted;

  /// Whether the reminder's own notification channel is switched on.
  ///
  /// Separate from [permissionGranted] because they fail independently and
  /// look identical from inside the app: Android offers to "turn off
  /// notifications" whenever one is dismissed a few times, and a user who
  /// accepts blocks the channel while app-level permission stays granted.
  /// Posting then reports success and nothing appears — silently, forever.
  final bool channelEnabled;

  /// Whether "Alarms & reminders" is allowed. Android 14 and later withhold
  /// this by default from apps targeting API 34+, which is why a reminder can
  /// be scheduled yet arrive late.
  final bool canScheduleExactly;

  final String timeZone;

  /// Whether the resolved time zone agrees with the device clock's offset. If
  /// it does not, a daily repeat drifts once daylight saving changes.
  final bool offsetMatchesDevice;

  /// Reminders can be delivered at all.
  bool get canDeliver => pluginReady && permissionGranted && channelEnabled;

  /// Everything is as good as it gets on this device.
  bool get isHealthy => canDeliver && canScheduleExactly && offsetMatchesDevice;
}
