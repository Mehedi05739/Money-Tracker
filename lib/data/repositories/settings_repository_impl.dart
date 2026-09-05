import '../../core/utils/result.dart';
import '../../domain/repositories/settings_repository.dart';
import '../local/daos/settings_dao.dart';
import 'repository_guard.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl(this._dao);

  final SettingsDao _dao;

  @override
  Future<Result<Map<String, String>>> getAll() =>
      guard(_dao.findAll, context: 'getSettings');

  @override
  Future<Result<String?>> get(String key) =>
      guard(() => _dao.find(key), context: 'getSetting');

  @override
  Future<Result<void>> set(String key, String value) =>
      guard(() => _dao.put(key, value), context: 'setSetting');

  @override
  Future<Result<void>> remove(String key) =>
      guard(() => _dao.remove(key), context: 'removeSetting');
}
