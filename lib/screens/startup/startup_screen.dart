import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../config/role_config.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/widgets/container_card_titled.dart';
import 'package:provider/provider.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  void _toggleRole(BuildContext context) {
    final roleManager = context.read<RoleConfig>();
    roleManager.toggleRole();

    final message = roleManager.isAdmin
        ? "Switched to Admin Mode"
        : "Switched to Employee Mode";
    DialogUtils.showToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoleConfig>(
      builder: (context, roleManager, child) {
        final isAdmin = roleManager.isAdmin;

        return Scaffold(
          backgroundColor: ThemeConfig.white,
          body: Column(
            children: [
              // ──────── TOP BAR ────────
              MasterTopBar(
                system: CoffeaSystem.startup,
                showTabs: false,
                showBackButton: false,
              ),

              // ──────── MIDDLE SECTION ────────
              Expanded(
                child: Container(
                  color: const Color(0xFFF6F6F6),
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 260, vertical: 60),
                    child: ContainerCardTitled(
                      title: "Select System",
                      centerTitle: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 20,
                      ),

                      child: SizedBox(
                        width: double.infinity,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double maxWidth = constraints.maxWidth;
                            const double horizontalGap = 20;
                            const double verticalGap = 20;

                            final double buttonWidth =
                                (maxWidth - horizontalGap * 3) / 2;

                            return Wrap(
                              alignment: WrapAlignment.center,
                              runAlignment: WrapAlignment.center,
                              spacing: horizontalGap,
                              runSpacing: verticalGap,
                              children: [
                                _SystemButton(
                                  label: "Point of Sale",
                                  icon: Icons.point_of_sale,
                                  onTap: () => Navigator.pushNamed(context, '/pos'),
                                  width: buttonWidth,
                                ),
                                _SystemButton(
                                  label: "Attendance",
                                  icon: Icons.access_time,
                                  onTap: () => Navigator.pushNamed(context, '/attendance'),
                                  width: buttonWidth,
                                ),
                                _SystemButton(
                                  label: "Inventory",
                                  icon: Icons.inventory_2,
                                  onTap: () => Navigator.pushNamed(context, '/inventory'),
                                  width: buttonWidth,
                                ),
                                _SystemButton(
                                  label: "Admin Tools",
                                  icon: Icons.admin_panel_settings,
                                  onTap: roleManager.isAdmin
                                      ? () => Navigator.pushNamed(context, '/admin')
                                      : null,
                                  disabled: !roleManager.isAdmin,
                                  width: buttonWidth,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  )
                ),
              ),

              // ──────── BOTTOM BAR ────────
              Container(
                height: 64,
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: ThemeConfig.white,
                  border: Border(
                    top: BorderSide(
                      color: ThemeConfig.lightGray,
                      width: 2,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    "v1.0.0   •   Coffea System Suite",
                    style: FontConfig.body(context).copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────────────
// System Button Widget (with ripple)
// ───────────────────────────────
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
      color: disabled ? Colors.grey[200] : ThemeConfig.primaryGreen,
      borderRadius: BorderRadius.circular(20),
      elevation: disabled ? 0 : 4,
      shadowColor:
          disabled ? Colors.transparent : ThemeConfig.primaryGreen.withOpacity(0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: disabled ? null : onTap,
        child: Container(
          width: width,
          height: 160,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: disabled ? Colors.grey : Colors.white,
                size: 38,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: disabled ? Colors.grey : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
