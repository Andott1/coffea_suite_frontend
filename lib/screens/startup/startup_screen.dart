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
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double fullScreenHeight = MediaQuery.of(context).size.height;

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
              // LEFT SIDEBAR (30%)
              // ───────────────────────────────────────────────
              Expanded(
                flex: 30,
                child: Container(
                  // Use BoxDecoration for the gradient (remains static)
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        ThemeConfig.primaryGreen,
                        ThemeConfig.secondaryGreen, 
                      ],
                    ),
                  ),
                  // ✅ FIX: Wrap content in ScrollView + SizedBox to ignore keyboard resize
                  child: SingleChildScrollView(
                    physics: const NeverScrollableScrollPhysics(), // Disable user scrolling
                    child: SizedBox(
                      height: fullScreenHeight, // Force full height
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(40, statusBarHeight + 20, 40, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LOGO AREA
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
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
                                  _InfoRow(icon: Icons.info_outline, label: "System Version", value: _version),
                                  const Divider(color: Colors.white12, height: 24),
                                  _InfoRow(icon: Icons.devices, label: "Terminal ID", value: "POS-01"),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ───────────────────────────────────────────────
              // RIGHT WORKSPACE (70%)
              // ───────────────────────────────────────────────
              Expanded(
                flex: 70,
                child: Container(
                  color: const Color.fromARGB(255, 243, 243, 243),
                  child: isLoggedIn 
                    ? Column(
                        children: [
                          // UTILITY BAR
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(20, 20 + statusBarHeight, 20, 20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5, offset: const Offset(0, 2))
                              ]
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: ThemeConfig.primaryGreen.withValues(alpha: 0.1),
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
                                const _ManualPullButton(),
                                const SizedBox(width: 20),
                                Container(width: 1, height: 40, color: Colors.grey.shade300),
                                const SizedBox(width: 20),
                                TextButton.icon(
                                  onPressed: () {
                                    context.read<AuthBloc>().add(AuthLogoutRequested());
                                    Future.delayed(const Duration(milliseconds: 100), _showStartupLogin);
                                  },
                                  icon: Icon(Icons.logout, size: 20, color: Colors.red.shade700),
                                  label: Text(
                                    "Logout",
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.red.shade50,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                )
                              ],
                            ),
                          ),

                          // MODULE GRID
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
                          
                          Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: Text(
                              "Select a module above to begin work.",
                              style: TextStyle(color: Colors.grey[500], fontSize: 18, fontWeight: FontWeight.w400),
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

// ✅ REDESIGNED: Watermarked "Big Button" Card
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
      borderRadius: BorderRadius.circular(24), // Softer corners
      elevation: isLocked ? 0 : 5, // Higher elevation for pop
      shadowColor: isLocked ? Colors.transparent : color.withValues(alpha: 0.25), // Colored shadow
      child: InkWell(
        onTap: isLocked ? null : onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isLocked ? Colors.grey.shade200 : color.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias, // Clip the watermark
          child: Stack(
            children: [
              // 1. WATERMARK ICON (Background Decoration)
              if (!isLocked)
                Positioned(
                  bottom: -30,
                  right: -30,
                  child: Transform.rotate(
                    angle: -0.2, // Stylish tilt
                    child: Icon(
                      icon,
                      size: 160, // Huge size for background texture
                      color: color.withValues(alpha: 0.1), // Very subtle watermark
                    ),
                  ),
                ),

              // 2. MAIN CONTENT
              Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // TOP ROW
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Icon Badge
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isLocked ? Colors.grey[200] : color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            isLocked ? Icons.lock : icon,
                            color: isLocked ? Colors.grey : color,
                            size: 34,
                          ),
                        ),
                        
                        // Action Arrow
                        if (!isLocked)
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade50,
                            ),
                            child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[400], size: 32),
                          ),
                      ],
                    ),

                    // BOTTOM TEXT
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.w700,
                            color: isLocked ? Colors.grey : Colors.black87,
                            height: 1.1
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isLocked ? "Restricted Access" : subtitle,
                          style: TextStyle(
                            color: isLocked ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 18,
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... (Rest of _ManualPullButton, _LiveClockWidget, _InfoRow remains same)

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
      if(mounted) DialogUtils.showToast(context, "Data updated from Cloud!");
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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