import 'package:flutter/widgets.dart';

/// Width classes the layout responds to.
enum LayoutSize {
  /// Small phones — iPhone SE, older Androids. Tight, one column.
  compact,

  /// The common phone width.
  standard,

  /// Large phones in landscape and small tablets.
  expanded,

  /// Tablets and desktop windows.
  wide;

  bool get isPhoneWidth => this == compact || this == standard;
  bool get isAtLeastExpanded => this == expanded || this == wide;
}

/// Width thresholds, in logical pixels.
///
/// Named to avoid `isPhone` / `isTablet` / `showNavbar`, which `package:get`
/// already defines on `BuildContext` — redefining them makes every call site
/// ambiguous.
class AppBreakpoints {
  const AppBreakpoints._();

  static const double standard = 360;
  static const double expanded = 600;
  static const double wide = 905;

  /// Reading measure for the main content column. Financial rows become hard
  /// to scan when the label and the amount drift to opposite screen edges, so
  /// content stays centred within this width however wide the window gets.
  static const double contentMaxWidth = 720;

  static LayoutSize of(double width) {
    if (width >= wide) return LayoutSize.wide;
    if (width >= expanded) return LayoutSize.expanded;
    if (width >= standard) return LayoutSize.standard;
    return LayoutSize.compact;
  }
}

extension LayoutContext on BuildContext {
  LayoutSize get layout => AppBreakpoints.of(MediaQuery.sizeOf(this).width);

  bool get isCompactLayout => layout == LayoutSize.compact;
  bool get isWideLayout => layout == LayoutSize.wide;

  /// True once there is room for a navigation rail beside the content.
  bool get usesNavigationRail => layout == LayoutSize.wide;

  /// Picks a value for the current width class, falling back to the nearest
  /// narrower value that was supplied.
  T responsive<T>({
    required T compact,
    T? standard,
    T? expanded,
    T? wide,
  }) {
    final standardValue = standard ?? compact;
    final expandedValue = expanded ?? standardValue;
    return switch (layout) {
      LayoutSize.compact => compact,
      LayoutSize.standard => standardValue,
      LayoutSize.expanded => expandedValue,
      LayoutSize.wide => wide ?? expandedValue,
    };
  }

  /// Column count for a grid at the current width.
  int gridColumns({
    required int compact,
    int? standard,
    int? expanded,
    int? wide,
  }) =>
      responsive<int>(
        compact: compact,
        standard: standard,
        expanded: expanded,
        wide: wide,
      );
}
