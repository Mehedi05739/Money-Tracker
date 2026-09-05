import 'package:flutter/animation.dart';

/// Motion tokens.
///
/// Animation in a finance app should confirm that something happened, never
/// entertain. Anything above [slow] is too slow to feel responsive when the
/// user is recording an expense in a shop queue.
class AppMotion {
  const AppMotion._();

  /// State flips: selection, toggles, colour changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// The default: bars filling, sheets settling, content swapping.
  static const Duration base = Duration(milliseconds: 220);

  /// Charts drawing themselves on first paint.
  static const Duration slow = Duration(milliseconds: 400);

  /// Decelerating curve for things entering the screen.
  static const Curve enter = Curves.easeOutCubic;

  /// Symmetric curve for things changing in place.
  static const Curve standard = Curves.easeInOut;

  /// Accelerating curve for things leaving.
  static const Curve exit = Curves.easeInCubic;
}
