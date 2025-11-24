import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class SessionUser {
  static UserModel? _current;

  static UserModel? get current => _current;

  /// Set the current user and return true
  static void set(UserModel? user) {
    _current = user;
  }

  /// Logout
  static void clear() {
    _current = null;
  }

  static bool get isLoggedIn => _current != null;

  // ──────────────── ROLE HELPERS ────────────────
  static bool get isAdmin => _current?.role == UserRoleLevel.admin;
  
  static bool get isManager => 
      _current?.role == UserRoleLevel.manager || 
      _current?.role == UserRoleLevel.admin; // Managers also include Admins usually, or strictly separation? 
                                             // Based on your request: Admin > Manager > Employee
}
/// <<END FILE>>