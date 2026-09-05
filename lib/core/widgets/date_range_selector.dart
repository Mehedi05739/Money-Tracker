import 'package:flutter/material.dart';

import '../utils/date_range.dart';

/// Horizontal preset chips plus a custom-range option.
///
/// Presets cover the common cases in one tap; "Custom" opens the platform
/// range picker.
class DateRangeSelector extends StatelessWidget {
  const DateRangeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.presets = const [
      DateRangePreset.today,
      DateRangePreset.thisWeek,
      DateRangePreset.thisMonth,
      DateRangePreset.lastMonth,
      DateRangePreset.thisYear,
      DateRangePreset.allTime,
    ],
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final DateRange selected;
  final ValueChanged<DateRange> onChanged;
  final List<DateRangePreset> presets;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isCustom = selected.preset == DateRangePreset.custom;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: padding,
        children: [
          for (final preset in presets) ...[
            _Chip(
              label: preset.label,
              isSelected: !isCustom && selected.preset == preset,
              onTap: () => onChanged(DateRange.fromPreset(preset)),
            ),
            const SizedBox(width: 8),
          ],
          _Chip(
            label: isCustom ? selected.label : 'Custom',
            icon: Icons.date_range_rounded,
            isSelected: isCustom,
            onTap: () => _pickCustomRange(context),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: selected.start, end: selected.end),
      helpText: 'Select a date range',
    );

    if (picked == null) return;
    onChanged(DateRange.custom(picked.start, picked.end));
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChoiceChip(
      selected: isSelected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 15,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
      label: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
