import 'package:flutter/widgets.dart';

/// The 4pt spacing scale.
///
/// Every gap and inset in the app comes from here. Before this existed the UI
/// used 13 different ad-hoc `SizedBox` values across 114 `EdgeInsets` literals,
/// which is the difference between a design and a collection of guesses.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double huge = 40;

  // ---- Semantic insets ----------------------------------------------------

  /// Horizontal padding for every screen's content column.
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: base);

  /// Standard card interior.
  static const EdgeInsets card = EdgeInsets.all(base);

  /// Denser card interior, for tiles in a grid.
  static const EdgeInsets cardCompact = EdgeInsets.all(md);

  /// Gap between cards in a row or column.
  static const double gutter = md;

  /// Gap between titled sections.
  static const double section = xl;

  /// Bottom padding so a floating action button never covers the last row.
  static const double fabClearance = 96;

  // ---- Const gaps ---------------------------------------------------------

  static const Widget gapXs = SizedBox(height: xs);
  static const Widget gapSm = SizedBox(height: sm);
  static const Widget gapMd = SizedBox(height: md);
  static const Widget gapBase = SizedBox(height: base);
  static const Widget gapLg = SizedBox(height: lg);
  static const Widget gapXl = SizedBox(height: xl);

  static const Widget hGapXs = SizedBox(width: xs);
  static const Widget hGapSm = SizedBox(width: sm);
  static const Widget hGapMd = SizedBox(width: md);
  static const Widget hGapBase = SizedBox(width: base);
}
