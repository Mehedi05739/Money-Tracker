import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_progress_bar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/danger_dialog.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../../domain/services/data_transfer_service.dart';
import '../../../../domain/services/import_validation.dart';
import '../controllers/data_controller.dart';

/// Export, import, backup and restore.
///
/// Kept off the main settings list because every action here is slow, and two
/// of them replace the entire ledger — they deserve a screen that can explain
/// itself rather than a row squeezed between toggles.
class DataPage extends GetView<DataController> {
  const DataPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Data')),
      body: ContentWidth(
        child: Obx(
          () => ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  'Files are written to this app’s own storage on this device. '
                  'Nothing is uploaded or shared.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              if (controller.progress.value case final step?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _ProgressCard(step: step),
                ),
              if (controller.lastProblems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _ProblemsCard(problems: controller.lastProblems),
                ),
              if (controller.lastResult.value case final result?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _ResultCard(result: result),
                ),

              const SectionHeader(title: 'Export'),
              _ActionCard(
                icon: Icons.description_outlined,
                title: 'Export data',
                subtitle:
                    'Writes every record to a readable JSON file you can '
                    'inspect or keep',
                busy: controller.isBusy.value,
                onTap: controller.exportData,
              ),
              _ActionCard(
                icon: Icons.upload_file_outlined,
                title: 'Import data',
                subtitle:
                    'Adds an export to your data, or replaces it — you choose',
                busy: controller.isBusy.value,
                onTap: () => _pickAndImport(context),
              ),

              const SectionHeader(title: 'Backup'),
              _ActionCard(
                icon: Icons.save_outlined,
                title: 'Backup database',
                subtitle: 'An exact copy of the database file',
                busy: controller.isBusy.value,
                onTap: controller.backup,
              ),
              _ActionCard(
                icon: Icons.settings_backup_restore_rounded,
                title: 'Restore database',
                subtitle: 'Puts a backup back in place of your current data',
                busy: controller.isBusy.value,
                onTap: () => _pickAndRestore(context),
              ),

              if (controller.files.isNotEmpty) ...[
                const SectionHeader(
                  title: 'Saved files',
                  subtitle: 'Newest first',
                ),
                for (final file in controller.files)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      AppSpacing.sm,
                    ),
                    child: _FileCard(file: file),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndImport(BuildContext context) async {
    final file = await _pickFile(
      context,
      backups: false,
      title: 'Choose an export',
      empty: 'No exports saved yet. Export your data first.',
    );
    if (file == null) return;

    // Read and validate before asking anything: a bad file should be reported
    // as bad, not confirmed and then rejected.
    final payload = await controller.inspect(file.path);
    if (payload == null || !context.mounted) return;

    final mode = await _chooseImportMode(context, file, payload);
    if (mode == null || !context.mounted) return;

    // Merge adds without touching what is there, so it needs no scare dialog.
    // Replace destroys data, so it gets the full typed confirmation.
    if (mode == ImportMode.replace) {
      final confirmed = await DangerDialog.show(
        title: 'Replace all data?',
        message:
            'Everything currently in the app is deleted and replaced with the '
            'contents of ${p.basename(file.path)}.',
        confirmWord: 'REPLACE',
        confirmLabel: 'Replace everything',
      );
      if (!confirmed) return;
    }

    await controller.importData(file.path, mode: mode);
  }

  /// Asks how the file should meet the data already there.
  ///
  /// Presented as a real choice with merge first and preselected: an import
  /// that silently overwrote a ledger would be the worst bug this app could
  /// have, so replacing has to be something the user picks deliberately.
  Future<ImportMode?> _chooseImportMode(
    BuildContext context,
    File file,
    ImportPayload payload,
  ) {
    final theme = Theme.of(context);

    return showModalBottomSheet<ImportMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Import', style: theme.textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                _describePayload(payload),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.merge_rounded),
              title: const Text('Add to my data'),
              subtitle: const Text(
                'Keeps everything you have. Records you already have are '
                'matched, not duplicated.',
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImportMode.merge),
            ),
            ListTile(
              leading: Icon(
                Icons.swap_horiz_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(
                'Replace my data',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              subtitle: const Text(
                'Deletes everything currently in the app first',
              ),
              onTap: () => Navigator.of(sheetContext).pop(ImportMode.replace),
            ),
            AppSpacing.gapMd,
          ],
        ),
      ),
    );
  }

  static String _describePayload(ImportPayload payload) {
    final parts = <String>[];
    payload.records.forEach((key, rows) {
      if (rows.isNotEmpty) {
        parts.add('${rows.length} ${key.replaceAll('_', ' ')}');
      }
    });
    if (payload.settings.isNotEmpty) {
      parts.add('${payload.settings.length} preferences');
    }
    final made = payload.exportedAt;
    final when = made == null ? '' : ' · exported ${AppDate.formatDate(made)}';
    return parts.isEmpty
        ? 'This file has no records$when'
        : '${parts.join(', ')}$when';
  }

  Future<void> _pickAndRestore(BuildContext context) async {
    final file = await _pickFile(
      context,
      backups: true,
      title: 'Choose a backup',
      empty: 'No backups saved yet. Back up your database first.',
    );
    if (file == null) return;

    final confirmed = await DangerDialog.show(
      title: 'Restore this backup?',
      message:
          'Your current data is replaced with ${p.basename(file.path)}. '
          'Anything recorded since that backup was made is lost.',
      confirmWord: 'RESTORE',
      confirmLabel: 'Restore backup',
    );
    if (!confirmed) return;

    await controller.restore(file.path);
  }

  /// A chooser over the app's own files, since there is no system file picker.
  Future<File?> _pickFile(
    BuildContext context, {
    required bool backups,
    required String title,
    required String empty,
  }) async {
    final files = await controller.filesOfType(backups: backups);
    if (files.isEmpty) {
      AppSnackbar.info(empty);
      return null;
    }
    if (!context.mounted) return null;

    return showModalBottomSheet<File>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: files.length,
                itemBuilder: (_, index) {
                  final file = files[index];
                  return ListTile(
                    leading: const Icon(Icons.insert_drive_file_outlined),
                    title: Text(p.basename(file.path)),
                    subtitle: Text(_describe(file)),
                    onTap: () => Navigator.of(sheetContext).pop(file),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _describe(File file) {
    final stat = file.statSync();
    final kb = (stat.size / 1024).toStringAsFixed(1);
    return '$kb KB · ${AppDate.formatDateTime(stat.modified)}';
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.busy,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, AppSpacing.sm),
      child: AppCard(
        onTap: busy ? null : onTap,
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  AppSpacing.gapXxs,
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator.adaptive(strokeWidth: 2),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      padding: AppSpacing.cardCompact,
      // Long-press copies the path, which is the only way to find the file
      // from outside the app without a share sheet.
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: file.path));
        AppSnackbar.success('Path copied');
      },
      child: Row(
        children: [
          Icon(
            file.path.endsWith('.bak')
                ? Icons.save_outlined
                : Icons.description_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(file.path),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  DataPage._describe(file),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete file',
            onPressed: () => _confirmDelete(context),
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 19,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      title: 'Delete this file?',
      message:
          '${p.basename(file.path)} is removed from this device. Your current '
          'data is not affected.',
    );
    if (confirmed) await Get.find<DataController>().deleteFile(file);
  }
}

/// What a running transfer is doing, and how far through it is.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.step});

  final TransferProgress step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(step.label, style: theme.textTheme.titleSmall),
              ),
              Text(
                '${(step.fraction * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          // Determinate: a spinner says "wait", a bar says how long for.
          AppProgressBar(
            value: step.fraction,
            color: theme.colorScheme.primary,
            height: 6,
            warningThreshold: 2,
          ),
        ],
      ),
    );
  }
}

