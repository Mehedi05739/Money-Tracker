import 'dart:io';

import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/services/data_transfer_service.dart';

/// Drives the Data screen.
///
/// Every action here either writes a file or replaces the entire ledger, so
/// each runs behind [isBusy] — a second tap while an import is mid-transaction
/// would be a second writer against the same rows.
class DataController extends GetxController {
  DataController(this._service, this._events);

  final DataTransferService _service;
  final AppEvents _events;

  final RxBool isBusy = false.obs;
  final RxList<File> files = <File>[].obs;

  @override
  void onInit() {
    super.onInit();
    refreshFiles();
  }

  Future<void> refreshFiles() async {
    final exports = await _service.listFiles(backups: false);
    final backups = await _service.listFiles(backups: true);
    files.assignAll(
      [
        ...exports,
        ...backups,
      ]..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified)),
    );
  }

  Future<List<File>> filesOfType({required bool backups}) =>
      _service.listFiles(backups: backups);

  Future<void> exportData() => _run(
    action: _service.exportToJson,
    describe: (result) =>
        'Exported ${result.recordCount} records to ${result.fileName}',
  );

  Future<void> backup() => _run(
    action: _service.backup,
    describe: (result) => 'Backed up to ${result.fileName}',
  );

  /// Replaces every record. Emits a change for each data kind afterwards, so
  /// screens the shell is keeping alive reload rather than showing the ledger
  /// that existed a moment ago.
  Future<void> importData(String path) => _run(
    action: () => _service.importFromJson(path),
    describe: (result) => 'Imported ${result.recordCount} records',
    invalidatesEverything: true,
  );

  Future<void> restore(String path) => _run(
    action: () => _service.restore(path),
    describe: (result) =>
        'Restored ${result.recordCount} transactions from ${result.fileName}',
    invalidatesEverything: true,
  );

  Future<void> deleteFile(File file) async {
    try {
      if (file.existsSync()) file.deleteSync();
      await refreshFiles();
      AppSnackbar.success('File deleted');
    } catch (error) {
      AppLogger.w('Could not delete file: ${error.runtimeType}', name: 'DATA');
      AppSnackbar.error('Could not delete that file');
    }
  }

  Future<void> _run({
    required Future<DataTransferResult> Function() action,
    required String Function(DataTransferResult result) describe,
    bool invalidatesEverything = false,
  }) async {
    if (isBusy.value) return;
    isBusy.value = true;

    try {
      final result = await action();
      if (invalidatesEverything) _emitAll();
      await refreshFiles();
      AppSnackbar.success(describe(result));
    } on FormatException catch (error) {
      // The message here describes the file, not the user's data, so it is
      // safe to show.
      AppSnackbar.error(error.message);
    } catch (error) {
      AppLogger.w('Data action failed: ${error.runtimeType}', name: 'DATA');
      AppSnackbar.error('That did not work. Your data is unchanged.');
    } finally {
      isBusy.value = false;
    }
  }

  void _emitAll() {
    for (final change in DataChange.values) {
      _events.emit(change);
    }
  }
}
