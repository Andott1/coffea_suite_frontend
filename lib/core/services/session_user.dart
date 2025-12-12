import '../models/user_model.dart';
import '../config/permissions_config.dart';

class SessionUser {
  static UserModel? _current;

  static UserModel? get current => _current;

  static void set(UserModel? user) {
    _current = user;
  }

  static void clear() {
    _current = null;
  }

  static bool get isLoggedIn => _current != null;

  // ──────────────── ROLE HELPERS ────────────────
  static bool get isAdmin => _current?.role == UserRoleLevel.admin;
  
  static bool get isManager => 
      _current?.role == UserRoleLevel.manager || 
      _current?.role == UserRoleLevel.admin;

  // ──────────────── PERMISSION HELPER (✅ NEW) ────────────────
  static bool hasPermission(AppPermission permission) {
    return PermissionsConfig.hasPermission(_current?.role, permission);
  }
}