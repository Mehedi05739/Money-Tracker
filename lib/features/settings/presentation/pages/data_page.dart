import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/danger_dialog.dart';
import '../../../../core/widgets/section_header.dart';
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
                subtitle: 'Replaces everything with the contents of an export',
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

    final confirmed = await DangerDialog.show(
      title: 'Replace all data?',
      message:
          'Everything currently in the app is deleted and replaced with the '
          'contents of ${p.basename(file.path)}.',
      confirmWord: 'REPLACE',
      confirmLabel: 'Replace everything',
    );
    if (!confirmed) return;

    await controller.importData(file.path);
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
