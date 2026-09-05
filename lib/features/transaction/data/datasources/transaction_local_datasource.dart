import '../../../../core/constants/storage_keys.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/services/storage_service.dart';
import '../models/transaction_model.dart';

abstract class TransactionLocalDataSource {
  Future<List<TransactionModel>> getCachedTransactions();
  Future<void> cacheTransactions(List<TransactionModel> transactions);
  Future<void> clearCache();
}

class TransactionLocalDataSourceImpl implements TransactionLocalDataSource {
  TransactionLocalDataSourceImpl(this._storage);

  final StorageService _storage;

  @override
  Future<List<TransactionModel>> getCachedTransactions() async {
    try {
      final raw = _storage.getJsonList(StorageKeys.cachedTransactions);
      if (raw == null) return const [];
      return raw
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const CacheException('Could not read cached transactions');
    }
  }

  @override
  Future<void> cacheTransactions(List<TransactionModel> transactions) {
    return _storage.setJsonList(
      StorageKeys.cachedTransactions,
      transactions.map((e) => e.toJson()).toList(),
    );
  }

  @override
  Future<void> clearCache() => _storage.remove(StorageKeys.cachedTransactions);
}
