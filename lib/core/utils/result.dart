import '../errors/failures.dart';

/// A success-or-failure wrapper, so repositories and use cases can return
/// errors as values instead of throwing across layers.
///
/// Kept dependency-free on purpose (no `dartz`) — pattern matching on the
/// sealed type covers everything we need:
///
/// ```dart
/// switch (result) {
///   case Success(:final data): ...
///   case Failed(:final failure): ...
/// }
/// ```
sealed class Result<T> {
  const Result();

  const factory Result.success(T data) = Success<T>;
  const factory Result.error(Failure failure) = Failed<T>;

  bool get isSuccess => this is Success<T>;
  bool get isError => this is Failed<T>;

  /// The value on success, `null` otherwise.
  T? get dataOrNull => switch (this) {
    Success<T>(:final data) => data,
    Failed<T>() => null,
  };

  /// The failure on error, `null` otherwise.
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Failed<T>(:final failure) => failure,
  };

  /// Collapses both branches into a single value.
  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(Failure failure) onError,
  }) => switch (this) {
    Success<T>(:final data) => onSuccess(data),
    Failed<T>(:final failure) => onError(failure),
  };

  /// Transforms the success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T data) transform) => switch (this) {
    Success<T>(:final data) => Success<R>(transform(data)),
    Failed<T>(:final failure) => Failed<R>(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

/// Named `Failed` rather than `Error` so it never collides with
/// `dart:core.Error` — a bare `case Error(...)` in a file that forgot to import
/// this library would silently match the wrong type.
final class Failed<T> extends Result<T> {
  const Failed(this.failure);
  final Failure failure;
}
