import 'package:flutter/material.dart';

import '../../utils/formatters.dart';

/// One point on a [LineTrendChart].
class LinePoint {
  const LinePoint({required this.label, required this.value});

  final String label;
  final double value;
}

/// A single-series line, drawn straight onto a canvas.
///
/// Deliberately plain: no gridlines, no tooltips, no growth animation. The
/// series it carries — a running savings balance — is read at a glance, and
/// chrome would cost more attention than it returns.
///
/// Sizes itself to the width it is given, so it works from a small phone to a
/// tablet without a breakpoint.
class LineTrendChart extends StatelessWidget {
  const LineTrendChart({
    super.key,
    required this.points,
    required this.color,
    this.height = 160,
    this.emptyMessage = 'No data for this period',
  });

  final List<LinePoint> points;
  final Color color;
  final double height;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    // Two points are the minimum that can describe a direction.
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyMessage,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      );
    }

    final values = points.map((point) => point.value).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);

    // Always keep zero on the axis: a savings line that never touches its own
    // baseline hides whether the user is actually ahead.
    final top = maxValue > 0 ? maxValue : 0.0;
    final bottom = minValue < 0 ? minValue : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              Money.compact(top),
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const Spacer(),
            Text(
              'Now ${Money.compact(values.last)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          width: double.infinity,
          child: Semantics(
            label:
                'Savings trend from ${Money.format(values.first)} '
                'to ${Money.format(values.last)}',
            child: CustomPaint(
              painter: _LinePainter(
                values: values,
                top: top,
                bottom: bottom,
                color: color,
                baselineColor: theme.dividerColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              points.first.label,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
            const Spacer(),
            Text(
              points.last.label,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  const _LinePainter({
    required this.values,
    required this.top,
    required this.bottom,
    required this.color,
    required this.baselineColor,
  });

  final List<double> values;
  final double top;
  final double bottom;
  final Color color;
  final Color baselineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final span = top - bottom;
    // A perfectly flat series would divide by zero; draw it down the middle.
    double y(double value) => span <= 0
        ? size.height / 2
        : size.height - ((value - bottom) / span) * size.height;
    double x(int index) => (index / (values.length - 1)) * size.width;

    final zeroY = y(0);
    canvas.drawLine(
      Offset(0, zeroY),
      Offset(size.width, zeroY),
      Paint()
        ..color = baselineColor
        ..strokeWidth = 1,
    );

    final line = Path()..moveTo(x(0), y(values.first));
    for (var i = 1; i < values.length; i++) {
      line.lineTo(x(i), y(values[i]));
    }

    // Close the path back along the zero line so the fill reads as "area
    // above/below break-even" rather than as an arbitrary wedge.
    final fill = Path.from(line)
      ..lineTo(x(values.length - 1), zeroY)
      ..lineTo(x(0), zeroY)
      ..close();

    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // A single marker on the latest value, the only point worth pinpointing.
    canvas.drawCircle(
      Offset(x(values.length - 1), y(values.last)),
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values ||
      old.top != top ||
      old.bottom != bottom ||
      old.color != color ||
      old.baselineColor != baselineColor;
}
