import 'package:flutter/foundation.dart';

/// Temporary lightweight reactive Role Manager
/// -----------------------------------------------------------
/// Why this?
/// - Works without BLoC
/// - Mimics a Cubit-like reactive model
/// - Easy to migrate to real BLoC later
/// -----------------------------------------------------------
enum UserRole { admin, employee }

class RoleConfig extends ChangeNotifier {
  static final RoleConfig instance = RoleConfig._internal();

  RoleConfig._internal();

  UserRole _currentRole = UserRole.admin;
  UserRole get currentRole => _currentRole;

  bool get isAdmin => _currentRole == UserRole.admin;
  bool get isEmployee => _currentRole == UserRole.employee;

  /// Switch between roles and notify all listeners
  void toggleRole() {
    _currentRole =
        _currentRole == UserRole.admin ? UserRole.employee : UserRole.admin;
    notifyListeners();
  }

  /// Set specific role manually (optional)
  void setRole(UserRole role) {
    _currentRole = role;
    notifyListeners();
  }
}
