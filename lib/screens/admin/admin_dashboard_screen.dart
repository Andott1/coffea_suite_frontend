/// <<FILE: lib/screens/admin/admin_dashboard_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/topbar.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/utils/responsive.dart';
import 'analytics_screen.dart';
import 'employee_management_screen.dart';
import 'settings_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int activeIndex = -1; // no active nav tab on this screen

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: ThemeConfig.white,
      appBar: TopBar(
        activeIndex: activeIndex,
        onNavTap: (index) {},
        tabLabels: const [],
        tabIcons: const [],
        showUserMode: true,
        showBackButton: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(r.wp(4)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Admin Tools Dashboard",
                style: FontConfig.h2(context).copyWith(
                  fontWeight: FontWeight.bold,
                  color: ThemeConfig.primaryGreen,
                ),
              ),
              SizedBox(height: r.hp(2)),

              // Grid layout for Admin Tools
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: r.isTablet ? 3 : 2,
                crossAxisSpacing: r.wp(3),
                mainAxisSpacing: r.hp(2),
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _AdminToolCard(
                    icon: Icons.people_alt,
                    label: "Employee Management",
                    color: Colors.blue.shade400,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const EmployeeManagementScreen()),
                      );
                    },
                  ),
                  _AdminToolCard(
                    icon: Icons.bar_chart,
                    label: "Analytics",
                    color: Colors.green.shade500,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AnalyticsScreen()),
                      );
                    },
                  ),
                  _AdminToolCard(
                    icon: Icons.settings,
                    label: "Settings",
                    color: Colors.grey.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ADMIN TOOL CARD COMPONENT
// ---------------------------------------------------------------------------
class _AdminToolCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminToolCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: r.scale(40)),
                SizedBox(height: r.hp(1)),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: FontConfig.body(context).copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: r.font(15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
/// <<END FILE>>