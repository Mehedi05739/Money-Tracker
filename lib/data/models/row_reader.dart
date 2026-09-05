import '../../core/utils/date_utils.dart';

/// Typed access to a sqflite row.
///
/// SQLite is dynamically typed: a REAL column can come back as `int` when the
/// stored value happened to be whole, so a bare `as double` cast is unsafe.
/// Every mapper reads through these helpers instead.
extension RowReader on Map<String, Object?> {
  int readInt(String key) => (this[key]! as num).toInt();

  int? readIntOrNull(String key) => (this[key] as num?)?.toInt();

  double readDouble(String key) => (this[key]! as num).toDouble();

  double readDoubleOr(String key, [double fallback = 0]) =>
      (this[key] as num?)?.toDouble() ?? fallback;

  String readString(String key) => this[key]! as String;

  String? readStringOrNull(String key) {
    final value = this[key] as String?;
    return (value == null || value.isEmpty) ? null : value;
  }

  bool readBool(String key) => (this[key] as num?)?.toInt() == 1;

  DateTime readDate(String key) => AppDate.fromDb(readString(key));

  DateTime? readDateOrNull(String key) =>
      AppDate.fromDbOrNull(this[key] as String?);
}

/// SQLite has no boolean type; 0/1 integers are the convention.
int asDbBool(bool value) => value ? 1 : 0;
