import 'package:flutter/material.dart';

import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/category_icons.dart';
import '../../../../domain/entities/category.dart';

/// Visual category picker.
///
/// A grid of icons is scanned by shape and colour rather than read word by
/// word, which is what makes category selection a glance instead of a task.
/// Column count follows the width class so the tiles stay thumb-sized.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onSelected,
    this.selectedId,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = true,
    this.physics,
    this.visibleRows,
  });

  final List<Category> categories;
  final ValueChanged<Category> onSelected;
  final int? selectedId;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  /// Pin the grid to this many rows. When null and the parent gives a bounded
  /// height, the grid fits as many *whole* rows as that height allows — a
  /// partial row reads as a rendering fault, and the leftover pixels read as a
  /// gap someone forgot to close.
  final int? visibleRows;

  @override
  Widget build(BuildContext context) {
    final columns = context.gridColumns(
      compact: 4,
      standard: 4,
      expanded: 5,
      wide: 6,
    );

    final grid = GridView.builder(
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.sm,
        // Tall enough for the icon plus two lines of label.
        childAspectRatio: _aspectRatio,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryTile(
          category: category,
          isSelected: category.id == selectedId,
          onTap: () => onSelected(category),
        );
      },
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = padding.resolve(TextDirection.ltr).horizontal;
        final usableWidth =
            constraints.maxWidth - horizontal - AppSpacing.sm * (columns - 1);
        final tileHeight = (usableWidth / columns) / _aspectRatio;
        final stride = tileHeight + AppSpacing.md;

        final rows =
            visibleRows ??
            (constraints.hasBoundedHeight
                ? (((constraints.maxHeight + AppSpacing.md) / stride)
                      .floor()
                      .clamp(1, 99))
                : 2);

        return SizedBox(
          height: tileHeight * rows + AppSpacing.md * (rows - 1),
          child: grid,
        );
      },
    );
  }

  /// Tile height ≈ 52dp icon + 4dp gap + up to two 11dp label lines. Anything
  /// taller leaves slack inside the tile that reads as a gap in the layout.
  static const double _aspectRatio = 0.95;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final Category category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = CategoryIcons.resolveColor(category.color, seed: category.id);

    return Semantics(
      button: true,
      selected: isSelected,
      label: category.name,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdAll,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isSelected ? 0.22 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                CategoryIcons.resolve(category.icon),
                color: color,
                size: 24,
              ),
            ),
            AppSpacing.gapXs,
            Flexible(
              child: Text(
                category.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
