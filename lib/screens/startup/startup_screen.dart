import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_event.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/bloc/connectivity/connectivity_cubit.dart';
import '../../core/models/user_model.dart';
import '../../core/models/sync_queue_model.dart'; 
import '../../core/services/session_user.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart'; 
import '../../core/utils/responsive.dart';
import '../../core/utils/dialog_utils.dart'; 
import '../../core/widgets/login_dialog.dart';
import 'initial_setup_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  String _version = "";

  @override
  void initState() {
    super.initState();
    _loadVersion();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStartupFlow();
    });
  }

  void _checkStartupFlow() {
    if (HiveService.userBox.isEmpty) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const InitialSetupScreen())
      );
      return;
    }
    
    if (!SessionUser.isLoggedIn) {
      _showStartupLogin();
    }
  }

  void _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if(mounted) {
      setState(() {
        _version = "v${info.version} (Build ${info.buildNumber})";
      });
    }
  }

  void _showStartupLogin() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoginDialog(isStartup: true),
    );
    if(mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 1. Get status bar height dynamically
    final double statusBarHeight = MediaQuery.of(context).padding.top;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoggedIn = state is AuthAuthenticated;
        UserModel? user;
        if (state is AuthAuthenticated) user = state.user;
        
        final isAdmin = user?.role == UserRoleLevel.admin;

        return Scaffold(
          body: Row(
            children: [
              // ───────────────────────────────────────────────
              // LEFT SIDEBAR: BRANDING & INFO (30%)
              // ───────────────────────────────────────────────
              Expanded(
                flex: 30,
                child: Container(
                  // ✅ FIX: Simple 20px padding all around + status bar
                  padding: EdgeInsets.fromLTRB(40, 20 + statusBarHeight, 40, 40),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ThemeConfig.primaryGreen,
                        ThemeConfig.secondaryGreen, // ✅ Verified
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LOGO AREA
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.coffee, color: Colors.white, size: 36),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            "COFFEA\nSUITE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 24,
                              letterSpacing: 2,
                              height: 1.0
                            ),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // CLOCK
                      const _LiveClockWidget(),
                      
                      const Spacer(),

                      // SYSTEM INFO CARD
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            // CLOUD SYNC
                            ValueListenableBuilder(
                              valueListenable: Hive.box<SyncQueueModel>('sync_queue').listenable(),
                              builder: (context, Box<SyncQueueModel> box, _) {
                                final count = box.length;
                                final isSynced = count == 0;
                                
                                return _InfoRow(
                                  icon: isSynced ? Icons.cloud_done : Icons.cloud_upload, 
                                  label: "Cloud Sync",
                                  valueWidget: Text(
                                    isSynced ? "ALL SYNCED" : "$count PENDING...",
                                    style: TextStyle(
                                      color: isSynced ? Colors.greenAccent : Colors.orangeAccent,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      fontSize: 20,
                                    ),
                                  ),
                                );
                              }
                            ),

                            const Divider(color: Colors.white12, height: 24),

                            // NETWORK STATUS
                            _InfoRow(
                              icon: Icons.wifi, 
                              label: "Network Status",
                              valueWidget: BlocBuilder<ConnectivityCubit, bool>(
                                builder: (context, isOnline) {
                                  return Text(
                                    isOnline ? "ONLINE" : "OFFLINE",
                                    style: TextStyle(
                                      color: isOnline ? Colors.greenAccent : Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                      fontSize: 20,
                                    ),
                                  );
                                }
                              ),
                            ),
                            
                            const Divider(color: Colors.white12, height: 24),
                            
                            // VERSION
                            _InfoRow(
                              icon: Icons.info_outline,
                              label: "System Version",
                              value: _version,
                            ),
                            
                            const Divider(color: Colors.white12, height: 24),
                            
                            // TERMINAL
                            _InfoRow(
                              icon: Icons.devices,
                              label: "Terminal ID",
                              value: "POS-01",
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ───────────────────────────────────────────────
              // RIGHT WORKSPACE: MODULE GRID (70%)
              // ───────────────────────────────────────────────
              Expanded(
                flex: 70,
                child: Container(
                  color: const Color(0xFFF5F7FA),
                  child: isLoggedIn 
                    ? Column(
                        children: [
                          // 1. ✅ UTILITY BAR (Simplified)
                          Container(
                            width: double.infinity,
                            // ✅ FIX: Simple padding logic. White BG extends to edges.
                            padding: EdgeInsets.fromLTRB(20, 20 + statusBarHeight, 20, 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2))
                              ]
                            ),
                            child: Row(
                              children: [
                                // USER PROFILE
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: ThemeConfig.primaryGreen.withOpacity(0.1),
                                  child: Text(
                                    user!.fullName[0].toUpperCase(),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen, fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87),
                                    ),
                                    Text(
                                      user.role.name.toUpperCase(),
                                      style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),

                                const Spacer(),

                                // ACTIONS
                                const _ManualPullButton(),
                                
                                const SizedBox(width: 20),
                                Container(width: 1, height: 40, color: Colors.grey.shade300),
                                const SizedBox(width: 20),

                                // LOGOUT
                                IconButton(
                                  onPressed: () {
                                    context.read<AuthBloc>().add(AuthLogoutRequested());
                                    Future.delayed(const Duration(milliseconds: 100), _showStartupLogin);
                                  },
                                  icon: const Icon(Icons.logout, color: Colors.grey, size: 28),
                                  tooltip: "Logout",
                                )
                              ],
                            ),
                          ),

                          // 2. MODULE GRID
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              padding: const EdgeInsets.all(40),
                              crossAxisSpacing: 30,
                              mainAxisSpacing: 30,
                              childAspectRatio: 1.6,
                              children: [
                                _ModuleCard(
                                  title: "Point of Sale",
                                  subtitle: "Process Orders",
                                  icon: Icons.point_of_sale,
                                  color: Colors.blue,
                                  onTap: () => Navigator.pushNamed(context, '/pos'),
                                ),
                                _ModuleCard(
                                  title: "Attendance",
                                  subtitle: "Time Clock & Logs",
                                  icon: Icons.access_time,
                                  color: Colors.orange,
                                  onTap: () => Navigator.pushNamed(context, '/attendance'),
                                ),
                                _ModuleCard(
                                  title: "Inventory",
                                  subtitle: "Stock & Recipes",
                                  icon: Icons.inventory_2,
                                  color: Colors.purple,
                                  onTap: () => Navigator.pushNamed(context, '/inventory'),
                                ),
                                _ModuleCard(
                                  title: "Admin Tools",
                                  subtitle: "Manage System",
                                  icon: Icons.admin_panel_settings,
                                  color: Colors.grey, 
                                  isLocked: !isAdmin, 
                                  onTap: () => Navigator.pushNamed(context, '/admin'),
                                ),
                              ],
                            ),
                          ),
                          
                          // FOOTER TEXT
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              "Select a module above to begin work.",
                              style: TextStyle(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                          )
                        ],
                      )
                    : const Center(child: CircularProgressIndicator()), 
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

// ──────────────── WIDGET COMPONENTS ────────────────

class _ManualPullButton extends StatefulWidget {
  const _ManualPullButton();

  @override
  State<_ManualPullButton> createState() => _ManualPullButtonState();
}

class _ManualPullButtonState extends State<_ManualPullButton> {
  bool _isLoading = false;

  Future<void> _pullData() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseSyncService.restoreFromCloud();
      if(mounted) DialogUtils.showToast(context, "Data updated from Cloud! ☁️");
    } catch (e) {
      if(mounted) DialogUtils.showToast(context, "Sync Error: $e", icon: Icons.error, accentColor: Colors.red);
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _isLoading ? null : _pullData,
      icon: _isLoading 
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh, size: 22),
      label: Text(
        _isLoading ? "Pulling..." : "Pull Data",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
      ),
      style: TextButton.styleFrom(
        foregroundColor: ThemeConfig.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: ThemeConfig.primaryGreen.withOpacity(0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
      ),
    );
  }
}

