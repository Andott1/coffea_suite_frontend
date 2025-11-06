/// <<FILE: lib/core/widgets/master_topbar.dart>>
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../config/role_config.dart';
import '../utils/dialog_utils.dart';

/// =============================================================
///  COFFEA SUITE - MASTER TOPBAR WIDGET (Refined Layout)
///  Description: Core topbar for all Coffea Suite modules
///               Now with flush bottom-aligned underline tabs.
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
  final List<bool> adminOnlyTabs;
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
    this.adminOnlyTabs = const [],
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

  static const Map<String, IconData> _tabIcons = {
    "dashboard": Icons.dashboard_outlined,
    "cashier": Icons.point_of_sale,
    "history": Icons.history,
    "overview": Icons.assessment_outlined,
    "products": Icons.local_cafe_outlined,
    "stock": Icons.inventory_2_outlined,
    "time": Icons.access_time,
    "logs": Icons.list_alt,
    "payroll": Icons.receipt_long,
    "analytics": Icons.analytics_outlined,
    "employees": Icons.people_outline,
    "ingredients": Icons.science_outlined,
    "settings": Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: statusBarHeight),
        Container(
          height: preferredSize.height,
          width: double.infinity,
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // LEFT SECTION
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    if (showBackButton)
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: ThemeConfig.primaryGreen),
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
              ),

              // CENTER SECTION (Tabs, role-aware)
              if (showTabs && tabs.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Consumer<RoleConfig>(
                        builder: (context, roleManager, _) {
                          final isAdmin = roleManager.isAdmin;

                          // Filter visible tabs
                          final visibleTabs = <String>[];
                          final visibleIndices = <int>[];

                          for (int i = 0; i < tabs.length; i++) {
                            final isRestricted = (adminOnlyTabs.isNotEmpty &&
                                i < adminOnlyTabs.length &&
                                adminOnlyTabs[i]);
                            if (!isRestricted || isAdmin) {
                              visibleTabs.add(tabs[i]);
                              visibleIndices.add(i);
                            }
                          }

                          // Prevent showing a hidden tab as active
                          if (!isAdmin &&
                              adminOnlyTabs.isNotEmpty &&
                              activeIndex < adminOnlyTabs.length &&
                              adminOnlyTabs[activeIndex]) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              onTabSelected?.call(0);
                            });
                          }

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(visibleTabs.length, (vIndex) {
                              final label = visibleTabs[vIndex];
                              final originalIndex = visibleIndices[vIndex];
                              final bool isActive = originalIndex == activeIndex;
                              final normalized = label.toLowerCase();

                              final tabIcon = _tabIcons.entries
                                  .firstWhere(
                                    (entry) => normalized.contains(entry.key),
                                    orElse: () => const MapEntry(
                                        "", Icons.circle_outlined),
                                  )
                                  .value;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10.0),
                                child: InkWell(
                                  splashColor: ThemeConfig.primaryGreen.withOpacity(0.1),
                                  hoverColor: ThemeConfig.primaryGreen.withOpacity(0.05),
                                  onTap: () => onTabSelected?.call(originalIndex),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    curve: Curves.easeInOut,
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: isActive
                                              ? ThemeConfig.primaryGreen
                                              : Colors.transparent,
                                          width: isActive ? 3 : 0,
                                        ),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          tabIcon,
                                          size: 18,
                                          color: ThemeConfig.primaryGreen,
                                        ),
                                        const SizedBox(width: 6),
                                        AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 150),
                                          style: FontConfig.body(context).copyWith(
                                            color: ThemeConfig.primaryGreen,
                                            fontWeight: isActive
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                            fontSize: isActive ? 17 : 15,
                                          ),
                                          child: Text(label),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                )
              else
                const Spacer(),

              // RIGHT SECTION
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  children: [
                    if (showOnlineStatus)
                      GestureDetector(
                        onTap: onStatusTap,
                        child: Row(
                          children: [
                            const Icon(Icons.wifi,
                                size: 18, color: ThemeConfig.primaryGreen),
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
                          final icon = isAdmin
                              ? Icons.admin_panel_settings
                              : Icons.person_outline;

                          return Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              splashColor:
                                  ThemeConfig.primaryGreen.withOpacity(0.1),
                              highlightColor:
                                  ThemeConfig.primaryGreen.withOpacity(0.05),
                              hoverColor:
                                  ThemeConfig.primaryGreen.withOpacity(0.08),
                              onTap: () {
                                final wasAdmin = roleManager.isAdmin;
                                roleManager.toggleRole();
                                final message = wasAdmin
                                    ? "Switched to Employee Mode"
                                    : "Switched to Admin Mode";
                                DialogUtils.showToast(context, message);
                                onRoleToggle?.call();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: ThemeConfig.primaryGreen,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon,
                                        size: 18,
                                        color: ThemeConfig.primaryGreen),
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
              ),
            ],
          ),
        ),
      ],
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
