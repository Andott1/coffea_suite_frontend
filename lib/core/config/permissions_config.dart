import '../models/user_model.dart';

enum AppPermission {

  // INVENTORY
  viewInventoryDashboard,
  viewInventoryList,
  viewInventoryLogs,
  editInventoryStock,

  // POS
  accessCashier,
  viewPosDashboard,
  viewPosHistory,
  voidTransaction,

  // ATTENDANCE
  accessTimeClock,
  viewAttendanceDashboard,
  viewAttendanceLogs,
  managePayroll,

  // ADMIN
  viewAdminDashboard,
  manageEmployees,
  manageProducts,
  manageIngredients,
  manageSettings,
}

class PermissionsConfig {
  static final Map<UserRoleLevel, Set<AppPermission>> _rolePermissions = {

    UserRoleLevel.admin: AppPermission.values.toSet(),

    UserRoleLevel.manager: {
      // Inventory
      AppPermission.viewInventoryDashboard,
      AppPermission.viewInventoryList,
      AppPermission.viewInventoryLogs,
      AppPermission.editInventoryStock,
      // POS
      AppPermission.accessCashier,
      AppPermission.viewPosDashboard,
      AppPermission.viewPosHistory,
      AppPermission.voidTransaction,
      // Attendance
      AppPermission.accessTimeClock,
      AppPermission.viewAttendanceDashboard,
      AppPermission.viewAttendanceLogs,
      // Admin
      AppPermission.viewAdminDashboard,
    },

    UserRoleLevel.employee: {
      AppPermission.viewInventoryList,
      AppPermission.accessCashier,
      AppPermission.accessTimeClock,
    },
  };

  static bool hasPermission(UserRoleLevel? role, AppPermission permission) {
    if (role == null) return false;
    return _rolePermissions[role]?.contains(permission) ?? false;
  }
}