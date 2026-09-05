import '../../core/utils/result.dart';

/// Key–value store backed by the `app_settings` table.
///
/// Only preferences belong here — never credentials or anything sensitive.
abstract class SettingsRepository {
  Future<Result<Map<String, String>>> getAll();
  Future<Result<String?>> get(String key);
  Future<Result<void>> set(String key, String value);
  Future<Result<void>> remove(String key);
}
