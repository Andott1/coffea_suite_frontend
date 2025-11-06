/// <<FILE: lib/screens/admin/admin_base_screen.dart>>
import 'package:flutter/material.dart';
import '../../core/widgets/master_topbar.dart';

class AdminBaseScreen extends StatefulWidget {
  const AdminBaseScreen({super.key});

  @override
  State<AdminBaseScreen> createState() => _AdminBaseScreenState();
}

class _AdminBaseScreenState extends State<AdminBaseScreen> {
  int activeTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.admin,
        tabs: const ["Analytics", "Employees", "Products", "Ingredients", "Settings"],
        activeIndex: activeTab,
        onTabSelected: (index) {
          setState(() => activeTab = index);
        },
        showOnlineStatus: true,
        showUserMode: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _AdminToolCard(
              icon: Icons.analytics,
              label: "Analytics",
              color: Colors.green,
              onTap: () {},
            ),
            _AdminToolCard(
              icon: Icons.people_alt,
              label: "Manage Employees",
              color: Colors.blue,
              onTap: () {},
            ),
            _AdminToolCard(
              icon: Icons.coffee,
              label: "Manage Products",
              color: Colors.brown,
              onTap: () {},
            ),
            _AdminToolCard(
              icon: Icons.inventory,
              label: "Manage Ingredients",
              color: Colors.orange,
              onTap: () {},
            ),
            _AdminToolCard(
              icon: Icons.settings,
              label: "Settings",
              color: Colors.grey,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

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
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 36, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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