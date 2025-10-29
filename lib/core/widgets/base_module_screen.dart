import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import 'topbar.dart';

/// ---------------------------------------------------------------------------
/// BaseModuleScreen
/// ---------------------------------------------------------------------------
/// Shared layout container for all Coffea Suite modules:
/// - POS
/// - Admin Tools
/// - Inventory System
/// - Attendance System
///
/// Each system defines its own tabs (via tabLabels + tabIcons),
/// and passes its corresponding screens list.
/// ---------------------------------------------------------------------------
class BaseModuleScreen extends StatefulWidget {
  final List<Widget> screens;
  final List<String> tabLabels;
  final List<IconData> tabIcons;
  final int defaultIndex;
  final bool showUserMode;
  final bool showBackButton;

  const BaseModuleScreen({
    super.key,
    required this.screens,
    required this.tabLabels,
    required this.tabIcons,
    this.defaultIndex = 0,
    this.showUserMode = true,
    this.showBackButton = true,
  });

  @override
  State<BaseModuleScreen> createState() => _BaseModuleScreenState();
}

class _BaseModuleScreenState extends State<BaseModuleScreen> {
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.defaultIndex;
  }

  void _onNavTap(int index) {
    if (index < widget.screens.length) {
      setState(() => _activeIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.white,
      appBar: TopBar(
        activeIndex: _activeIndex,
        onNavTap: _onNavTap,
        showUserMode: widget.showUserMode,
        showBackButton: widget.showBackButton,
        tabLabels: widget.tabLabels,
        tabIcons: widget.tabIcons,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: widget.screens[_activeIndex],
      ),
    );
  }
}
