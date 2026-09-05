import 'package:get/get.dart';

/// Owns which tab the shell is showing.
///
/// Tab bodies are kept alive by an [IndexedStack], so switching tabs does not
/// re-run their controllers' queries.
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
