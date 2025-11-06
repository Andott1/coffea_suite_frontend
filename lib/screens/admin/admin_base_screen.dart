/// <<FILE: lib/screens/admin/admin_base_screen.dart>>
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/master_topbar.dart';
import '../../config/role_config.dart';

class AdminBaseScreen extends StatefulWidget {
  const AdminBaseScreen({super.key});

  @override
  State<AdminBaseScreen> createState() => _AdminBaseScreenState();
}

class _AdminBaseScreenState extends State<AdminBaseScreen> {
  int _activeIndex = 0;
  late RoleConfig _roleManager;
  late VoidCallback _roleListener;

  final List<String> _tabs = const [
    "Analytics",
    "Employees",
    "Products",
    "Ingredients",
    "Settings",
  ];

  final List<Widget> _screens = const [
    AdminAnalyticsScreen(),
    AdminEmployeesScreen(),
    AdminProductsScreen(),
    AdminIngredientsScreen(),
    AdminSettingsScreen(),
  ];

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
  }

  @override
  void initState() {
    super.initState();

    // Attach role change listener
    _roleManager = RoleConfig.instance;
    _roleListener = () {
      // If role changes to employee → redirect to startup screen
      if (!_roleManager.isAdmin && mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    };

    _roleManager.addListener(_roleListener);
  }

  @override
  void dispose() {
    _roleManager.removeListener(_roleListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: MasterTopBar(
        system: CoffeaSystem.admin,
        tabs: _tabs,
        adminOnlyTabs: const [true, true, true, true, true],
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
/// TAB 1: Analytics
/// -----------------------------
class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.4,
        children: const [
          _AdminStatCard(title: "Total Sales", value: "₱25,430"),
          _AdminStatCard(title: "Transactions Today", value: "132"),
          _AdminStatCard(title: "Active Employees", value: "8"),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  final String title;
  final String value;

  const _AdminStatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// -----------------------------
/// TAB 2: Employee Management
/// -----------------------------
class AdminEmployeesScreen extends StatelessWidget {
  const AdminEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: Text(
            "Manage Employees Placeholder",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// -----------------------------
/// TAB 3: Product Management
/// -----------------------------
class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: Text(
            "Manage Products Placeholder",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// -----------------------------
/// TAB 4: Ingredient Management
/// -----------------------------
class AdminIngredientsScreen extends StatelessWidget {
  const AdminIngredientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: Text(
            "Manage Ingredients Placeholder",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

/// -----------------------------
/// TAB 5: Settings
/// -----------------------------
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        color: Colors.white,
        child: const Center(
          child: Text(
            "System Settings Placeholder",
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
/// <<END FILE>>