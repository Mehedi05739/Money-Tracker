import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Kinds of data change screens may care about.
enum DataChange {
  transactions,
  accounts,
  categories,
  budgets,
  plans,
  goals,
  recurring,
}

/// Broadcasts "this kind of data changed" so screens that are already built
/// refresh themselves.
///
/// The shell keeps tab bodies alive, so a transaction added from the floating
/// action button would otherwise leave the dashboard, ledger and reports
/// showing stale figures until the app restarted. Emitting here is cheaper and
/// far less error-prone than every caller remembering which screens to reload.
class AppEvents extends GetxService {
  final Rx<DataChange?> _lastChange = Rx<DataChange?>(null);

  void emit(DataChange change) {
    // Reset first so emitting the same kind twice in a row still notifies —
    // `Rx` suppresses writes that equal the current value.
    _lastChange
      ..value = null
      ..value = change;
  }

  /// Runs [action] whenever any of [kinds] is emitted.
  ///
  /// Callers must dispose the returned worker in `onClose`.
  Worker listen(List<DataChange> kinds, VoidCallback action) =>
      onChange(kinds, (_) => action());

  /// Like [listen], but hands the change to [action].
  ///
  /// Screens that show several kinds of data use this to reload only the part
  /// that actually went stale, instead of re-running every query they own.
  Worker onChange(
    List<DataChange> kinds,
    void Function(DataChange change) action,
  ) => ever<DataChange?>(_lastChange, (change) {
    if (change != null && kinds.contains(change)) action(change);
  });
}
