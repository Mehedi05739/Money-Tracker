import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';

/// Greeting and today's date.
///
/// A finance app is opened many times a day, so the header answers "when am I
/// looking at?" before the figures do.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, this.now});

  /// Injectable so the greeting can be tested without waiting for evening.
  final DateTime? now;

  static String greetingFor(DateTime time) {
    final hour = time.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = now ?? DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          greetingFor(time),
          style: theme.textTheme.titleLarge,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        AppSpacing.gapXxs,
        Text(
          AppDate.formatDate(time),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
