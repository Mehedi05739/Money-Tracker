import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';

/// Shown when the app cannot open its database.
///
/// Startup failure is the one error the normal error views cannot report: there
/// is no navigator, no theme controller and no repositories yet. Without this
/// the user gets a blank screen and no way to act, so it runs as its own
/// minimal app carrying the message and a retry.
class StartupFailureApp extends StatefulWidget {
  const StartupFailureApp({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;

  /// Re-attempts startup. Returns false when it fails again.
  final Future<bool> Function() onRetry;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  bool _isRetrying = false;
  bool _retryFailed = false;

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
      _retryFailed = false;
    });

    final recovered = await widget.onRetry();
    // On success the caller swaps in the real app, so this widget is gone.
    if (!mounted || recovered) return;

    setState(() {
      _isRetrying = false;
      _retryFailed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Builder(
                builder: (context) {
                  final theme = Theme.of(context);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storage_rounded,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      AppSpacing.gapLg,
                      Text(
                        'Cannot open your data',
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      AppSpacing.gapSm,
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.gapSm,
                      Text(
                        'Your records have not been changed.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AppSpacing.gapXl,
                      SizedBox(
                        width: 220,
                        child: FilledButton.icon(
                          onPressed: _isRetrying ? null : _retry,
                          icon: _isRetrying
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator.adaptive(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh_rounded, size: 18),
                          label: Text(_isRetrying ? 'Retrying' : 'Try again'),
                        ),
                      ),
                      if (_retryFailed) ...[
                        AppSpacing.gapMd,
                        Text(
                          'Still unable to open the database.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
