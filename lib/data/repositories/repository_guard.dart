import 'package:sqflite/sqflite.dart';

import '../../core/errors/failure_mapper.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/result.dart';

/// Runs a data-layer call and converts anything it throws into a [Failure].
///
/// This is the single boundary where sqflite exceptions stop: nothing above the
/// repositories ever sees a `DatabaseException`.
Future<Result<T>> guard<T>(
  Future<T> Function() action, {
  String? context,
}) async {
  try {
    return Result.success(await action());
  } on DatabaseException catch (error, stackTrace) {
    // Log the failure shape, never the row values — they are financial data.
    AppLogger.e(
      'Database error${context == null ? '' : ' in $context'}',
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
    return Result.error(_mapDatabaseException(error));
  } on StateError catch (error, stackTrace) {
    AppLogger.e('Invalid state', error: error, stackTrace: stackTrace);
    return const Result.error(CacheFailure('The database is not ready'));
  } catch (error, stackTrace) {
    return Result.error(mapExceptionToFailure(error, stackTrace));
  }
}

Failure _mapDatabaseException(DatabaseException error) {
  if (error.isUniqueConstraintError()) {
    return const ValidationFailure('That entry already exists');
  }
  if (error.isNotNullConstraintError()) {
    return const ValidationFailure('A required field was missing');
  }
  if (error.isDatabaseClosedError()) {
    return const CacheFailure('The database was closed unexpectedly');
  }
  // CHECK and FOREIGN KEY violations land here — both mean the write was
  // rejected by a rule the user can act on.
  return const ValidationFailure('That change is not allowed');
}

/// Wraps a lookup that must find a row.
Future<Result<T>> guardFound<T>(
  Future<T?> Function() action, {
  String notFoundMessage = 'Not found',
  String? context,
}) async {
  final result = await guard(action, context: context);
  return result.fold(
    onSuccess: (value) => value == null
        ? Result<T>.error(ValidationFailure(notFoundMessage))
        : Result<T>.success(value),
    onError: Result<T>.error,
  );
}
