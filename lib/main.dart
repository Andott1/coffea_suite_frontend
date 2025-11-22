/// <<FILE: lib/main.dart>>
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ Import 1

import 'core/services/hive_service.dart';
import 'core/services/supabase_sync_service.dart'; // ✅ Import 2
import 'core/bloc/auth/auth_bloc.dart';
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

  // 1. Initialize Local Database (Hive)
  await HiveService.init();

  // 2. Initialize Supabase (Cloud Sync)
  await Supabase.initialize(
    url: 'https://vvbjuezcwyakrnkrmgon.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ2Ymp1ZXpjd3lha3Jua3JtZ29uIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMwMzI1ODUsImV4cCI6MjA3ODYwODU4NX0.MBloBPZdwfjit4N5heAxdWwRMOGHF3mPHsTkk-zZkWM', 
  );

  // 3. Start the Sync Service (Background Queue)
  await SupabaseSyncService.init();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
        BlocProvider<PosBloc>(create: (_) => PosBloc()),
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