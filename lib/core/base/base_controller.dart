import 'package:get/get.dart';

import '../errors/failures.dart';
import '../utils/result.dart';
import 'view_state.dart';

/// Shared controller plumbing: one observable [ViewState] plus a helper that
/// runs a use case and moves the state through loading → loaded/error.
abstract class BaseController extends GetxController {
  final Rx<ViewState> _state = Rx<ViewState>(const IdleState());

  ViewState get state => _state.value;
  bool get isLoading => _state.value is LoadingState;
  bool get hasError => _state.value is ErrorState;

  void setIdle() => _state.value = const IdleState();
  void setLoading() => _state.value = const LoadingState();
  void setLoaded() => _state.value = const LoadedState();
  void setEmpty([String message = 'Nothing here yet']) =>
      _state.value = EmptyState(message);
  void setError(Failure failure) => _state.value = ErrorState(failure);

  /// Runs [task], flipping view state around it.
  ///
  /// Pass `showLoader: false` for pull-to-refresh and other background work
  /// that should not blank out content already on screen.
  Future<T?> execute<T>(
    Future<Result<T>> Function() task, {
    bool showLoader = true,
    void Function(T data)? onSuccess,
    void Function(Failure failure)? onError,
  }) async {
    if (showLoader) setLoading();

    final result = await task();

    return result.fold(
      onSuccess: (data) {
        setLoaded();
        onSuccess?.call(data);
        return data;
      },
      onError: (failure) {
        if (onError != null) {
          onError(failure);
        } else {
          setError(failure);
        }
        return null;
      },
    );
  }
}
