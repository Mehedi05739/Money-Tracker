import '../utils/logger.dart';
import 'exceptions.dart';
import 'failures.dart';

/// The single place where data-layer exceptions become domain failures.
/// Repositories call this in their `catch` blocks so the mapping stays uniform.
Failure mapExceptionToFailure(Object error, [StackTrace? stackTrace]) {
  AppLogger.e('Repository error', error: error, stackTrace: stackTrace);

  return switch (error) {
    UnauthorizedException(:final message) => UnauthorizedFailure(message),
    NetworkException(:final message) => NetworkFailure(message),
    CacheException(:final message) => CacheFailure(message),
    ParseException(:final message) => ServerFailure(message),
    ServerException(:final message, :final statusCode) =>
      ServerFailure(message, statusCode: statusCode),
    AppException(:final message, :final statusCode) =>
      ServerFailure(message, statusCode: statusCode),
    _ => const UnknownFailure(),
  };
}
