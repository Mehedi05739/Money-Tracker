import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';

/// Centres and caps the main content column.
///
/// Without this, a financial row on a tablet puts its label at the far left and
/// its amount at the far right, and the eye loses the connection between them.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    // Below the cap there is nothing to do, so phones pay no layout cost.
    if (MediaQuery.sizeOf(context).width <= maxWidth) return child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A sliver-friendly version of [ContentWidth] for `CustomScrollView` bodies.
class SliverContentWidth extends StatelessWidget {
  const SliverContentWidth({
    super.key,
    required this.sliver,
    this.maxWidth = AppBreakpoints.contentMaxWidth,
  });

  final Widget sliver;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= maxWidth) return sliver;

    final inset = (width - maxWidth) / 2;
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      sliver: sliver,
    );
  }
}
