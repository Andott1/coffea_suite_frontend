import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/user_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/session_user.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';

// Import New Widget Components
import 'widgets/flat_search_field.dart';
import 'widgets/flat_dropdown.dart';
import 'widgets/flat_action_button.dart';
import 'widgets/employee_list_item.dart';

// ✅ IMPORT THE NEW SCREEN
import 'employee_edit_screen.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  // ──────────────── STATE ────────────────
  String _searchQuery = "";
  String _roleFilter = "All Roles";
  String _sortOrder = "Name (A-Z)";
  
  late Box<UserModel> _userBox;

  @override
  void initState() {
    super.initState();
    _userBox = HiveService.userBox;
  }

  // ──────────────── NAVIGATION ────────────────
  
  void _openEditor({UserModel? user}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EmployeeEditScreen(user: user)),
    );
  }

  // ──────────────── LOGIC: FILTERING ────────────────
  List<UserModel> _getFilteredUsers() {
    List<UserModel> users = _userBox.values.toList();

    // 1. Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      users = users.where((u) => 
        u.fullName.toLowerCase().contains(q) ||
        u.username.toLowerCase().contains(q)
      ).toList();
    }

    // 2. Role Filter
    if (_roleFilter != "All Roles") {
      users = users.where((u) => u.role.name.toUpperCase() == _roleFilter.toUpperCase()).toList();
    }

    // 3. Sort
    switch (_sortOrder) {
      case "Name (A-Z)":
        users.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case "Name (Z-A)":
        users.sort((a, b) => b.fullName.compareTo(a.fullName));
        break;
      case "Rate (High-Low)":
        users.sort((a, b) => b.hourlyRate.compareTo(a.hourlyRate));
        break;
      case "Rate (Low-High)":
        users.sort((a, b) => a.hourlyRate.compareTo(b.hourlyRate));
        break;
    }

    return users;
  }

  // ──────────────── ACTIONS ────────────────

  Future<void> _toggleStatus(UserModel user) async {
    if (user.id == SessionUser.current?.id) {
       DialogUtils.showToast(context, "Cannot deactivate your own account.", icon: Icons.block, accentColor: Colors.red);
       return;
    }

    final newStatus = !user.isActive;
    
    // If deactivating, confirm first
    if (!newStatus) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Confirm Deactivation"),
          content: Text("Deactivate ${user.fullName}? They will no longer be able to log in."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Deactivate", style: TextStyle(color: Colors.white)),
            )
          ],
        )
      );
      if (confirm != true) return;
    }

    user.isActive = newStatus;
    user.updatedAt = DateTime.now();
    await user.save();

    SupabaseSyncService.addToQueue(
      table: 'users',
      action: 'UPDATE',
      data: {'id': user.id, 'is_active': user.isActive, 'updated_at': user.updatedAt.toIso8601String()}
    );

    if(mounted) DialogUtils.showToast(context, "User ${newStatus ? 'Activated' : 'Deactivated'}");
  }

  Future<void> _deleteUser(UserModel user) async {
    if (user.id == SessionUser.current?.id) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Permanently?"),
        content: const Text(
          "This will PERMANENTLY erase this user and potentially break linked attendance records.\n\n"
          "Recommended: Use 'Deactivate' instead."
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final id = user.id;
    await user.delete();
    SupabaseSyncService.addToQueue(table: 'users', action: 'DELETE', data: {'id': id});
    
    if(mounted) DialogUtils.showToast(context, "User deleted.");
  }

  // ──────────────── UI: BUILD ────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: ValueListenableBuilder(
        valueListenable: _userBox.listenable(),
        builder: (context, _, __) {
          final allUsers = _userBox.values.toList();
          final displayedUsers = _getFilteredUsers();

          // Stats
          final total = allUsers.length;
          final active = allUsers.where((u) => u.isActive).length;
          final inactive = total - active;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // ─── 1. KPI CARDS ───
                Row(
                  children: [
                    _buildStatCard("Total Staff", "$total", Icons.people, Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard("Active", "$active", Icons.check_circle, ThemeConfig.primaryGreen),
                    const SizedBox(width: 16),
                    _buildStatCard("Inactive", "$inactive", Icons.block, Colors.grey),
                  ],
                ),

                const SizedBox(height: 24),

                // ─── 2. TOOLBAR ───
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: FlatSearchField(
                        hintText: "Search employees...",
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    Expanded(
                      flex: 3,
                      child: FlatDropdown<String>(
                        value: _roleFilter,
                        items: const ["All Roles", "Admin", "Manager", "Employee"],
                        label: "Role",
                        icon: Icons.filter_alt,
                        onChanged: (v) => setState(() => _roleFilter = v!),
                      ),
                    ),
                    const SizedBox(width: 16),

                    Expanded(
                      flex: 3,
                      child: FlatDropdown<String>(
                        value: _sortOrder,
                        items: const ["Name (A-Z)", "Name (Z-A)", "Rate (High-Low)", "Rate (Low-High)"],
                        label: "Sort By",
                        icon: Icons.sort,
                        onChanged: (v) => setState(() => _sortOrder = v!),
                      ),
                    ),
                    const SizedBox(width: 16),

                    FlatActionButton(
                      label: "Add Employee",
                      icon: Icons.person_add,
                      onPressed: () => _openEditor(), // ✅ Calls new screen
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ─── 3. HEADERS ───
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(width: 64),
                      Expanded(flex: 3, child: Text("IDENTITY", style: FontConfig.caption(context))),
                      Expanded(flex: 2, child: Text("ROLE", style: FontConfig.caption(context))),
                      Expanded(flex: 2, child: Text("RATE", style: FontConfig.caption(context))),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),

                // ─── 4. LIST ───
                Expanded(
                  child: displayedUsers.isEmpty
                    ? const Center(child: Text("No employees found.", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: displayedUsers.length,
                        itemBuilder: (context, index) {
                          final user = displayedUsers[index];
                          return EmployeeListItem(
                            user: user,
                            onEdit: () => _openEditor(user: user), // ✅ Calls new screen with data
                            onToggleStatus: () => _toggleStatus(user),
                            onDelete: () => _deleteUser(user),
                          );
                        },
                      ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}