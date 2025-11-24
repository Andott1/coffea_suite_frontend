import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/services/session_user.dart'; // Updated import
import 'admin_ingredient_tab.dart';
import 'admin_product_tab.dart';

import 'package:flutter_bloc/flutter_bloc.dart'; // ✅ Import Bloc
import '../../core/bloc/auth/auth_bloc.dart';      // ✅ Import AuthBloc
import '../../core/bloc/auth/auth_state.dart';     // ✅ Import AuthState
import '../../core/models/user_model.dart';
import 'employee_management_screen.dart';
import 'settings_screen.dart';        // ✅ Import UserRoleLevel

class AdminBaseScreen extends StatefulWidget {
  const AdminBaseScreen({super.key});

  @override
  State<AdminBaseScreen> createState() => _AdminBaseScreenState();
}

class _AdminBaseScreenState extends State<AdminBaseScreen> {
  int _activeIndex = 0;
  
  // Tabs configuration
  final List<String> _tabs = const [
    "Analytics",
    "Employees",
    "Products",
    "Ingredients",
    "Settings",
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = const [
      AdminAnalyticsScreen(),
      EmployeeManagementScreen(),
      AdminProductTab(),
      AdminIngredientTab(),
      SettingsScreen(),
    ];

    // Security Check on Init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess();
    });
  }

  void _checkAccess() {
    if (!SessionUser.isAdmin) {
       // Kick user out if they are not admin
       if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to session changes
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        
        if (state is! AuthAuthenticated || state.user.role != UserRoleLevel.admin) {
           // If user logs out or switches to non-admin, kick them out
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
           });
           // Return loading/empty while redirecting
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: MasterTopBar(
            system: CoffeaSystem.admin,
            tabs: _tabs,
            // All tabs here are technically admin-only, passing true ensures logic holds
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
    );
  }
}

// ... (Placeholders for Analytics, Employees, Products, Settings remain unchanged) ...
class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Analytics Placeholder"));
  }
}

class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text("Products Placeholder"));
  }
}
