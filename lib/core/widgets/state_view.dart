import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../base/base_controller.dart';
import '../base/view_state.dart';
import 'app_empty_view.dart';
import 'app_error_view.dart';
import 'app_loader.dart';

/// Renders the right widget for a controller's [ViewState], so pages only
/// describe the loaded case.
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.controller,
    required this.builder,
    this.onRetry,
    this.emptyAction,
    this.loadingBuilder,
  });

  final BaseController controller;
  final WidgetBuilder builder;
  final VoidCallback? onRetry;
  final Widget? emptyAction;
  final WidgetBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => switch (controller.state) {
        IdleState() ||
        LoadingState() => loadingBuilder?.call(context) ?? const AppLoader(),
        EmptyState(:final message) => AppEmptyView(
          message: message,
          action: emptyAction,
        ),
        ErrorState(:final message) => AppErrorView(
          message: message,
          onRetry: onRetry,
        ),
        LoadedState() => builder(context),
      },
    );
  }
}
