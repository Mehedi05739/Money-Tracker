import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';

/// Covers the app until the user authenticates.
///
/// A gate, not a keypad: the prompt itself is the operating system's, so this
/// screen only has to hide what is behind it and offer a way to retry. It is
/// deliberately blank of figures — the point is that a glance at the phone
/// shows nothing.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _prompting = false;
  bool _refused = false;

  @override
  void initState() {
    super.initState();
    // After the first frame, so the prompt appears over a painted screen
    // rather than a blank window.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  Future<void> _prompt() async {
    if (_prompting) return;
    setState(() {
      _prompting = true;
      _refused = false;
    });

    final granted = await Get.find<SettingsController>().unlock();

    if (!mounted) return;
    if (granted) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _prompting = false;
      _refused = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              AppSpacing.gapLg,
              Text(AppConstants.appName, style: theme.textTheme.titleLarge),
              AppSpacing.gapSm,
              Text(
                _refused ? 'Authentication was not completed' : 'Locked',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              AppSpacing.gapXl,
              if (_prompting)
                const CircularProgressIndicator.adaptive()
              else
                FilledButton.icon(
                  onPressed: _prompt,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(_refused ? 'Try again' : 'Unlock'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
