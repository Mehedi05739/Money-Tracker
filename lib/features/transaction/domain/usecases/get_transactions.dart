import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class GetTransactions
    extends UseCase<List<TransactionEntity>, GetTransactionsParams> {
  GetTransactions(this._repository);

  final TransactionRepository _repository;

  @override
  Future<Result<List<TransactionEntity>>> call(
    GetTransactionsParams params,
  ) async {
    final result = await _repository.getTransactions(
      page: params.page,
      limit: params.limit,
    );

    // Business rule: newest first, regardless of what the source returned.
    return result.map(
      (items) => [...items]..sort((a, b) => b.date.compareTo(a.date)),
    );
  }
}

class GetTransactionsParams {
  const GetTransactionsParams({this.page = 1, this.limit = 20});

  final int page;
  final int limit;
}
