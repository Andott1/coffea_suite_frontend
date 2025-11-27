import 'package:talker_flutter/talker_flutter.dart';

class LoggerService {
  // Singleton instance of Talker
  static final Talker _talker = TalkerFlutter.init(
    settings: TalkerSettings(
      maxHistoryItems: 1000,
      useConsoleLogs: true,
      enabled: true,
    ),
    // We can add Sentry/Crashlytics observers here later
    logger: TalkerLogger(
      settings: TalkerLoggerSettings(
        enableColors: true,
      ),
    ),
  );

  /// Accessor for advanced usage (e.g., passing to BlocObserver)
  static Talker get instance => _talker;

  // ───────────────────────────────────────────────────────────────────────────
  // STATIC HELPERS (Replace your print statements with these)
  // ───────────────────────────────────────────────────────────────────────────

  /// Log general info (Blue/White)
  /// Replaces: LoggerService.info('Initializing...');
  static void info(String message) {
    _talker.info(message);
  }

  /// Log a warning (Orange)
  /// Replaces: LoggerService.info('Warning: Stock is low');
  static void warning(String message) {
    _talker.warning(message);
  }

  /// Log a critical error with exception/stack trace (Red)
  /// Replaces: LoggerService.info('Error: $e');
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    _talker.error(message, error, stackTrace);
  }

  /// Log a verbose debug message (Grey)
  /// Good for API payloads or heavy data
  static void debug(String message) {
    _talker.debug(message);
  }
}