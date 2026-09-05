import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/result.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../datasources/transaction_local_datasource.dart';
import '../datasources/transaction_remote_datasource.dart';
import '../models/transaction_model.dart';

/// Decides where data comes from and turns exceptions into [Failure]s.
/// This is the only class that knows both data sources exist.
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({required this.remote, required this.local});

  final TransactionRemoteDataSource remote;
  final TransactionLocalDataSource local;

  @override
  Future<Result<List<TransactionEntity>>> getTransactions({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final items = await remote.getTransactions(page: page, limit: limit);
      if (page == 1) await local.cacheTransactions(items);
      return Result.success(items);
    } catch (error, stackTrace) {
      final failure = mapExceptionToFailure(error, stackTrace);

      // Offline: serve the last good page-1 snapshot instead of an error screen.
      if (failure is NetworkFailure && page == 1) {
        final cached = await _readCache();
        if (cached != null && cached.isNotEmpty) return Result.success(cached);
      }
      return Result.error(failure);
    }
  }

  @override
  Future<Result<TransactionEntity>> getTransactionById(String id) async {
    try {
      return Result.success(await remote.getTransactionById(id));
    } catch (error, stackTrace) {
      return Result.error(mapExceptionToFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<TransactionEntity>> addTransaction(
    TransactionEntity transaction,
  ) async {
    try {
      final created = await remote.addTransaction(
        TransactionModel.fromEntity(transaction),
      );
      return Result.success(created);
    } catch (error, stackTrace) {
      return Result.error(mapExceptionToFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  ) async {
    try {
      final updated = await remote.updateTransaction(
        TransactionModel.fromEntity(transaction),
      );
      return Result.success(updated);
    } catch (error, stackTrace) {
      return Result.error(mapExceptionToFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<void>> deleteTransaction(String id) async {
    try {
      await remote.deleteTransaction(id);
      return const Result.success(null);
    } catch (error, stackTrace) {
      return Result.error(mapExceptionToFailure(error, stackTrace));
    }
  }

  Future<List<TransactionEntity>?> _readCache() async {
    try {
      return await local.getCachedTransactions();
    } catch (_) {
      return null;
    }
  }
}
