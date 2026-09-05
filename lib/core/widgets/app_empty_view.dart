import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.inbox_rounded,
    this.action,
  });

  final String message;
  final String? title;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.6,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 38,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            AppSpacing.gapLg,
            if (title != null) ...[
              Text(title!, style: theme.textTheme.titleLarge),
              AppSpacing.gapSm,
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[AppSpacing.gapXl, action!],
          ],
        ),
      ),
    );
  }
}
