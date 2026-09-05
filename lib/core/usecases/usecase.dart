import '../utils/result.dart';

/// One use case = one business action. Callable so it reads like a function:
/// `await getTransactions(NoParams())`.
abstract class UseCase<T, Params> {
  Future<Result<T>> call(Params params);
}

/// Synchronous variant, for pure business rules that need no I/O.
abstract class SyncUseCase<T, Params> {
  Result<T> call(Params params);
}

/// Params placeholder for use cases that take no input.
class NoParams {
  const NoParams();
}
