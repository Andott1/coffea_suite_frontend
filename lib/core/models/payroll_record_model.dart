import 'package:hive/hive.dart';
part 'payroll_record_model.g.dart';

@HiveType(typeId: 40) // ✅ Unique Type ID
class PayrollRecordModel extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String userId;
  
  // Period Covered
  @HiveField(2) final DateTime periodStart;
  @HiveField(3) final DateTime periodEnd;
  
  // The Math
  @HiveField(4) final double totalHours;
  @HiveField(5) final double grossPay;
  @HiveField(6) final double netPay;
  
  // Snapshot of Adjustments (Stored as JSON String for flexibility)
  // Example: '[{"label": "Cash Advance", "amount": -500.0}, ...]'
  @HiveField(7) final String adjustmentsJson; 
  
  @HiveField(8) final DateTime generatedAt;
  
  // Optional: Who generated it?
  @HiveField(9) final String generatedBy;

  PayrollRecordModel({
    required this.id,
    required this.userId,
    required this.periodStart,
    required this.periodEnd,
    required this.totalHours,
    required this.grossPay,
    required this.netPay,
    required this.adjustmentsJson,
    required this.generatedAt,
    required this.generatedBy,
  });
}