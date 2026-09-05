import 'package:get/get.dart';

/// Owns which tab the shell is showing.
///
/// Tab bodies are kept alive by an [IndexedStack], so switching tabs does not
/// re-run their controllers' queries.
/// Tab indices, so callers switching tabs do not pass a bare integer.
class ShellTabs {
  const ShellTabs._();

  static const int dashboard = 0;
  static const int transactions = 1;
  static const int plans = 2;
  static const int reports = 3;
  static const int more = 4;
}

class ShellController extends GetxController {
  final RxInt currentIndex = 0.obs;

  /// Tabs the user has opened. A tab's body is not built until first visit,
  /// so startup only pays for the dashboard.
  final RxSet<int> visitedTabs = <int>{0}.obs;

  void changeTab(int index) {
    if (index == currentIndex.value) return;
    currentIndex.value = index;
    visitedTabs.add(index);
  }

  bool isVisited(int index) => visitedTabs.contains(index);
}
