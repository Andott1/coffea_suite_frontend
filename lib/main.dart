import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart'; // ✅ Import
import 'package:talker_flutter/talker_flutter.dart';

import 'package:camera/camera.dart';

import 'core/bloc/connectivity/connectivity_cubit.dart';
import 'core/services/hive_service.dart';
import 'core/services/supabase_sync_service.dart';
import 'core/services/logger_service.dart'; // ✅ Import
import 'core/bloc/auth/auth_bloc.dart';
import 'config/theme_config.dart';

// Screens
import 'screens/startup/startup_screen.dart';
import 'screens/pos/pos_base_screen.dart';
import 'screens/admin/admin_base_screen.dart';
import 'screens/inventory/inventory_base_screen.dart';
import 'screens/attendance/attendance_base_screen.dart';
import 'screens/pos/bloc/pos_bloc.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Initialize Logger
  LoggerService.info("🚀 App Starting...");

  try {
    cameras = await availableCameras();
    LoggerService.info("📷 Cameras initialized: ${cameras.length} found");
  } catch (e) {
    LoggerService.error("❌ Camera init failed: $e");
  }

  // 1. Initialize Supabase (Cloud Sync)
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    LoggerService.error('❌ Supabase credentials missing! Run with --dart-define');
  }

  await Supabase.initialize(
    url: supabaseUrl, 
    anonKey: supabaseKey, 
  );

  // 2. Initialize Local Database (Hive)
  await HiveService.init();

  // 3. Start the Sync Service (Background Queue)
  await SupabaseSyncService.init();

  // 4. ✅ Hook into BLoC for automatic state logging
  Bloc.observer = TalkerBlocObserver(
    talker: LoggerService.instance,
    settings: const TalkerBlocLoggerSettings(
      printEventFullData: false, // Set true to see full event payloads
      printStateFullData: false,
    ),
  );

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
        BlocProvider<PosBloc>(create: (_) => PosBloc()),
        BlocProvider<ConnectivityCubit>(create: (_) => ConnectivityCubit()),
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
      // ✅ Add TalkerObserver to Navigator to log screen transitions
      navigatorObservers: [
        TalkerRouteObserver(LoggerService.instance),
      ],
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