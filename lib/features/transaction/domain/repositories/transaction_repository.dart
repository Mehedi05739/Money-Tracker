import '../../../../core/utils/result.dart';
import '../entities/transaction_entity.dart';

/// Contract owned by the domain layer and implemented in `data/`.
/// This is the dependency inversion that keeps the domain testable.
abstract class TransactionRepository {
  Future<Result<List<TransactionEntity>>> getTransactions({
    int page = 1,
    int limit = 20,
  });

  Future<Result<TransactionEntity>> getTransactionById(String id);

  Future<Result<TransactionEntity>> addTransaction(TransactionEntity transaction);

  Future<Result<TransactionEntity>> updateTransaction(
    TransactionEntity transaction,
  );

  Future<Result<void>> deleteTransaction(String id);
}
