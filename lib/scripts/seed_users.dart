import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../core/models/user_model.dart';
import '../core/services/logger_service.dart';
import '../core/utils/hashing_utils.dart'; // we will create this later

final Uuid uuid = Uuid();

Future<void> seedUsers() async {
  try {
    final userBox = Hive.box<UserModel>('users');

    if (userBox.isNotEmpty) {
      LoggerService.info("ℹ️ Users already seeded, skipping.");
      return;
    }

    LoggerService.info("⏳ Seeding Users...");

    final jsonString = await rootBundle.loadString('assets/data/users_list.json');
    final List<dynamic> data = jsonDecode(jsonString);

    int count = 0;

    for (final item in data) {
      final roleInt = item['role'];
      late UserRoleLevel role;

      switch (roleInt) {
        case 1:
          role = UserRoleLevel.employee;
          break;
        case 2:
          role = UserRoleLevel.manager;
          break;
        case 3:
        default:
          role = UserRoleLevel.admin;
      }

      final user = UserModel(
        id: item['id'] ?? uuid.v4(),
        fullName: item['fullName'] ?? "Unnamed User",
        username: item['username'],
        passwordHash: HashingUtils.hashPassword(item['password']),
        pinHash: HashingUtils.hashPin(item['pin']),
        role: role,
        isActive: true,
        hourlyRate: role == UserRoleLevel.admin ? 0.0 : 65.0,
      );

      await userBox.put(user.id, user);
      count++;
    }

    LoggerService.info("✅ Users seeded successfully ($count records).");

  } catch (e) {
    LoggerService.error("❌ Error seeding users: $e");
  }
}
