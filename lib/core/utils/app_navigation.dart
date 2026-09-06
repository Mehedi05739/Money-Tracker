import 'package:flutter/widgets.dart';

/// Pops the current route with [result].
///
/// Deliberately uses `Navigator.pop` rather than `Get.back()`. GetX's `back()`
/// begins with:
///
/// ```dart
/// if (isSnackbarOpen && !closeOverlays) {
///   closeCurrentSnackbar();
///   return;            // never reaches the pop
/// }
/// ```
///
/// Every form in this app shows a "saved" snackbar and then navigates back, so
/// `Get.back()` would dismiss that snackbar and silently swallow the pop —
/// leaving the user on a form whose data was already written.
///
/// Only for synchronous pops. After an `await`, capture the navigator *before*
/// the gap instead: `final navigator = Navigator.of(context);`
void popRoute<T extends Object?>(BuildContext context, [T? result]) =>
    Navigator.of(context).pop<T>(result);

/// Unwinds every pushed route, returning to the app shell.
///
/// Uses the same `Navigator` reasoning as [popRoute]: `Get.until` shares
/// `Get.back()`'s snackbar early-return.
void popToRoot(BuildContext context) =>
    Navigator.of(context).popUntil((route) => route.isFirst);
