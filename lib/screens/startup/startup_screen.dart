/// <<FILE: lib/screens/startup/startup_screen.dart>>
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/user_model.dart'; // for UserRoleLevel
import '../../core/services/session_user.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/widgets/container_card_titled.dart';
import '../../core/widgets/login_dialog.dart'; // import login dialog

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {

  @override
  void initState() {
    super.initState();
    // 1. Trigger Login Dialog on startup if not logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!SessionUser.isLoggedIn) {
        _showStartupLogin();
      }
    });
  }

  void _showStartupLogin() async {
    await showDialog(
      context: context,
      barrierDismissible: false, // Force login
      builder: (_) => const LoginDialog(isStartup: true),
    );
    setState(() {}); // Refresh UI after login
  }

  @override
  Widget build(BuildContext context) {
    // 2. Listen to Session Changes
    return Consumer<SessionUserNotifier>(
      builder: (context, notifier, child) {
        final user = SessionUser.current;
        final role = user?.role ?? UserRoleLevel.employee;
        final isLoggedIn = SessionUser.isLoggedIn;

        return Scaffold(
          backgroundColor: ThemeConfig.white,
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              Column(
                children: [
                  const MasterTopBar(
                    system: CoffeaSystem.startup,
                    showTabs: false,
                    showBackButton: false,
                    showUserMode: true, // Shows "Switch User" button now
                  ),

                  Expanded(
                    child: Container(
                      color: const Color(0xFFF6F6F6),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 200, vertical: 60),
                        child: ContainerCardTitled(
                          title: isLoggedIn ? "Welcome, ${user!.fullName}" : "Please Login",
                          subtitle: isLoggedIn ? "Select a system to proceed" : "",
                          centerTitle: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final double maxWidth = constraints.maxWidth;
                                const double gap = 20;
                                final double buttonWidth = (maxWidth - gap * 3) / 2;

                                return Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: gap,
                                  runSpacing: gap,
                                  children: [
                                    _SystemButton(
                                      label: "Point of Sale",
                                      icon: Icons.point_of_sale,
                                      onTap: () => Navigator.pushNamed(context, '/pos'),
                                      disabled: !isLoggedIn, // Everyone can access POS if logged in
                                      width: buttonWidth,
                                    ),
                                    _SystemButton(
                                      label: "Attendance",
                                      icon: Icons.access_time,
                                      onTap: () => Navigator.pushNamed(context, '/attendance'),
                                      disabled: !isLoggedIn, 
                                      width: buttonWidth,
                                    ),
                                    _SystemButton(
                                      label: "Inventory",
                                      icon: Icons.inventory_2,
                                      onTap: () => Navigator.pushNamed(context, '/inventory'),
                                      // Only Manager or Admin
                                      disabled: !isLoggedIn, 
                                      width: buttonWidth,
                                    ),
                                    _SystemButton(
                                      label: "Admin Tools",
                                      icon: Icons.admin_panel_settings,
                                      // Only Admin
                                      disabled: !isLoggedIn || role != UserRoleLevel.admin,
                                      onTap: () => Navigator.pushNamed(context, '/admin'),
                                      width: buttonWidth,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Bottom Bar
                  Container(
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: ThemeConfig.lightGray)),
                    ),
                    child: Center(
                      child: Text(
                        "v1.0.2i   •   Coffea System Suite   •   ${isLoggedIn ? 'Logged in as ${user!.username}' : 'Not Logged In'}",
                        style: FontConfig.caption(context),
                      ),
                    ),
                  )
                ],
              ),

              // Overlay if not logged in (Double security visual)
              if (!isLoggedIn)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: CircularProgressIndicator()),
                )
            ],
          ),
        );
      },
    );
  }
}

class _SystemButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;
  final double? width;

  const _SystemButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.disabled = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: disabled ? Colors.grey[300] : ThemeConfig.primaryGreen,
      borderRadius: BorderRadius.circular(16),
      elevation: disabled ? 0 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onTap,
        child: Container(
          width: width,
          height: 140,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: disabled ? Colors.grey[600] : Colors.white, size: 40),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.grey[600] : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
/// <<END FILE>>