import 'dart:convert';

import 'package:get/get.dart';

/// Key–value persistence contract.
///
/// Feature code depends on this interface only, so swapping the backing store
/// (`get_storage`, `shared_preferences`, `flutter_secure_storage`) is a one-file
/// change in [di/dependency_injection.dart].
abstract class StorageService {
  Future<void> init();

  String? getString(String key);
  Future<void> setString(String key, String value);

  bool? getBool(String key);
  Future<void> setBool(String key, bool value);

  int? getInt(String key);
  Future<void> setInt(String key, int value);

  Map<String, dynamic>? getJson(String key);
  Future<void> setJson(String key, Map<String, dynamic> value);

  List<dynamic>? getJsonList(String key);
  Future<void> setJsonList(String key, List<dynamic> value);

  Future<void> remove(String key);
  Future<void> clear();
}

/// Default in-memory implementation so the app runs out of the box.
///
/// Replace with a disk-backed implementation when persistence is needed —
/// nothing outside this file has to change.
class InMemoryStorageService extends GetxService implements StorageService {
  final Map<String, Object> _box = <String, Object>{};

  @override
  Future<void> init() async {}

  @override
  String? getString(String key) => _box[key] as String?;

  @override
  Future<void> setString(String key, String value) async => _box[key] = value;

  @override
  bool? getBool(String key) => _box[key] as bool?;

  @override
  Future<void> setBool(String key, bool value) async => _box[key] = value;

  @override
  int? getInt(String key) => _box[key] as int?;

  @override
  Future<void> setInt(String key, int value) async => _box[key] = value;

  @override
  Map<String, dynamic>? getJson(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) =>
      setString(key, jsonEncode(value));

  @override
  List<dynamic>? getJsonList(String key) {
    final raw = getString(key);
    if (raw == null) return null;
    return jsonDecode(raw) as List<dynamic>;
  }

  @override
  Future<void> setJsonList(String key, List<dynamic> value) =>
      setString(key, jsonEncode(value));

  @override
  Future<void> remove(String key) async => _box.remove(key);

  @override
  Future<void> clear() async => _box.clear();
}
