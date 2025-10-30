import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/role_config.dart';
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
/// Handles:
/// ✅ Dynamic TopBar tabs per module
/// ✅ Animated screen switching
/// ✅ Role-based tab visibility (Admin / Employee)
/// ✅ Automatic safe padding (top + bottom)
/// ---------------------------------------------------------------------------
class BaseModuleScreen extends StatefulWidget {
  final List<Widget> screens;
  final List<String> tabLabels;
  final List<IconData> tabIcons;
  final int defaultIndex;
  final bool showUserMode;
  final bool showBackButton;
  final bool useTopBar;
  final List<bool>? adminOnly; // 👈 New optional flag for role-based visibility

  const BaseModuleScreen({
    super.key,
    required this.screens,
    required this.tabLabels,
    required this.tabIcons,
    this.adminOnly,
    this.defaultIndex = 0,
    this.showUserMode = true,
    this.showBackButton = true,
    this.useTopBar = true,
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
    if (index < _visibleScreens.length) {
      setState(() => _activeIndex = index);
    }
  }

  List<int> get _visibleIndices {
    final adminOnly = widget.adminOnly;
    if (adminOnly == null) {
      return List.generate(widget.screens.length, (i) => i);
    }

    // Filter indices based on current role
    return List.generate(widget.screens.length, (i) {
      final restricted = adminOnly[i];
      if (!restricted || RoleConfig.instance.isAdmin) return i;
      return -1;
    }).where((i) => i != -1).toList();
  }

  List<Widget> get _visibleScreens => _visibleIndices.map((i) => widget.screens[i]).toList();
  List<String> get _visibleLabels => _visibleIndices.map((i) => widget.tabLabels[i]).toList();
  List<IconData> get _visibleIcons => _visibleIndices.map((i) => widget.tabIcons[i]).toList();

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    final topInset = padding.top;
    final bottomInset = padding.bottom;

    // Ensure activeIndex stays valid if tabs change due to role switching
    if (_activeIndex >= _visibleScreens.length) {
      _activeIndex = 0;
    }

    return Scaffold(
      backgroundColor: ThemeConfig.white,
      appBar: widget.useTopBar
        ? TopBar(
            activeIndex: _activeIndex,
            onNavTap: _onNavTap,
            showUserMode: widget.showUserMode,
            showBackButton: widget.showBackButton,
            tabLabels: _visibleLabels,
            tabIcons: _visibleIcons,
            onRoleChanged: () {
              setState(() {
                _activeIndex = 0; // 👈 reset active index after role change
              });
            },
          )
        : null,
      body: Padding(
        padding: EdgeInsets.only(
          top: widget.useTopBar ? 0 : padding.top,
          bottom: padding.bottom,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Builder(
            builder: (context) {
              // 👇 If no tabs are visible for current role → go back to startup screen
              if (_visibleScreens.isEmpty) {
                Future.microtask(() {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                });
                return const Center(
                  child: Text(
                    "Redirecting to Startup...",
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              // Otherwise, render the appropriate screen
              return _visibleScreens[_activeIndex.clamp(0, _visibleScreens.length - 1)];
            },
          ),
        ),
      ),
    );
  }
}
