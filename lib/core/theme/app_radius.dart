import 'package:flutter/widgets.dart';

/// Corner radii.
///
/// Seven steps replacing the eleven one-off values the UI used to hardcode.
/// Larger surfaces take larger radii, so a sheet never looks like a chip.
class AppRadius {
  const AppRadius._();

  /// Chips, small badges.
  static const double xs = 8;

  /// Inline pills, segment buttons.
  static const double sm = 10;

  /// Progress tracks, small tiles.
  static const double md = 12;

  /// Inputs and buttons.
  static const double lg = 14;

  /// Cards.
  static const double xl = 18;

  /// Hero surfaces and dialogs.
  static const double xxl = 22;

  /// Fully rounded.
  static const double pill = 999;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));

  /// Bottom sheets: rounded top only.
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(xxl),
  );
}