class _LiveClockWidget extends StatelessWidget {
  const _LiveClockWidget();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('hh:mm').format(now),
              style: const TextStyle(
                fontSize: 72,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.0,
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    DateFormat('a').format(now),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: ThemeConfig.primaryGreen,
                      fontSize: 20
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE, MMM d').format(now),
                  style: const TextStyle(
                    fontSize: 24,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        );
      }
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;

  const _InfoRow({
    required this.icon,
    required this.label,
    this.value,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 32),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 16)), 
            const SizedBox(height: 2),
            valueWidget ?? Text(value ?? "", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 20)),
          ],
        )
      ],
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLocked;

  const _ModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: isLocked ? 0 : 2,
      child: InkWell(
        onTap: isLocked ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isLocked ? Colors.grey[50] : null,
            border: Border.all(
              color: isLocked ? Colors.transparent : Colors.grey.shade200,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLocked ? Colors.grey[300] : color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLocked ? Icons.lock : icon,
                      color: isLocked ? Colors.grey : color,
                      size: 36,
                    ),
                  ),
                  if (!isLocked)
                    Icon(Icons.arrow_forward, color: Colors.grey[300], size: 28),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: isLocked ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isLocked ? "Access Restricted" : subtitle,
                    style: TextStyle(
                      color: isLocked ? Colors.grey : Colors.grey[600],
                      fontSize: 18,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}