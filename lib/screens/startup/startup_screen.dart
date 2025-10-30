import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../config/role_config.dart';
import '../../core/utils/dialog_utils.dart';
import 'package:provider/provider.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  late bool isAdmin;

  void _toggleRole(BuildContext context) {
  final roleManager = context.read<RoleConfig>();
  roleManager.toggleRole();

  final message = roleManager.isAdmin
      ? "☕ Switched to Admin Mode"
      : "👤 Switched to Employee Mode";
  DialogUtils.showToast(context, message);
}

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleConfig>(
      builder: (context, roleManager, child) {
        final isAdmin = roleManager.isAdmin;

        return Scaffold(
          backgroundColor: ThemeConfig.white,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select System",
                        style: FontConfig.h1(context).copyWith(
                          color: ThemeConfig.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleRole(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: ThemeConfig.primaryGreen, width: 2),
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isAdmin
                                    ? Icons.admin_panel_settings
                                    : Icons.person,
                                color: ThemeConfig.primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isAdmin ? "ADMIN" : "EMPLOYEE",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: ThemeConfig.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 30,
                      mainAxisSpacing: 30,
                      children: [
                        _SystemButton(
                          label: "POS System",
                          icon: Icons.point_of_sale,
                          onTap: () => Navigator.pushNamed(context, '/pos'),
                        ),
                        _SystemButton(
                          label: "Attendance",
                          icon: Icons.access_time,
                          onTap: () =>
                              Navigator.pushNamed(context, '/attendance'),
                        ),
                        _SystemButton(
                          label: "Inventory",
                          icon: Icons.inventory_2,
                          onTap: () =>
                              Navigator.pushNamed(context, '/inventory'),
                        ),
                        _SystemButton(
                          label: "Admin Tools",
                          icon: Icons.admin_panel_settings,
                          onTap: isAdmin
                              ? () => Navigator.pushNamed(context, '/admin')
                              : null,
                          disabled: !isAdmin,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  Text(
                    "v1.0.0   •   Coffea POS Suite",
                    style: FontConfig.body(context).copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────────────
// System Button Widget
// ───────────────────────────────
class _SystemButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool disabled;

  const _SystemButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey[200] : ThemeConfig.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!disabled)
              BoxShadow(
                color: ThemeConfig.primaryGreen.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: disabled ? Colors.grey : Colors.white,
                size: 42,
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.grey : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
