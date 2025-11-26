import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/widgets/master_topbar.dart';
import '../../core/services/session_user.dart';
import '../../core/bloc/auth/auth_bloc.dart';
import '../../core/bloc/auth/auth_state.dart';
import '../../core/models/user_model.dart';

// Screens
import 'admin_dashboard_screen.dart'; // ✅ Import Dashboard
import 'admin_ingredient_tab.dart';
import 'admin_product_tab.dart';
import 'employee_management_screen.dart';
import 'settings_screen.dart';

class AdminBaseScreen extends StatefulWidget {
  const AdminBaseScreen({super.key});

  @override
  State<AdminBaseScreen> createState() => _AdminBaseScreenState();
}

class _AdminBaseScreenState extends State<AdminBaseScreen> {
  int _activeIndex = 0;
  
  final List<String> _tabs = const [
    "Dashboard", // ✅ Renamed from Analytics
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
      AdminDashboardScreen(), // ✅ Use Real Dashboard
      EmployeeManagementScreen(),
      AdminProductTab(),
      AdminIngredientTab(),
      SettingsScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAccess();
    });
  }

  void _checkAccess() {
    if (!SessionUser.isAdmin) {
       if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  void _onTabChanged(int index) {
    setState(() => _activeIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        
        if (state is! AuthAuthenticated || state.user.role != UserRoleLevel.admin) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
           });
           return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

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
    );
  }
}