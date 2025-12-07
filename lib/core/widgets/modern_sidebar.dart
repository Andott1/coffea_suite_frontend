import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/connectivity/connectivity_cubit.dart';
import '../services/supabase_sync_service.dart';
import '../utils/dialog_utils.dart';
import 'login_dialog.dart';

// ✅ IMPORT THE SHARED ENUM
import '../enums/coffea_system.dart';

class ModernSidebar extends StatelessWidget {
  final CoffeaSystem system;
  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onBack;

  // Icon mapping for all systems
  static const Map<String, IconData> _tabIcons = {
    "dashboard": Icons.dashboard_outlined,
    "employees": Icons.people_outline,
    "products": Icons.local_cafe_outlined,
    "ingredients": Icons.science_outlined,
    "settings": Icons.settings_outlined,
    "cashier": Icons.point_of_sale,
    "history": Icons.history,
    "logs": Icons.list_alt,
    "time": Icons.access_time,
    "payroll": Icons.receipt_long,
    "inventory": Icons.inventory_2_outlined,
  };

  const ModernSidebar({
    super.key,
    required this.system,
    required this.tabs,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240, // Fixed width for tablet stability
      color: const Color(0xFFF8F9FA), // Very subtle gray/white distinction
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── 1. HEADER (Identity) ───
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button & Label
                  InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_ios_new, size: 16, color: ThemeConfig.midGray),
                          const SizedBox(width: 8),
                          Text("MAIN MENU", style: FontConfig.caption(context).copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _getSystemTitle(),
                    style: FontConfig.h2(context).copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: ThemeConfig.primaryGreen,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ─── 2. NAVIGATION (Tabs) ───
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: tabs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final label = tabs[index];
                final isActive = index == activeIndex;
                final icon = _getIconForLabel(label);

                return Material(
                  color: isActive ? ThemeConfig.primaryGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => onTabSelected(index),
                    borderRadius: BorderRadius.circular(12),
                    hoverColor: isActive ? null : ThemeConfig.primaryGreen.withValues(alpha: 0.05),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      child: Row(
                        children: [
                          Icon(
                            icon, 
                            color: isActive ? Colors.white : Colors.grey[600], 
                            size: 22
                          ),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              color: isActive ? Colors.white : Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ─── 3. FOOTER (Status) ───
          const _SidebarFooter(),
        ],
      ),
    );
  }

  String _getSystemTitle() {
    switch (system) {
      case CoffeaSystem.admin: return "Admin\nTools";
      case CoffeaSystem.pos: return "Point\nof Sale";
      case CoffeaSystem.inventory: return "Inventory\nControl";
      case CoffeaSystem.attendance: return "Staff\nManager";
      default: return "Coffea";
    }
  }

  IconData _getIconForLabel(String label) {
    final normalized = label.toLowerCase();
    for (var entry in _tabIcons.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    return Icons.circle_outlined;
  }
}

// ───────────────────────────────────────────────
// STATUS FOOTER
// ───────────────────────────────────────────────
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // Sync & Network Row
          Row(
            children: [
              const Expanded(child: _ManualSyncWidget()),
              const SizedBox(width: 10),
              BlocBuilder<ConnectivityCubit, bool>(
                builder: (context, isOnline) {
                  return Tooltip(
                    message: isOnline ? "Online" : "Offline",
                    child: Icon(
                      isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                      color: isOnline ? ThemeConfig.primaryGreen : Colors.red,
                      size: 36
                    ),
                  );
                }
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // User Profile
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              String name = "Guest";
              String role = "";
              
              if (state is AuthAuthenticated) {
                name = state.user.fullName;
                role = state.user.role.name.toUpperCase();
              }

              return InkWell(
                onTap: () {
                  showDialog(
                    context: context, 
                    builder: (_) => const LoginDialog(isStartup: false)
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: ThemeConfig.primaryGreen.withValues(alpha: 0.1),
                      child: Text(name[0], style: const TextStyle(color: ThemeConfig.primaryGreen, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(role, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                        ],
                      ),
                    ),
                    const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                  ],
                ),
              );
            }
          ),
        ],
      ),
    );
  }
}

class _ManualSyncWidget extends StatefulWidget {
  const _ManualSyncWidget();

  @override
  State<_ManualSyncWidget> createState() => _ManualSyncWidgetState();
}

class _ManualSyncWidgetState extends State<_ManualSyncWidget> {
  bool _isLoading = false;

  Future<void> _handleSync() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseSyncService.restoreFromCloud();
      if (mounted) DialogUtils.showToast(context, "Data Synced!");
    } catch (e) {
      if (mounted) DialogUtils.showToast(context, "Sync Failed", icon: Icons.error, accentColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ UPDATED: Matching styling from Startup Screen
    return TextButton.icon(
      onPressed: _isLoading ? null : _handleSync,
      icon: _isLoading 
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade700))
          : Icon(Icons.cloud_download_outlined, size: 22, color: Colors.blue.shade700),
      label: Text(
        _isLoading ? "Syncing..." : "Pull Data",
        style: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700
        )
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.blue.shade50, 
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}