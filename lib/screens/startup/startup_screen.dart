import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/models/user_model.dart';
import '../../core/services/session_user.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/master_topbar.dart';
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final isLoggedIn = state is AuthAuthenticated;
        UserModel? user;
        if (state is AuthAuthenticated) user = state.user;
        
        final role = user?.role ?? UserRoleLevel.employee;
        final theme = Theme.of(context);

        return Scaffold(
           backgroundColor: theme.scaffoldBackgroundColor,
           resizeToAvoidBottomInset: false,
           body: Stack(
             children: [
               Column(
                 children: [
                    // TOP BAR
                    const MasterTopBar(
                      system: CoffeaSystem.startup,
                      showTabs: false,
                      showBackButton: false,
                      showUserMode: true,
                    ),

                    // MAIN CONTENT AREA
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF6F6F6),
                        alignment: Alignment.center,
                        // Keep ScrollView for landscape support
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.symmetric(
                            // Responsive Padding to keep card centered but safe
                            vertical: r.hp(5).clamp(20, 60), 
                            horizontal: r.wp(10).clamp(20, 200)
                          ),
                          child: Card(
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // HEADER
                                  Text(
                                    isLoggedIn ? "Welcome, ${user!.fullName}" : "Please Login",
                                    style: FontConfig.h3(context).copyWith(color: theme.primaryColor),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (isLoggedIn) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      "Select a system to proceed",
                                      style: FontConfig.body(context).copyWith(color: Colors.grey),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  
                                  const SizedBox(height: 30),

                                  // BUTTON GRID (WRAP)
                                  SizedBox(
                                    width: double.infinity,
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final double maxWidth = constraints.maxWidth;
                                        const double gap = 20;
                                        
                                        // Force 2 columns: (Available Width - Gap) / 2
                                        // Floor to double prevents sub-pixel wrapping issues
                                        final double buttonWidth = ((maxWidth - gap) / 2).floorToDouble();

                                        return Wrap(
                                          alignment: WrapAlignment.center,
                                          spacing: gap,
                                          runSpacing: gap,
                                          children: [
                                            _SystemButton(
                                              label: "Point of Sale",
                                              icon: Icons.point_of_sale,
                                              onTap: () => Navigator.pushNamed(context, '/pos'),
                                              disabled: !isLoggedIn, 
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
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // BOTTOM BAR
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: theme.dividerColor)),
                      ),
                      child: Center(
                        child: Text(
                          "$_version   •   Coffea System Suite",
                          style: FontConfig.caption(context),
                        ),
                      ),
                    )
                 ]
               ),
               
               if (!isLoggedIn)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(child: CircularProgressIndicator()),
                )
             ]
           )
        );
      }
    );
  }
}

class _SystemButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;
  final double? width; // ✅ Restored width

  const _SystemButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.disabled = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: disabled ? theme.disabledColor : colorScheme.primary,
      borderRadius: BorderRadius.circular(16),
      elevation: disabled ? 0 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onTap,
        child: Container(
          width: width, // ✅ Applied width
          height: 140,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                color: disabled ? Colors.grey[600] : colorScheme.onPrimary, 
                size: 40
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.grey[600] : colorScheme.onPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600
                ),
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
    );
  }
}