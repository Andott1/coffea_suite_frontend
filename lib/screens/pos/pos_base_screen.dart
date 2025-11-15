/// <<FILE: lib/screens/pos/pos_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';
import 'cashier_screen.dart'; // Import your existing CashierScreen

class POSBaseScreen extends StatefulWidget {
  const POSBaseScreen({super.key});

  @override
  State<POSBaseScreen> createState() => _POSBaseScreenState();
}

class _POSBaseScreenState extends State<POSBaseScreen> {
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = SystemTabMemory.getLastTab(
      CoffeaSystem.pos,
      defaultIndex: 1,
    );
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.pos, index);
  }

  final List<String> _tabs = const ["Dashboard", "Cashier", "History"];

  // Screens: Replace POSCashierScreen placeholder with actual CashierScreen
  late final List<Widget> _screens = [
    const POSDashboardScreen(),
    const CashierScreen(),
    const POSHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.pos,
        tabs: _tabs,
        adminOnlyTabs: const [false, false, false],
        activeIndex: _activeIndex,
        onTabSelected: _onTabChanged,
        showOnlineStatus: true,
        showUserMode: true,
      ),
      body: IndexedStack(index: _activeIndex, children: _screens),
    );
  }
}

// Dashboard placeholder
class POSDashboardScreen extends StatelessWidget {
  const POSDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "POS Dashboard Screen",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// History placeholder
class POSHistoryScreen extends StatelessWidget {
  const POSHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Transaction History Placeholder",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// <<END FILE>>
