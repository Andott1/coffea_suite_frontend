/// <<FILE: lib/main.dart>>
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // ✅ Import Bloc
import 'core/services/hive_service.dart';
import 'core/bloc/auth/auth_bloc.dart'; // ✅ Import AuthBloc
import 'config/theme_config.dart';

// Screens
import 'screens/startup/startup_screen.dart';
import 'screens/pos/pos_base_screen.dart';
import 'screens/admin/admin_base_screen.dart';
import 'screens/inventory/inventory_base_screen.dart';
import 'screens/attendance/attendance_base_screen.dart';

import 'screens/pos/bloc/pos_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveService.init();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
        BlocProvider<PosBloc>(create: (_) => PosBloc()), // ✅ Add POS Bloc
      ],
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
/// <<END FILE>>