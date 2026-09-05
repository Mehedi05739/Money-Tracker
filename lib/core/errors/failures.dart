/// Domain-level errors. Everything the UI is allowed to know about a problem.
sealed class Failure {
  const Failure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => '$runtimeType: $message';
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Session expired'])
    : super(statusCode: 401);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Could not read local data']);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message, {this.fieldErrors = const {}});

  final Map<String, String> fieldErrors;
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong']);
}
