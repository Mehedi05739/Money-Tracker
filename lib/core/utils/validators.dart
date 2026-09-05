/// Form-level validation. Returns `null` when valid so it plugs straight into
/// `TextFormField.validator`.
///
/// Business-rule validation (budget limits, goal amounts) lives in the domain
/// services; this file only guards user input shape.
class Validators {
  const Validators._();

  /// Largest amount accepted in a single entry — guards against a mistyped
  /// keypad entry silently corrupting balances.
  static const double maxAmount = 999999999.99;

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? amount(String? value, {String field = 'Amount'}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '$field is required';

    final parsed = double.tryParse(raw.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid number';
    if (parsed.isNaN || parsed.isInfinite) return 'Enter a valid number';
    if (parsed <= 0) return '$field must be greater than zero';
    if (parsed > maxAmount) return '$field is too large';
    return null;
  }

  /// Same rules as [amount] but allows exactly zero.
  static String? nonNegativeAmount(String? value, {String field = 'Amount'}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '$field is required';

    final parsed = double.tryParse(raw.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid number';
    if (parsed.isNaN || parsed.isInfinite) return 'Enter a valid number';
    if (parsed < 0) return '$field cannot be negative';
    if (parsed > maxAmount) return '$field is too large';
    return null;
  }

  static String? name(String? value, {String field = 'Name', int min = 2}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '$field is required';
    if (raw.length < min) return '$field must be at least $min characters';
    if (raw.length > 60) return '$field must be under 60 characters';
    return null;
  }

  static String? percentage(String? value, {String field = 'Percentage'}) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return '$field is required';

    final parsed = int.tryParse(raw);
    if (parsed == null) return 'Enter a whole number';
    if (parsed < 1 || parsed > 100) return '$field must be between 1 and 100';
    return null;
  }

  /// Parses a user-entered amount, tolerating thousands separators.
  /// Returns `null` when the text is not a usable number.
  static double? parseAmount(String? value) {
    final parsed = double.tryParse((value ?? '').trim().replaceAll(',', ''));
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    return parsed;
  }

  /// Rounds to cents so repeated arithmetic cannot accumulate binary
  /// floating-point drift into a visible balance error.
  static double normalizeAmount(double value) =>
      (value * 100).roundToDouble() / 100;
}
