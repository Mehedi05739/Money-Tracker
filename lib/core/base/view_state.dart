import '../errors/failures.dart';

/// What a screen is currently showing. Controllers expose this instead of
/// juggling separate `isLoading` / `errorMessage` / `isEmpty` flags.
sealed class ViewState {
  const ViewState();
}

class IdleState extends ViewState {
  const IdleState();
}

class LoadingState extends ViewState {
  const LoadingState();
}

class LoadedState extends ViewState {
  const LoadedState();
}

class EmptyState extends ViewState {
  const EmptyState([this.message = 'Nothing here yet']);
  final String message;
}

class ErrorState extends ViewState {
  const ErrorState(this.failure);
  final Failure failure;

  String get message => failure.message;
}
