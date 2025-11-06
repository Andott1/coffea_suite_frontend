/// <<FILE: lib/screens/pos/pos_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';

class POSBaseScreen extends StatefulWidget {
  const POSBaseScreen({super.key});

  @override
  State<POSBaseScreen> createState() => _POSBaseScreenState();
}

class _POSBaseScreenState extends State<POSBaseScreen> {
  int activeTab = 1; // Default to "Cashier"

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.pos,
        tabs: const ["Dashboard", "Cashier", "History"],
        activeIndex: activeTab,
        onTabSelected: (index) {
          setState(() => activeTab = index);
          // Future: Implement view switching here
        },
        showOnlineStatus: true,
        showUserMode: true,
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.all(12),
              child: const Center(
                child: Text("Product Selector Grid Placeholder"),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.white,
              margin: const EdgeInsets.all(12),
              child: const Center(
                child: Text("Order Summary Panel Placeholder"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
/// <<END FILE>>