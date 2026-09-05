import 'package:flutter/material.dart';

import '../theme/category_icons.dart';

/// Circular category badge used in lists, pickers and charts legends.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    super.key,
    this.icon,
    this.color,
    this.seed = 0,
    this.size = 42,
    this.overrideIcon,
  });

  final String? icon;
  final int? color;
  final int seed;
  final double size;
  final IconData? overrideIcon;

  @override
  Widget build(BuildContext context) {
    final resolved = CategoryIcons.resolveColor(color, seed: seed);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(
        overrideIcon ?? CategoryIcons.resolve(icon),
        color: resolved,
        size: size * 0.5,
      ),
    );
  }
}
