import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../utils/responsive.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final int activeIndex;
  final Function(int) onNavTap;
  final bool showUserMode;
  final bool showBackButton;
  final List<String> tabLabels;
  final List<IconData> tabIcons;

  const TopBar({
    super.key,
    required this.activeIndex,
    required this.onNavTap,
    required this.tabLabels,
    required this.tabIcons,
    this.showUserMode = true,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final double statusBarHeight = MediaQuery.of(context).padding.top; // 👈 Dynamic padding for notification bar

    return Container(
      // Total height = TopBar height + status bar padding
      height: preferredSize.height + statusBarHeight,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: ThemeConfig.white,
        border: Border(
          bottom: BorderSide(color: ThemeConfig.lightGray, width: 2),
        ),
      ),
      padding: EdgeInsets.only(
        top: statusBarHeight, // 👈 This ensures TopBar starts below notif bar
        left: r.wp(2),
        right: r.wp(2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LEFT: Logo or Back Button
          Row(
            children: [
              if (showBackButton)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: ThemeConfig.primaryGreen),
                  iconSize: r.scale(24),
                  onPressed: () => Navigator.pop(context),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: r.hp(0.8)),
                  child: Image.asset(
                    'assets/logo/coffea.png',
                    height: r.hp(5.5),
                    fit: BoxFit.contain,
                  ),
                ),
            ],
          ),

          // CENTER: Tabs (if available)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(tabLabels.length, (index) {
                final isActive = index == activeIndex;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: r.wp(0.8)),
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

          // RIGHT: Online Status + Role
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _OnlineIndicator(),
              SizedBox(width: r.wp(2)),
              if (showUserMode) const _UserModeSwitcher(),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}

// ---------------------------------------------------------------------------
// NAV BUTTON
// ---------------------------------------------------------------------------

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
      borderRadius: BorderRadius.circular(r.scale(8)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.wp(1.2), vertical: r.hp(0.4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? activeColor : inactiveColor, size: r.scale(20)),
            SizedBox(height: r.hp(0.4)),
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
                margin: EdgeInsets.only(top: r.hp(0.4)),
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

// ---------------------------------------------------------------------------
// ONLINE INDICATOR
// ---------------------------------------------------------------------------

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
          vertical: r.hp(0.6),
        ),
        decoration: BoxDecoration(
          color: ThemeConfig.white,
          borderRadius: BorderRadius.circular(r.scale(8)),
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

// ---------------------------------------------------------------------------
// USER MODE SWITCHER
// ---------------------------------------------------------------------------

class _UserModeSwitcher extends StatefulWidget {
  const _UserModeSwitcher();

  @override
  State<_UserModeSwitcher> createState() => _UserModeSwitcherState();
}

class _UserModeSwitcherState extends State<_UserModeSwitcher> {
  bool isAdmin = true;

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);

    return GestureDetector(
      onTap: () => setState(() => isAdmin = !isAdmin),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: r.wp(2),
          vertical: r.hp(0.7),
        ),
        decoration: BoxDecoration(
          color: ThemeConfig.white,
          borderRadius: BorderRadius.circular(r.scale(8)),
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
