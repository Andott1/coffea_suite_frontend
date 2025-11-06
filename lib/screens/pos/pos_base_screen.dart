/// <<FILE: lib/screens/pos/pos_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';

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
    _activeIndex = SystemTabMemory.getLastTab(CoffeaSystem.pos, defaultIndex: 1);
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.pos, index);
  }

  final List<String> _tabs = const [
    "Dashboard",
    "Cashier",
    "History",
  ];

  final List<Widget> _screens = const [
    POSDashboardScreen(),
    POSCashierScreen(),
    POSHistoryScreen(),
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
      body: IndexedStack(
        index: _activeIndex,
        children: _screens,
      ),
    );
  }
}

// Placeholder screens — these will later be replaced by real implementations.
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

class POSCashierScreen extends StatelessWidget {
  const POSCashierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(12),
            color: Colors.white,
            child: const Center(child: Text("Product Selector Grid Placeholder")),
          ),
        ),
        Expanded(
          flex: 2,
          child: Container(
            margin: const EdgeInsets.all(12),
            color: Colors.white,
            child: const Center(child: Text("Order Summary Panel Placeholder")),
          ),
        ),
      ],
    );
  }
}

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