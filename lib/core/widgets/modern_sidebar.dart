import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/connectivity/connectivity_cubit.dart';
import '../services/supabase_sync_service.dart';
import '../utils/dialog_utils.dart';
import '../enums/coffea_system.dart';
import 'login_dialog.dart';

class ModernSidebar extends StatelessWidget {
  final CoffeaSystem system;
  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onBack;

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
      width: 240,
      color: const Color(0xFFF8F9FA),
      // ✅ CHANGED: Replaced Column with CustomScrollView + Slivers
      child: CustomScrollView(
        slivers: [
          // ─── 1. HEADER (Scrolls with content) ───
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: onBack,
                        style: TextButton.styleFrom(
                          backgroundColor: ThemeConfig.lightGray,
                          foregroundColor: ThemeConfig.midGray,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: const Text("MAIN MENU", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5)),
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
          ),

          // ─── 2. NAVIGATION (Sliver List) ───
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final label = tabs[index];
                  final isActive = index == activeIndex;
                  final icon = _getIconForLabel(label);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Material(
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
                              Icon(icon, color: isActive ? Colors.white : Colors.grey[600], size: 22),
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
                    ),
                  );
                },
                childCount: tabs.length,
              ),
            ),
          ),

          // ─── 3. FOOTER (Fills remaining space) ───
          // This forces the footer to the bottom if there is space,
          // but allows it to scroll naturally if space is tight (keyboard open).
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                 _SidebarFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSystemTitle() {
    switch (system) {
      case CoffeaSystem.admin: return "Admin\nTools";
      case CoffeaSystem.pos: return "Point\nof Sale";
      case CoffeaSystem.inventory: return "Inventory";
      case CoffeaSystem.attendance: return "Attendance";
      default: return "> Coffea";
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── UTILITY ROW ───
          Row(
            children: [
              const Expanded(child: _ManualSyncWidget()),
              const SizedBox(width: 10),
              BlocBuilder<ConnectivityCubit, bool>(
                builder: (context, isOnline) {
                  return Tooltip(
                    message: isOnline ? "Online" : "Offline",
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green.shade50 : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color: isOnline ? Colors.green : Colors.red,
                        size: 20
                      ),
                    ),
                  );
                }
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 2),
          const SizedBox(height: 16),

          // ─── USER IDENTITY ───
          BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              String name = "Guest";
              String role = "";
              
              if (state is AuthAuthenticated) {
                name = state.user.fullName;
                role = state.user.role.name.toUpperCase();
              }

              return Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: ThemeConfig.primaryGreen.withValues(alpha: 0.1),
                    child: Text(name.isNotEmpty ? name[0] : "?", style: const TextStyle(color: ThemeConfig.primaryGreen, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(role, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w400)),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),

          const SizedBox(height: 16),

          // ─── LOGOUT BUTTON ───
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context, 
                  builder: (_) => const LoginDialog(isStartup: false)
                );
              },
              icon: Icon(Icons.logout, size: 20, color: Colors.red.shade700),
              label: Text(
                "Logout",
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16 
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────── SYNC WIDGET ────────────────
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
    return TextButton.icon(
      onPressed: _isLoading ? null : _handleSync,
      icon: _isLoading 
          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue.shade700))
          : Icon(Icons.cloud_download_outlined, size: 22, color: Colors.blue.shade700),
      label: Text(
        _isLoading ? "Syncing..." : "Pull Data",
        style: TextStyle(
          fontSize: 16,
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