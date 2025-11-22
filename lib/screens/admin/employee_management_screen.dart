import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/user_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart'; // ✅ Sync Import
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/hashing_utils.dart';

import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/basic_search_box.dart';
import '../../core/widgets/container_card.dart';
import '../../core/widgets/dialog_box_editable.dart';
import '../../core/widgets/item_card.dart';
import '../../core/widgets/item_grid_view.dart';

class EmployeeManagementScreen extends StatefulWidget {
  const EmployeeManagementScreen({super.key});

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  // ──────────────── STATE ────────────────
  String _searchQuery = "";
  late Box<UserModel> _userBox;

  @override
  void initState() {
    super.initState();
    _userBox = HiveService.userBox;
  }

  // ──────────────── LOGIC: FILTERING ────────────────
  List<UserModel> _getFilteredUsers() {
    final users = _userBox.values.toList();
    if (_searchQuery.isEmpty) return users;
    return users.where((u) => 
      u.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      u.username.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  // ──────────────── LOGIC: SAVE USER (CREATE / UPDATE) ────────────────
  Future<void> _saveUser({
    required String? id,
    required String fullName,
    required String username,
    required String? password, // Null if unchanged (edit mode)
    required String? pin,      // Null if unchanged (edit mode)
    required UserRoleLevel role,
    required double hourlyRate,
    required bool isActive,
  }) async {
    final isEdit = id != null;
    final userId = id ?? const Uuid().v4();
    
    // 1. Hashing Logic
    // If creating: Hash mandatory inputs.
    // If editing: Keep old hash if input is empty, else hash new input.
    String finalPasswordHash;
    String finalPinHash;

    if (isEdit) {
      final oldUser = _userBox.get(userId)!;
      finalPasswordHash = (password == null || password.isEmpty) 
          ? oldUser.passwordHash 
          : HashingUtils.hashPassword(password);
      finalPinHash = (pin == null || pin.isEmpty) 
          ? oldUser.pinHash 
          : HashingUtils.hashPin(pin);
    } else {
      // Create mode (Validation ensures these aren't null)
      finalPasswordHash = HashingUtils.hashPassword(password!);
      finalPinHash = HashingUtils.hashPin(pin!);
    }

    // 2. Create Model
    final user = UserModel(
      id: userId,
      fullName: fullName,
      username: username,
      passwordHash: finalPasswordHash,
      pinHash: finalPinHash,
      role: role,
      isActive: isActive,
      hourlyRate: hourlyRate,
      updatedAt: DateTime.now(),
      createdAt: isEdit ? _userBox.get(userId)!.createdAt : DateTime.now(),
    );

    // 3. Save Local
    await _userBox.put(userId, user);

    // 4. ✅ SYNC TO SUPABASE (Fixes Foreign Key Error)
    SupabaseSyncService.addToQueue(
      table: 'users',
      action: 'UPSERT',
      data: {
        'id': user.id,
        'full_name': user.fullName,
        'username': user.username,
        'password_hash': user.passwordHash,
        'pin_hash': user.pinHash,
        'role': user.role.name, // Enum to String
        'is_active': user.isActive,
        'hourly_rate': user.hourlyRate,
        'updated_at': user.updatedAt.toIso8601String(),
        'created_at': user.createdAt.toIso8601String(),
      },
    );

    if (mounted) {
      DialogUtils.showToast(context, isEdit ? "User updated successfully" : "User created successfully");
    }
  }

  // ──────────────── UI: ADD / EDIT DIALOG ────────────────
  void _showUserDialog({UserModel? user}) {
    final isEdit = user != null;
    final formKey = GlobalKey<FormState>();
    
    // Controllers
    final nameCtrl = TextEditingController(text: user?.fullName);
    final usernameCtrl = TextEditingController(text: user?.username);
    final rateCtrl = TextEditingController(text: user?.hourlyRate.toString() ?? "60.0");
    final passCtrl = TextEditingController(); // Empty by default
    final pinCtrl = TextEditingController();  // Empty by default

    // Local State for Dialog
    UserRoleLevel selectedRole = user?.role ?? UserRoleLevel.employee;
    bool isActive = user?.isActive ?? true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return DialogBoxEditable(
            title: isEdit ? "Edit User" : "New User",
            formKey: formKey,
            width: 500,
            onSave: () {
              // Validation
              if (!formKey.currentState!.validate()) return;
              
              // Special Validation for New Users (Must have Pass/PIN)
              if (!isEdit && (passCtrl.text.isEmpty || pinCtrl.text.isEmpty)) {
                DialogUtils.showToast(context, "Password and PIN are required for new users.", icon: Icons.error, accentColor: Colors.red);
                return;
              }

              _saveUser(
                id: user?.id,
                fullName: nameCtrl.text.trim(),
                username: usernameCtrl.text.trim(),
                password: passCtrl.text.trim(),
                pin: pinCtrl.text.trim(),
                role: selectedRole,
                hourlyRate: double.tryParse(rateCtrl.text) ?? 0.0,
                isActive: isActive,
              );
              Navigator.pop(context);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── 1. IDENTITY ───
                Row(
                  children: [
                    Expanded(child: BasicInputField(label: "Full Name", controller: nameCtrl)),
                    const SizedBox(width: 12),
                    Expanded(child: BasicInputField(label: "Username", controller: usernameCtrl)),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── 2. ROLE & RATE ───
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<UserRoleLevel>(
                        value: selectedRole,
                        decoration: InputDecoration(
                          labelText: "Role",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        items: UserRoleLevel.values.map((r) => DropdownMenuItem(
                          value: r, 
                          child: Text(r.name.toUpperCase())
                        )).toList(),
                        onChanged: (v) => setState(() => selectedRole = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BasicInputField(
                        label: "Hourly Rate (₱)", 
                        controller: rateCtrl, 
                        inputType: TextInputType.number,
                        isCurrency: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ─── 3. SECURITY (Pass & PIN) ───
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200)
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.security, size: 16, color: Colors.orange),
                          SizedBox(width: 8),
                          Text("Security Credentials", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: BasicInputField(
                              label: isEdit ? "Change Password" : "Password", 
                              controller: passCtrl, 
                              isPassword: true,
                              isRequired: !isEdit, // Only required for new
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: BasicInputField(
                              label: isEdit ? "Change PIN" : "PIN (4-6 digits)", 
                              controller: pinCtrl, 
                              inputType: TextInputType.number,
                              isPassword: true,
                              isRequired: !isEdit,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ─── 4. STATUS SWITCH ───
                if (isEdit)
                  Row(
                    children: [
                      Switch(
                        value: isActive, 
                        activeColor: ThemeConfig.primaryGreen,
                        onChanged: (v) => setState(() => isActive = v)
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isActive ? "Active User" : "Inactive (Access Revoked)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive ? ThemeConfig.primaryGreen : Colors.grey
                        ),
                      )
                    ],
                  )
              ],
            ),
          );
        }
      ),
    );
  }

  // ──────────────── UI: BUILD ────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ─── TOP BAR ───
            ContainerCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: BasicSearchBox(
                      hintText: "Search Employees...",
                      onChanged: (v) => setState(() => _searchQuery = v),
                    ),
                  ),
                  const SizedBox(width: 20),
                  BasicButton(
                    label: "Add Employee",
                    icon: Icons.person_add,
                    type: AppButtonType.primary,
                    fullWidth: false,
                    onPressed: () => _showUserDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ─── GRID LIST ───
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _userBox.listenable(),
                builder: (context, Box<UserModel> box, _) {
                  final users = _getFilteredUsers();

                  if (users.isEmpty) {
                    return const Center(child: Text("No employees found."));
                  }

                  return ItemGridView<UserModel>(
                    items: users,
                    minItemWidth: 280,
                    childAspectRatio: 1.8,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    itemBuilder: (context, user) => _buildUserCard(user),
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user) {
    final roleColor = user.role == UserRoleLevel.admin 
        ? Colors.purple 
        : (user.role == UserRoleLevel.manager ? Colors.blue : ThemeConfig.primaryGreen);

    return ItemCard(
      onTap: () => _showUserDialog(user: user),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar Placeholder
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withOpacity(0.1),
                    child: Icon(Icons.person, color: roleColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          "@${user.username}",
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const Spacer(),
              
              // Role Badge & Rate
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: roleColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)
                    ),
                    child: Text(
                      user.role.name.toUpperCase(),
                      style: TextStyle(color: roleColor, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                  if (user.role != UserRoleLevel.admin)
                    Text(
                      "${FormatUtils.formatCurrency(user.hourlyRate)}/hr",
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                ],
              )
            ],
          ),
          
          if (!user.isActive)
            Container(
              color: Colors.white.withOpacity(0.6),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(4)),
                child: const Text("INACTIVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
    );
  }
}