/// Low-level exceptions thrown by data sources.
///
/// These never cross into the domain layer — repositories catch them and
/// translate them into [Failure]s.
class AppException implements Exception {
  const AppException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

class ServerException extends AppException {
  const ServerException(super.message, {super.statusCode});
}

class UnauthorizedException extends AppException {
  const UnauthorizedException([super.message = 'Unauthorized'])
    : super(statusCode: 401);
}

class NetworkException extends AppException {
  const NetworkException([super.message = 'No internet connection']);
}

class CacheException extends AppException {
  const CacheException([super.message = 'Cache error']);
}

/// The stored database was written by a newer build of the app.
///
/// Deleting it would be silent data loss, so opening fails and the user is told
/// to update instead.
class DatabaseDowngradeException extends AppException {
  const DatabaseDowngradeException({
    required this.currentVersion,
    required this.supportedVersion,
  }) : super(
         'This data was saved by a newer version of the app. '
         'Update to open it.',
       );

  final int currentVersion;
  final int supportedVersion;
}

class ParseException extends AppException {
  const ParseException([super.message = 'Malformed response']);
}
