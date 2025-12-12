import 'package:flutter/material.dart';
import '../../core/widgets/session_guard.dart';
import 'modern_sidebar.dart';
import '../enums/coffea_system.dart'; // ✅ Add this

class ModernScaffold extends StatelessWidget {
  final CoffeaSystem system;
  final List<String> currentTabs;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final Widget body;
  final bool resizeToAvoidBottomInset;

  const ModernScaffold({
    super.key,
    required this.system,
    required this.currentTabs,
    required this.activeIndex,
    required this.onTabSelected,
    required this.body,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Wrap in SessionGuard so user switching works globally
    return SessionGuard(
      onUserChanged: () {
        // Trigger a rebuild or navigation if needed
        // (Usually handled by parent SetState, but this keeps the guard active)
      },
      child: Scaffold(
        backgroundColor: Colors.white, // Content area is pure white
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── LEFT: SIDEBAR ───
            ModernSidebar(
              system: system,
              tabs: currentTabs,
              activeIndex: activeIndex,
              onTabSelected: onTabSelected,
              onBack: () => Navigator.maybePop(context),
            ),

            // ─── RIGHT: CONTENT ───
            Expanded(
              // Using a Container with a border to crisply separate content
              child: Container(
                padding: const EdgeInsets.only(top: 24),
                decoration: BoxDecoration(
                  border: Border(left: BorderSide(color: Colors.grey.shade200)),
                ),
                child: body,
              ),
            ),
          ],
        ),
      ),
    );
  }
}