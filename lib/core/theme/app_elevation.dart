import 'package:flutter/material.dart';

/// Depth tokens.
///
/// Finance UIs read as trustworthy when surfaces are calm, so light mode
/// separates cards with a hairline border and only the faintest lift. Dark mode
/// cannot rely on shadows at all — black on black is invisible — so it
/// separates surfaces by raising their fill instead.
class AppElevation {
  const AppElevation._();

  /// Flat: no separation beyond the surface colour.
  static const List<BoxShadow> none = [];

  /// Cards and tiles resting on the page background.
  static List<BoxShadow> level1(Brightness brightness) =>
      brightness == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0A101828),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ];

  /// Raised controls: segmented selection, floating chips.
  static List<BoxShadow> level2(Brightness brightness) =>
      brightness == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x14101828),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ];

  /// Sheets, dialogs and bars that overlay content.
  static List<BoxShadow> level3(Brightness brightness) =>
      brightness == Brightness.dark
      ? const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, -2),
          ),
        ]
      : const [
          BoxShadow(
            color: Color(0x1A101828),
            blurRadius: 18,
            offset: Offset(0, -2),
          ),
        ];

  static List<BoxShadow> card(BuildContext context) =>
      level1(Theme.of(context).brightness);

  static List<BoxShadow> raised(BuildContext context) =>
      level2(Theme.of(context).brightness);

  static List<BoxShadow> overlay(BuildContext context) =>
      level3(Theme.of(context).brightness);
}
