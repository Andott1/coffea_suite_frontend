import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/role_config.dart';
import 'screens/startup/startup_screen.dart';
import 'screens/pos/pos_base_screen.dart';
import 'screens/admin/admin_base_screen.dart';
import 'screens/inventory/inventory_base_screen.dart';
import 'screens/attendance/attendance_base_screen.dart';
import 'config/theme_config.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => RoleConfig.instance,
      child: const CoffeaSuiteApp(),
    ),
  );
}

class CoffeaSuiteApp extends StatelessWidget {
  const CoffeaSuiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coffea POS Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeConfig.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const StartupScreen(),
        '/pos': (context) => const POSBaseScreen(),
        '/admin': (context) => const AdminBaseScreen(),
        '/inventory': (context) => const InventoryBaseScreen(),
        '/attendance': (context) => const AttendanceBaseScreen(),
      },
    );
  }
}
