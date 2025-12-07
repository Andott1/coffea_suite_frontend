import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/connectivity/connectivity_cubit.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/services/session_user.dart';
import '../../core/services/supabase_sync_service.dart'; // ✅ Added Import
import '../../core/utils/dialog_utils.dart'; // ✅ Added Import
import '../../core/models/user_model.dart';
import 'login_dialog.dart'; 
import 'basic_button.dart';

import '../enums/coffea_system.dart';
export '../enums/coffea_system.dart';

class MasterTopBar extends StatelessWidget implements PreferredSizeWidget {
  final CoffeaSystem system;
  final int activeIndex;
  final List<String> tabs;
  final List<bool> adminOnlyTabs;
  final ValueChanged<int>? onTabSelected;
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

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        String userLabel = "GUEST";
        String roleLabel = "";
        bool isAdmin = false;

        if (state is AuthAuthenticated) {
          userLabel = state.user.username.toUpperCase();
          roleLabel = state.user.role.name.toUpperCase();
          isAdmin = state.user.role == UserRoleLevel.admin;
        }

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
                    color: Colors.black.withValues(alpha: 0.05),
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
                  ),

                  // CENTER SECTION (Tabs)
                  if (showTabs && tabs.isNotEmpty)
                    Expanded(
                      child: Align(
                        alignment: Alignment.center,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Builder(
                            builder: (context) {
                              final visibleTabs = <String>[];
                              final visibleIndices = <int>[];

                              for (int i = 0; i < tabs.length; i++) {
                                final isRestricted = (adminOnlyTabs.isNotEmpty && i < adminOnlyTabs.length && adminOnlyTabs[i]);
                                if (!isRestricted || isAdmin) {
                                  visibleTabs.add(tabs[i]);
                                  visibleIndices.add(i);
                                }
                              }

                              if (!isAdmin && adminOnlyTabs.isNotEmpty && activeIndex < adminOnlyTabs.length && adminOnlyTabs[activeIndex]) {
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
                                        orElse: () => const MapEntry("", Icons.circle_outlined),
                                      )
                                      .value;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                                    child: InkWell(
                                      splashColor: ThemeConfig.primaryGreen.withValues(alpha: 0.1),
                                      hoverColor: ThemeConfig.primaryGreen.withValues(alpha: 0.05),
                                      onTap: () => onTabSelected?.call(originalIndex),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        curve: Curves.easeInOut,
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: isActive ? ThemeConfig.primaryGreen : Colors.transparent,
                                              width: isActive ? 3 : 0,
                                            ),
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(tabIcon, size: 18, color: ThemeConfig.primaryGreen),
                                            const SizedBox(width: 6),
                                            AnimatedDefaultTextStyle(
                                              duration: const Duration(milliseconds: 150),
                                              style: FontConfig.body(context).copyWith(
                                                color: ThemeConfig.primaryGreen,
                                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
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

                  // RIGHT SECTION: Status & User
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      children: [
                        if (showOnlineStatus) ...[
                          BlocBuilder<ConnectivityCubit, bool>(
                            builder: (context, isOnline) {
                              final color = isOnline ? ThemeConfig.primaryGreen : Colors.redAccent;
                              final icon = isOnline ? Icons.wifi : Icons.wifi_off;
                              final text = isOnline ? "Online" : "Offline";

                              return Row(
                                children: [
                                  Icon(icon, size: 18, color: color),
                                  const SizedBox(width: 4),
                                  Text(
                                    text,
                                    style: FontConfig.body(context).copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              );
                            }
                          ),
                          const SizedBox(width: 12),
                          // ✅ ADDED: Manual Sync Button
                          const _ManualSyncButton(),
                        ],
                        
                        const SizedBox(width: 12),

                        if (showUserMode)
                          BasicButton(
                            label: "$userLabel • $roleLabel",
                            icon: isAdmin ? Icons.admin_panel_settings : Icons.person,
                            type: AppButtonType.secondary,
                            fullWidth: false,
                            height: 40,
                            fontSize: 14,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            onPressed: () {
                              FocusScope.of(context).unfocus();
                              showDialog(
                                context: context,
                                barrierDismissible: true,
                                builder: (_) => const LoginDialog(isStartup: false),
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
    );
  }

  String _getSystemTitle() {
    switch (system) {
      case CoffeaSystem.startup: return "Coffea Suite";
      case CoffeaSystem.pos: return "Point of Sale";
      case CoffeaSystem.attendance: return "Attendance";
      case CoffeaSystem.inventory: return "Inventory";
      case CoffeaSystem.admin: return "Admin Tools";
    }
  }
}

// ───────────────────────────────────────────────
// ✅ NEW COMPONENT: Manual Sync Button
// ───────────────────────────────────────────────
class _ManualSyncButton extends StatefulWidget {
  const _ManualSyncButton();

  @override
  State<_ManualSyncButton> createState() => _ManualSyncButtonState();
}

class _ManualSyncButtonState extends State<_ManualSyncButton> {
  bool _isLoading = false;

  Future<void> _handleSync() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      // This method pulls all tables from Supabase and overwrites local Hive boxes
      // It effectively forces a "fresh pull" of the database.
      await SupabaseSyncService.restoreFromCloud();
      
      if (mounted) {
        DialogUtils.showToast(context, "Sync Complete! Data refreshed.");
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showToast(
          context, 
          "Sync Failed: $e", 
          icon: Icons.error, 
          accentColor: Colors.red
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isLoading ? null : _handleSync,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: _isLoading 
          ? const SizedBox(
              width: 18, 
              height: 18, 
              child: CircularProgressIndicator(strokeWidth: 2)
            )
          : const Icon(Icons.sync, size: 20, color: Colors.blue),
      ),
    );
  }
}