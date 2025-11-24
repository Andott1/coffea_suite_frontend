import '../../core/widgets/master_topbar.dart';

/// =============================================================
/// SystemTabMemory
/// Keeps the last selected tab index per system (POS, Inventory,
/// Attendance, Admin) so navigation retains the last active tab.
/// =============================================================
class SystemTabMemory {
  static final Map<CoffeaSystem, int> _lastTabs = {};

  /// Get the last saved tab for a system
  static int getLastTab(CoffeaSystem system, {int defaultIndex = 0}) {
    return _lastTabs[system] ?? defaultIndex;
  }

  /// Save the current tab for a system
  static void setLastTab(CoffeaSystem system, int index) {
    _lastTabs[system] = index;
  }

  /// Optional: Clear all saved tabs (useful for logout or reset)
  static void clearAll() => _lastTabs.clear();
}
/// <<END FILE>>