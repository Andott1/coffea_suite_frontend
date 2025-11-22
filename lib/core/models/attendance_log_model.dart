import 'package:hive/hive.dart';
part 'attendance_log_model.g.dart';

@HiveType(typeId: 30) // Unique Type ID
enum AttendanceStatus {
  @HiveField(0) onTime,
  @HiveField(1) late,
  @HiveField(2) overtime,
  @HiveField(3) incomplete // Missed clock out
}

@HiveType(typeId: 31)
class AttendanceLogModel extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String userId;
  
  // Normalized Date (Midnight) for easy querying
  @HiveField(2) final DateTime date; 
  
  @HiveField(3) DateTime timeIn;
  @HiveField(4) DateTime? timeOut;
  
  // Break Tracking (Optional expansion: List<Break> for multiple breaks)
  @HiveField(5) DateTime? breakStart;
  @HiveField(6) DateTime? breakEnd;

  @HiveField(7) AttendanceStatus status;
  
  // Snapshot of rate at the time of work (in case their rate changes later)
  @HiveField(8) double hourlyRateSnapshot; 

  AttendanceLogModel({
    required this.id,
    required this.userId,
    required this.date,
    required this.timeIn,
    this.timeOut,
    this.breakStart,
    this.breakEnd,
    this.status = AttendanceStatus.incomplete,
    this.hourlyRateSnapshot = 0.0,
  });

  // ──────────────── COMPUTED HELPERS ────────────────
  
  /// Returns total hours worked excluding break
  double get totalHoursWorked {
    if (timeOut == null) return 0.0;

    final workDuration = timeOut!.difference(timeIn);
    Duration breakDuration = Duration.zero;

    if (breakStart != null && breakEnd != null) {
      breakDuration = breakEnd!.difference(breakStart!);
    }

    final netDuration = workDuration - breakDuration;
    // Return hours as double (e.g., 8.5 hours)
    return netDuration.inMinutes / 60.0; 
  }
  
  /// Returns simple payroll calculation for this day
  double get dailyPay => totalHoursWorked * hourlyRateSnapshot;
}