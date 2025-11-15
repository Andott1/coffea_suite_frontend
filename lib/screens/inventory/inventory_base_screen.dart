/// <<FILE: lib/screens/inventory/inventory_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/utils/system_tab_memory.dart';

class InventoryBaseScreen extends StatefulWidget {
  const InventoryBaseScreen({super.key});

  @override
  State<InventoryBaseScreen> createState() => _InventoryBaseScreenState();
}

class _InventoryBaseScreenState extends State<InventoryBaseScreen> {
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _activeIndex = SystemTabMemory.getLastTab(CoffeaSystem.inventory);
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
    SystemTabMemory.setLastTab(CoffeaSystem.inventory, index);
  }

  final List<String> _tabs = const [
    "Overview",
    "Products",
    "Stock Adjustments",
  ];

  final List<Widget> _screens = const [
    InventoryOverviewScreen(),
    InventoryProductsScreen(),
    InventoryAdjustmentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.inventory,
        tabs: _tabs,
        adminOnlyTabs: const [false, false, true],
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

/// -----------------------------
/// TAB: Overview
/// -----------------------------
class InventoryOverviewScreen extends StatelessWidget {
  const InventoryOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Inventory Overview",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: const Center(
                child: Text(
                  "Analytics and Stock Summary Placeholder",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------
/// TAB: Products
/// -----------------------------
class InventoryProductsScreen extends StatelessWidget {
  const InventoryProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: "Search product...",
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: const Center(
                child: Text(
                  "Inventory Product Table Placeholder",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// -----------------------------
/// TAB: Stock Adjustments
/// -----------------------------
class InventoryAdjustmentsScreen extends StatelessWidget {
  const InventoryAdjustmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: Text(
            "Stock Adjustment Form Placeholder",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// <<END FILE>>