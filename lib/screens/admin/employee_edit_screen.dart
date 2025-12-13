import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/models/user_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/hashing_utils.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_input_field.dart';
import 'widgets/employee_avatar.dart';

class EmployeeEditScreen extends StatefulWidget {
  final UserModel? user;

  const EmployeeEditScreen({super.key, this.user});

  @override
  State<EmployeeEditScreen> createState() => _EmployeeEditScreenState();
}

class _EmployeeEditScreenState extends State<EmployeeEditScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _activeTab = "General";

  // ──────────────── FORM STATE ────────────────
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: "0.00");
  UserRoleLevel _selectedRole = UserRoleLevel.employee;
  bool _isActive = true;

  final _passwordCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  
  bool _isEditingPassword = false;
  bool _isEditingPin = false;

  late Box<UserModel> _userBox;

  @override
  void initState() {
    super.initState();
    _userBox = HiveService.userBox;

    if (widget.user != null) {
      _initEditMode();
    } else {
      _isEditingPassword = true;
      _isEditingPin = true;
    }
  }

  void _initEditMode() {
    final u = widget.user!;
    _nameCtrl.text = u.fullName;
    _usernameCtrl.text = u.username;
    _rateCtrl.text = u.hourlyRate.toStringAsFixed(2);
    _selectedRole = u.role;
    _isActive = u.isActive;
  }

  // ──────────────── SAVE LOGIC ────────────────
  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    //TODO: Move to new HiveService method
    final usernameInput = _usernameCtrl.text.trim();
    final currentUserId = widget.user?.id; // Will be null if creating new

    final isTaken = _userBox.values.any((u) {
      final nameMatches = u.username.toLowerCase() == usernameInput.toLowerCase();
      final isNotSelf = u.id != currentUserId; // Critical: Don't block our own existing name
      return nameMatches && isNotSelf;
    });

    if (isTaken) {
      DialogUtils.showToast(
        context, 
        "Username '$usernameInput' is already taken.", 
        icon: Icons.warning, 
        accentColor: Colors.orange
      );
      return; // 🛑 Stop execution
    }

    if (widget.user == null) {
      if (_passwordCtrl.text.isEmpty || _pinCtrl.text.isEmpty) {
        DialogUtils.showToast(context, "Password and PIN are required.", icon: Icons.error, accentColor: Colors.red);
        setState(() => _activeTab = "Security");
        return;
      }
    }

    try {
      final String id = widget.user?.id ?? const Uuid().v4();
      
      String finalPassHash = widget.user?.passwordHash ?? "";
      String finalPinHash = widget.user?.pinHash ?? "";

      if (_isEditingPassword && _passwordCtrl.text.isNotEmpty) {
        finalPassHash = HashingUtils.hashPassword(_passwordCtrl.text.trim());
      }
      if (_isEditingPin && _pinCtrl.text.isNotEmpty) {
        finalPinHash = HashingUtils.hashPin(_pinCtrl.text.trim());
      }

      final user = UserModel(
        id: id,
        fullName: _nameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        passwordHash: finalPassHash,
        pinHash: finalPinHash,
        role: _selectedRole,
        isActive: _isActive,
        hourlyRate: double.tryParse(_rateCtrl.text) ?? 0.0,
        updatedAt: DateTime.now(),
        createdAt: widget.user?.createdAt ?? DateTime.now(),
      );

      await _userBox.put(id, user);

      SupabaseSyncService.addToQueue(
        table: 'users',
        action: 'UPSERT',
        data: {
          'id': user.id,
          'full_name': user.fullName,
          'username': user.username,
          'password_hash': user.passwordHash,
          'pin_hash': user.pinHash,
          'role': user.role.name,
          'is_active': user.isActive,
          'hourly_rate': user.hourlyRate,
          'updated_at': user.updatedAt.toIso8601String(),
          'created_at': user.createdAt.toIso8601String(),
        }
      );

      if (mounted) {
        DialogUtils.showToast(context, "Employee saved successfully!");
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) DialogUtils.showToast(context, "Error: $e", icon: Icons.error);
    }
  }

  // ──────────────── UI BUILD ────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.user == null ? "Register New Employee" : "Edit Profile",
          style: FontConfig.h2(context).copyWith(color: Colors.black87),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: BasicButton(
              label: "Save Changes",
              icon: Icons.check,
              type: AppButtonType.primary,
              fullWidth: false,
              onPressed: _save,
            ),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ──────────────── LEFT SIDEBAR (Navigation) ───
            Container(
              width: 300,
              color: const Color(0xFFF8F9FA),
              child: Column(
                children: [
                  // 1. SCROLLABLE TOP SECTION (Avatar + Nav)
                  // Wrapped in Expanded + SingleChildScrollView to handle keyboard crunch
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 30),
                          
                          // Avatar with Upload Placeholder
                          GestureDetector(
                            onTap: () => DialogUtils.showToast(context, "Upload feature coming soon!", icon: Icons.cloud_upload),
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                EmployeeAvatar(
                                  name: _nameCtrl.text.isNotEmpty ? _nameCtrl.text : "New",
                                  role: _selectedRole,
                                  size: 100, 
                                ),
                                
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: ThemeConfig.primaryGreen,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2), 
                                        blurRadius: 4, 
                                        offset: const Offset(0, 2)
                                      )
                                    ]
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            _nameCtrl.text.isNotEmpty ? _nameCtrl.text : "New Employee",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            _selectedRole.name.toUpperCase(),
                            style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          
                          const SizedBox(height: 30),
                          const Divider(height: 1),

                          // Nav Tiles
                          _buildNavTile("General Info", Icons.badge_outlined, "General"),
                          _buildNavTile("Security & Access", Icons.lock_outline, "Security"),
                          
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // 2. PINNED BOTTOM SECTION (Account Status)
                  // Stays anchored to bottom (or top of keyboard)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey[200]!)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Account Status", style: FontConfig.caption(context)),
                        Switch(
                          value: _isActive,
                          activeColor: Colors.green,
                          onChanged: (v) => setState(() => _isActive = v),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const VerticalDivider(width: 1, color: Colors.grey),

            // ──────────────── RIGHT CONTENT (Dynamic) ───
            Expanded(
              child: Container(
                color: Colors.white,
                child: _activeTab == "General" 
                    ? _buildGeneralTab() 
                    : _buildSecurityTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavTile(String label, IconData icon, String tabId) {
    final isSelected = _activeTab == tabId;
    return Material(
      color: isSelected ? Colors.white : Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _activeTab = tabId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            border: isSelected 
                ? const Border(left: BorderSide(color: ThemeConfig.primaryGreen, width: 4))
                : null,
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? ThemeConfig.primaryGreen : Colors.grey, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.black87 : Colors.grey[700],
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────── TAB 1: GENERAL INFO ────────────────
  Widget _buildGeneralTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Identity", style: FontConfig.h3(context)),
          const SizedBox(height: 24),
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BasicInputField(
                  label: "Full Name",
                  controller: _nameCtrl,
                  // Rebuild to update sidebar name instantly
                  onChanged: (v) => setState(() {}),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: BasicInputField(
                  label: "Username",
                  controller: _usernameCtrl,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 40),

          Text("Role & Compensation", style: FontConfig.h3(context)),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<UserRoleLevel>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: "Access Level",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  items: UserRoleLevel.values.map((r) => DropdownMenuItem(
                    value: r, 
                    child: Text(r.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold))
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedRole = v!),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: BasicInputField(
                  label: "Hourly Rate",
                  controller: _rateCtrl,
                  inputType: TextInputType.number,
                  isCurrency: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────── TAB 2: SECURITY ────────────────
  Widget _buildSecurityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSecuritySection(
            title: "Login Password",
            subtitle: "Used for accessing the main dashboard/admin tools.",
            isEditing: _isEditingPassword,
            controller: _passwordCtrl,
            isPin: false,
            onEdit: () => setState(() => _isEditingPassword = true),
            onCancel: widget.user == null ? null : () { 
              setState(() {
                _isEditingPassword = false;
                _passwordCtrl.clear();
              });
            },
          ),

          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 40),

          _buildSecuritySection(
            title: "Time Clock PIN",
            subtitle: "4-digit numeric code used for daily attendance.",
            isEditing: _isEditingPin,
            controller: _pinCtrl,
            isPin: true,
            onEdit: () => setState(() => _isEditingPin = true),
            onCancel: widget.user == null ? null : () {
              setState(() {
                _isEditingPin = false;
                _pinCtrl.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection({
    required String title,
    required String subtitle,
    required bool isEditing,
    required TextEditingController controller,
    required bool isPin,
    required VoidCallback onEdit,
    VoidCallback? onCancel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            if (!isEditing)
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 16),
                label: Text(widget.user == null ? "Set Now" : "Reset"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ThemeConfig.primaryGreen,
                  side: const BorderSide(color: ThemeConfig.primaryGreen),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        
        if (isEditing)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: BasicInputField(
                    label: isPin ? "Enter New PIN (4 digits)" : "Enter New Password",
                    controller: controller,
                    isPassword: true,
                    inputType: isPin ? TextInputType.number : TextInputType.text,
                    maxLength: isPin ? 4 : null,
                  ),
                ),
                if (onCancel != null) ...[
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                  )
                ]
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 12),
                const Text("Credentials are set and active", style: TextStyle(fontWeight: FontWeight.w500, color: Colors.black87)),
                const Spacer(),
                Text(isPin ? "****" : "••••••••", style: const TextStyle(color: Colors.grey, fontSize: 18, letterSpacing: 2)),
              ],
            ),
          ),
      ],
    );
  }
}