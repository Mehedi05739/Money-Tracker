import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One arc of the donut.
class DonutSlice {
  const DonutSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Category-share donut with a centred caption.
///
/// Drawn directly with a painter rather than pulling in a charting package:
/// the shape is simple and this keeps full control of theming and dependencies.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.size = 168,
    this.strokeWidth = 26,
    this.centerTitle,
    this.centerSubtitle,
  });

  final List<DonutSlice> slices;
  final double size;
  final double strokeWidth;
  final String? centerTitle;
  final String? centerSubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.value);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => CustomPaint(
          painter: _DonutPainter(
            slices: total <= 0 ? const [] : slices,
            total: total,
            strokeWidth: strokeWidth,
            progress: progress,
            emptyColor: theme.progressIndicatorTheme.linearTrackColor ??
                theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (centerTitle != null)
                  Text(
                    centerTitle!,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                if (centerSubtitle != null)
                  Text(
                    centerSubtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.total,
    required this.strokeWidth,
    required this.progress,
    required this.emptyColor,
  });

  final List<DonutSlice> slices;
  final double total;
  final double strokeWidth;
  final double progress;
  final Color emptyColor;

  static const double _startAngle = -math.pi / 2;
  static const double _gap = 0.02;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    if (slices.isEmpty || total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = emptyColor);
      return;
    }

    var angle = _startAngle;
    for (final slice in slices) {
      final sweep = (slice.value / total) * math.pi * 2 * progress;
      if (sweep <= 0) continue;

      canvas.drawArc(
        rect,
        angle,
        // Leave a hairline gap between arcs, but never invert a tiny slice.
        math.max(sweep - _gap, sweep * 0.6),
        false,
        paint..color = slice.color,
      );
      angle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.total != total ||
      oldDelegate.slices.length != slices.length;
}