/// The outcome of the last transfer.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final DataTransferResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: context.incomeColor),
          AppSpacing.hGapMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Finished', style: theme.textTheme.titleSmall),
                AppSpacing.gapXxs,
                Text(
                  _describe(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _describe() {
    if (result.added == 0 && result.reused == 0) {
      return '${result.recordCount} records · ${result.fileName}';
    }
    final reused = result.reused == 0
        ? ''
        : ' · ${result.reused} already existed and were matched';
    return '${result.added} records added$reused';
  }
}

/// Why an import file was refused, listed rather than summarised.
///
/// "Invalid file" is not something a user can act on; "transactions, record 12:
/// missing amount" is.
class _ProblemsCard extends StatelessWidget {
  const _ProblemsCard({required this.problems});

  final List<ImportProblem> problems;

  /// Enough to find the pattern without turning the screen into a wall of text.
  static const int _shown = 8;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hidden = problems.length - _shown;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
              AppSpacing.hGapMd,
              Expanded(
                child: Text(
                  problems.length == 1
                      ? 'That file could not be imported'
                      : 'That file could not be imported '
                            '(${problems.length} problems)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.gapSm,
          for (final problem in problems.take(_shown))
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $problem',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (hidden > 0)
            Text(
              'and $hidden more',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          AppSpacing.gapSm,
          Text(
            'Nothing was changed.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
