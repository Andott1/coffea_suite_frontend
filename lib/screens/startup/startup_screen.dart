import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/utils/responsive.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return Scaffold(
      backgroundColor: ThemeConfig.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: r.wp(5)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // App Logo
                Image.asset(
                  'assets/logo/coffea.png',
                  height: r.hp(20), // 20% of screen height
                  fit: BoxFit.contain,
                ),

                SizedBox(height: r.hp(3)),

                Text(
                  'Select System',
                  style: FontConfig.h1(context).copyWith(fontSize: r.font(28)),
                ),

                SizedBox(height: r.hp(4)),

                // System Buttons Grid
                Wrap(
                  spacing: r.wp(2),
                  runSpacing: r.hp(2),
                  alignment: WrapAlignment.center,
                  children: [
                    _SystemButton(
                      label: 'POS System',
                      icon: Icons.point_of_sale,
                      width: r.wp(35),
                      height: r.hp(18),
                      onTap: () => Navigator.pushNamed(context, '/pos'),
                    ),
                    _SystemButton(
                      label: 'Attendance',
                      icon: Icons.access_time,
                      width: r.wp(35),
                      height: r.hp(18),
                      onTap: () => Navigator.pushNamed(context, '/attendance'),
                    ),
                    _SystemButton(
                      label: 'Admin Tools',
                      icon: Icons.admin_panel_settings,
                      width: r.wp(35),
                      height: r.hp(18),
                      onTap: () => Navigator.pushNamed(context, '/admin'),
                    ),
                    _SystemButton(
                      label: 'Inventory',
                      icon: Icons.inventory_2,
                      width: r.wp(35),
                      height: r.hp(18),
                      onTap: () => Navigator.pushNamed(context, '/inventory'),
                    ),
                  ],
                ),

                const Spacer(),

                Padding(
                  padding: EdgeInsets.symmetric(vertical: r.hp(2)),
                  child: Column(
                    children: [
                      const Divider(
                        thickness: 1,
                        color: ThemeConfig.lightGray,
                      ),
                      SizedBox(height: r.hp(1)),
                      Text(
                        'v1.0.0   Coffea POS Suite',
                        style: FontConfig.caption(context),
                      ),
                    ],
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

class _SystemButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final double width;
  final double height;
  final VoidCallback onTap;

  const _SystemButton({
    required this.label,
    required this.icon,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.scale(12)),
      child: Ink(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: ThemeConfig.primaryGreen,
          borderRadius: BorderRadius.circular(r.scale(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: r.scale(8),
              offset: Offset(0, r.scale(4)),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: r.scale(36),
              color: ThemeConfig.white,
            ),
            SizedBox(height: r.hp(1.2)),
            Text(
              label,
              style: FontConfig.button(context).copyWith(
                fontSize: r.font(18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
