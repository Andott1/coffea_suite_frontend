/// <<FILE: lib/screens/inventory/inventory_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';

class InventoryBaseScreen extends StatefulWidget {
  const InventoryBaseScreen({super.key});

  @override
  State<InventoryBaseScreen> createState() => _InventoryBaseScreenState();
}

class _InventoryBaseScreenState extends State<InventoryBaseScreen> {
  int activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.inventory,
        tabs: const ["Overview", "Products", "Stock Adjustments"],
        activeIndex: activeTab,
        onTabSelected: (index) {
          setState(() => activeTab = index);
        },
        showOnlineStatus: true,
        showUserMode: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: "Search inventory...",
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
                color: Colors.white,
                child: const Center(
                  child: Text("Inventory Table Placeholder"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// <<END FILE>>