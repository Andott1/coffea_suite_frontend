import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../utils/responsive.dart';
import '../../config/role_config.dart';
import '../utils/dialog_utils.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final int activeIndex;
  final Function(int) onNavTap;
  final bool showUserMode;
  final bool showBackButton;
  final List<String> tabLabels;
  final List<IconData> tabIcons;
  final VoidCallback? onRoleChanged;

  const TopBar({
    super.key,
    required this.activeIndex,
    required this.onNavTap,
    required this.tabLabels,
    required this.tabIcons,
    this.showUserMode = true,
    this.showBackButton = true,
    this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final double topBarHeight = preferredSize.height;

    return Container(
      height: topBarHeight + statusBarHeight,
      width: double.infinity,
      padding: EdgeInsets.only(
        top: statusBarHeight,
        left: r.wp(2),
        right: r.wp(2),
      ),
      decoration: const BoxDecoration(
        color: ThemeConfig.white,
        border: Border(
          bottom: BorderSide(color: ThemeConfig.lightGray, width: 2),
        ),
      ),
      child: Row(
        children: [
          // 🟩 COLUMN 1 — Back button
          SizedBox(
            width: r.wp(10), // fixed width column for back button
            child: Align(
              alignment: Alignment.centerLeft,
              child: showBackButton
                  ? IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: ThemeConfig.primaryGreen,
                      ),
                      iconSize: r.scale(26),
                      onPressed: () => Navigator.pop(context),
                    )
                  : Image.asset(
                      'assets/logo/coffea.png',
                      height: r.hp(5),
                      fit: BoxFit.contain,
                    ),
            ),
          ),

          // 🟦 COLUMN 2 — Navigation Tabs (centered)
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(tabLabels.length, (index) {
                  final isActive = index == activeIndex;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.wp(1)),
                    child: _NavButton(
                      label: tabLabels[index],
                      icon: tabIcons[index],
                      isActive: isActive,
                      onTap: () => onNavTap(index),
                    ),
                  );
                }),
              ),
            ),
          ),

          // 🟧 COLUMN 3 — Status + Role Switcher (right side)
          SizedBox(
            width: r.wp(18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const _OnlineIndicator(),
                SizedBox(width: r.wp(1.5)),
                if (showUserMode)
                  _UserModeSwitcher(onRoleChanged: onRoleChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

// ======================================================================
// NAV BUTTON
// ======================================================================
class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final Color activeColor = ThemeConfig.primaryGreen;
    final Color inactiveColor = const Color(0xFFAAAAAA);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r.scale(6)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.wp(0.8), vertical: r.hp(0.4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : inactiveColor, size: r.scale(20)),
            SizedBox(height: r.hp(0.3)),
            Text(
              label,
              style: FontConfig.body(context).copyWith(
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: r.font(15),
              ),
            ),
            if (isActive)
              Container(
                margin: EdgeInsets.only(top: r.hp(0.3)),
                height: r.scale(3),
                width: r.wp(5),
                color: activeColor,
              ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// ONLINE INDICATOR
// ======================================================================
class _OnlineIndicator extends StatefulWidget {
  const _OnlineIndicator();

  @override
  State<_OnlineIndicator> createState() => _OnlineIndicatorState();
}

class _OnlineIndicatorState extends State<_OnlineIndicator> {
  bool isOnline = true;

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return GestureDetector(
      onTap: () => setState(() => isOnline = !isOnline),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.wp(1.5),
          vertical: r.hp(0.5),
        ),
        decoration: BoxDecoration(
          color: ThemeConfig.white,
          borderRadius: BorderRadius.circular(r.scale(6)),
          border: Border.all(color: ThemeConfig.primaryGreen, width: 2),
        ),
        child: Row(
          children: [
            Icon(
              isOnline ? Icons.wifi : Icons.wifi_off,
              color: ThemeConfig.primaryGreen,
              size: r.scale(16),
            ),
            SizedBox(width: r.wp(0.8)),
            Text(
              isOnline ? "Online" : "Offline",
              style: FontConfig.body(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// USER MODE SWITCHER
// ======================================================================
class _UserModeSwitcher extends StatefulWidget {
  final VoidCallback? onRoleChanged;
  const _UserModeSwitcher({this.onRoleChanged, super.key});

  @override
  State<_UserModeSwitcher> createState() => _UserModeSwitcherState();
}

class _UserModeSwitcherState extends State<_UserModeSwitcher> {
  late bool isAdmin;

  @override
  void initState() {
    super.initState();
    isAdmin = context.read<RoleConfig>().isAdmin;
  }

  void _toggleRole() {
    final roleManager = context.read<RoleConfig>();
    roleManager.toggleRole();

    setState(() {
      isAdmin = roleManager.isAdmin;
    });

    widget.onRoleChanged?.call();

    final message =
        isAdmin ? "Switched to Admin Mode" : "Switched to Employee Mode";
    DialogUtils.showToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return GestureDetector(
      onTap: _toggleRole,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.wp(1.8),
          vertical: r.hp(0.5),
        ),
        decoration: BoxDecoration(
          color: ThemeConfig.white,
          borderRadius: BorderRadius.circular(r.scale(6)),
          border: Border.all(color: ThemeConfig.primaryGreen, width: 2),
        ),
        child: Text(
          isAdmin ? "ADMIN" : "EMPLOYEE",
          style: FontConfig.body(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
