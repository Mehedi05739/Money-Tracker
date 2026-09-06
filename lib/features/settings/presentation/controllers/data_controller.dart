import 'dart:io';

import 'package:get/get.dart';

import '../../../../core/events/app_events.dart';
import '../../../../core/utils/logger.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../domain/services/data_transfer_service.dart';
import '../../../../domain/services/import_validation.dart';

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

  /// The step a running transfer is on, or null when idle. Drives the progress
  /// bar; a long import over a big ledger otherwise looks like a hang.
  final Rxn<TransferProgress> progress = Rxn<TransferProgress>();

  /// What the last transfer produced, kept so the screen can show a result
  /// rather than a snackbar the user may have missed.
  final Rxn<DataTransferResult> lastResult = Rxn<DataTransferResult>();

  /// Problems from the last rejected import file, listed for the user.
  final RxList<ImportProblem> lastProblems = <ImportProblem>[].obs;

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
    action: () => _service.exportToJson(onProgress: _report),
    describe: (result) =>
        'Exported ${result.recordCount} records to ${result.fileName}',
  );

  Future<void> backup() => _run(
    action: _service.backup,
    describe: (result) => 'Backed up to ${result.fileName}',
  );

  /// Reads a file and reports what it holds, without writing anything.
  ///
  /// Lets the user see what they are about to import — and be told exactly
  /// what is wrong with a bad file — before any confirmation is asked for.
  Future<ImportPayload?> inspect(String path) async {
    lastProblems.clear();
    // Clear the previous run's outcome too, or a failed inspection leaves a
    // stale "Finished" card sitting under the error.
    lastResult.value = null;
    try {
      return await _service.inspect(path);
    } on ImportValidationException catch (error) {
      lastProblems.assignAll(error.problems);
      AppSnackbar.error(error.summary);
      return null;
    } catch (error) {
      AppLogger.w('Could not read file: ${error.runtimeType}', name: 'DATA');
      AppSnackbar.error('That file could not be read');
      return null;
    }
  }

  /// Loads a file. Emits a change for each data kind afterwards, so screens the
  /// shell is keeping alive reload rather than showing the ledger that existed
  /// a moment ago.
  Future<void> importData(String path, {required ImportMode mode}) => _run(
    action: () =>
        _service.importFromJson(path, mode: mode, onProgress: _report),
    describe: (result) => result.replaced
        ? 'Replaced everything with ${result.added} records'
        : result.reused > 0
        ? 'Added ${result.added} records, matched ${result.reused} you '
              'already had'
        : 'Added ${result.added} records',
    invalidatesEverything: true,
  );

  Future<void> restore(String path) => _run(
    action: () => _service.restore(path, onProgress: _report),
    describe: (result) =>
        'Restored ${result.recordCount} records from ${result.fileName}',
    invalidatesEverything: true,
  );

  void _report(TransferProgress value) => progress.value = value;

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
    lastResult.value = null;
    lastProblems.clear();

    try {
      final result = await action();
      if (invalidatesEverything) _emitAll();
      await refreshFiles();
      lastResult.value = result;
      AppSnackbar.success(describe(result));
    } on ImportValidationException catch (error) {
      lastProblems.assignAll(error.problems);
      AppSnackbar.error(error.summary);
    } on FormatException catch (error) {
      // The message here describes the file, not the user's data, so it is
      // safe to show.
      AppSnackbar.error(error.message);
    } catch (error) {
      AppLogger.w('Data action failed: ${error.runtimeType}', name: 'DATA');
      AppSnackbar.error('That did not work. Your data is unchanged.');
    } finally {
      isBusy.value = false;
      progress.value = null;
    }
  }

  void _emitAll() {
    for (final change in DataChange.values) {
      _events.emit(change);
    }
  }
}
