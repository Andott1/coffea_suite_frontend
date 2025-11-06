/// <<FILE: lib/core/widgets/master_topbar.dart>>
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../config/role_config.dart';
import '../utils/dialog_utils.dart'; //

/// =============================================================
///  COFFEA SUITE - MASTER TOPBAR WIDGET
///  Description: Core custom topbar architecture shared across
///               all system modules (POS, Admin, Inventory, etc.)
/// =============================================================

enum CoffeaSystem {
  startup,
  pos,
  attendance,
  inventory,
  admin,
}

class TopBarLayout {
  final String title;
  final List<String> tabs;
  final List<bool> adminOnlyTabs;
  final bool showUserMode;
  final bool showOnlineStatus;

  const TopBarLayout({
    required this.title,
    this.tabs = const [],
    this.adminOnlyTabs = const [],
    this.showUserMode = true,
    this.showOnlineStatus = true,
  });
}

class CoffeaContext {
  static CoffeaSystem detectSystem(BuildContext context) {
    final route = ModalRoute.of(context)?.settings.name ?? '/';
    if (route.startsWith('/pos')) return CoffeaSystem.pos;
    if (route.startsWith('/inventory')) return CoffeaSystem.inventory;
    if (route.startsWith('/attendance')) return CoffeaSystem.attendance;
    if (route.startsWith('/admin')) return CoffeaSystem.admin;
    return CoffeaSystem.startup;
  }
}

class MasterTopBar extends StatelessWidget implements PreferredSizeWidget {
  final CoffeaSystem system;
  final int activeIndex;
  final List<String> tabs;
  final ValueChanged<int>? onTabSelected;
  final VoidCallback? onRoleToggle;
  final VoidCallback? onStatusTap;
  final bool showUserMode;
  final bool showOnlineStatus;
  final bool showBackButton;
  final bool showTabs;

  const MasterTopBar({
    super.key,
    required this.system,
    this.activeIndex = 0,
    this.tabs = const [],
    this.onTabSelected,
    this.onRoleToggle,
    this.onStatusTap,
    this.showUserMode = true,
    this.showOnlineStatus = true,
    this.showBackButton = true,
    this.showTabs = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double totalHeight = statusBarHeight + preferredSize.height;

    return Container(
      height: totalHeight,
      padding: EdgeInsets.only(top: statusBarHeight, left: 20, right: 20),
      decoration: BoxDecoration(
        color: ThemeConfig.white,
        border: const Border(
          bottom: BorderSide(color: ThemeConfig.lightGray, width: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT SECTION
          Row(
            children: [
              if (showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: ThemeConfig.primaryGreen),
                  onPressed: () => Navigator.maybePop(context),
                ),
              Text(
                _getSystemTitle(),
                style: FontConfig.h2(context).copyWith(
                  color: ThemeConfig.primaryGreen,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // CENTER SECTION (Tabs)
          if (showTabs && tabs.isNotEmpty)
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(tabs.length, (index) {
                      final bool isActive = index == activeIndex;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => onTabSelected?.call(index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tabs[index],
                                style: FontConfig.body(context).copyWith(
                                  fontWeight:
                                      isActive ? FontWeight.bold : FontWeight.w500,
                                  color: isActive
                                      ? ThemeConfig.primaryGreen
                                      : Colors.grey[600],
                                ),
                              ),
                              if (isActive)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  height: 3,
                                  width: 26,
                                  color: ThemeConfig.primaryGreen,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            )
          else
            const Spacer(),

          // RIGHT SECTION
          Row(
            children: [
              if (showOnlineStatus)
                GestureDetector(
                  onTap: onStatusTap,
                  child: Row(
                    children: [
                      const Icon(Icons.wifi, size: 18, color: ThemeConfig.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        "Online",
                        style: FontConfig.body(context).copyWith(
                          color: ThemeConfig.primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 12),

              if (showUserMode)
                Consumer<RoleConfig>(
                  builder: (context, roleManager, _) {
                    final isAdmin = roleManager.isAdmin;
                    final label = isAdmin ? "ADMIN" : "EMPLOYEE";
                    final icon =
                        isAdmin ? Icons.admin_panel_settings : Icons.person_outline;

                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        splashColor: ThemeConfig.primaryGreen.withOpacity(0.1),
                        highlightColor: ThemeConfig.primaryGreen.withOpacity(0.05),
                        hoverColor: ThemeConfig.primaryGreen.withOpacity(0.08),
                        onTap: () {
                          // Capture the current role BEFORE toggling
                          final wasAdmin = roleManager.isAdmin;

                          // Toggle role
                          roleManager.toggleRole();

                          // Determine message based on the previous role
                          final message = wasAdmin
                              ? "Switched to Employee Mode"
                              : "Switched to Admin Mode";

                          // ✅ Use the same toast call as StartupScreen
                          DialogUtils.showToast(context, message);

                          // Optional external callback (non-toggle use)
                          onRoleToggle?.call();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ThemeConfig.primaryGreen,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: ThemeConfig.primaryGreen),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: FontConfig.body(context).copyWith(
                                  color: ThemeConfig.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

            ],
          ),
        ],
      ),
    );
  }

  String _getSystemTitle() {
    switch (system) {
      case CoffeaSystem.startup:
        return "Coffea Suite";
      case CoffeaSystem.pos:
        return "Point of Sale";
      case CoffeaSystem.attendance:
        return "Attendance Monitoring";
      case CoffeaSystem.inventory:
        return "Inventory Management";
      case CoffeaSystem.admin:
        return "Admin Tools";
    }
  }
}
/// <<END FILE>>