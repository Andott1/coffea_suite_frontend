import 'package:hive/hive.dart';
part 'user_model.g.dart';

@HiveType(typeId: 20)
enum UserRoleLevel {
  @HiveField(0) employee, // Level 1
  @HiveField(1) manager,  // Level 2
  @HiveField(2) admin     // Level 3
}

@HiveType(typeId: 21)
class UserModel extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String fullName;
  @HiveField(2) String username;
  @HiveField(3) String passwordHash;
  @HiveField(4) String pinHash;
  @HiveField(5) UserRoleLevel role;
  @HiveField(6) bool isActive;
  @HiveField(7) DateTime createdAt;
  @HiveField(8) DateTime updatedAt;

  // ✅ NEW: Payroll Field
  @HiveField(9) 
  double hourlyRate;

  UserModel({
    required this.id,
    required this.fullName,
    required this.username,
    required this.passwordHash,
    required this.pinHash,
    required this.role,
    this.isActive = true,
    this.hourlyRate = 0.0, // Default to 0 for Admins/Unset
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}