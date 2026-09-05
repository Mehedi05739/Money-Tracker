import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/result.dart';
import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class AddTransaction extends UseCase<TransactionEntity, TransactionEntity> {
  AddTransaction(this._repository);

  final TransactionRepository _repository;

  @override
  Future<Result<TransactionEntity>> call(TransactionEntity params) async {
    final errors = <String, String>{};
    if (params.title.trim().isEmpty) errors['title'] = 'Title is required';
    if (params.amount <= 0) errors['amount'] = 'Amount must be greater than 0';

    if (errors.isNotEmpty) {
      return Result.error(
        ValidationFailure('Please fix the highlighted fields',
            fieldErrors: errors),
      );
    }

    return _repository.addTransaction(params);
  }
}
