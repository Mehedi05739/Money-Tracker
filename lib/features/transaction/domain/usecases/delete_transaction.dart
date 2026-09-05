import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../repositories/transaction_repository.dart';

class DeleteTransaction extends UseCase<void, String> {
  DeleteTransaction(this._repository);

  final TransactionRepository _repository;

  @override
  Future<Result<void>> call(String params) =>
      _repository.deleteTransaction(params);
}
