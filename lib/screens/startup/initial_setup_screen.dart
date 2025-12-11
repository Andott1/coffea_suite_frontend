import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme_config.dart';
import '../../core/models/user_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/supabase_sync_service.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/utils/hashing_utils.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/container_card_titled.dart';

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key});

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  int _step = 0; // 0 = Choice, 1 = Create Admin, 2 = Restoring
  final _formKey = GlobalKey<FormState>();
  
  // Admin Form Controllers
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final uuid = const Uuid().v4();
      
      // 1. Create Admin User Model
      final admin = UserModel(
        id: uuid,
        fullName: _nameCtrl.text.trim(),
        username: _usernameCtrl.text.trim(),
        passwordHash: HashingUtils.hashPassword(_passwordCtrl.text.trim()),
        pinHash: HashingUtils.hashPin(_pinCtrl.text.trim()),
        role: UserRoleLevel.admin,
        isActive: true,
        hourlyRate: 0.0, // Owners don't usually track hourly pay here
      );

      // 2. Save Locally
      await HiveService.userBox.put(admin.id, admin);

      // 3. Queue for Cloud
      await SupabaseSyncService.addToQueue(
        table: 'users', 
        action: 'UPSERT', 
        data: {
          'id': admin.id,
          'full_name': admin.fullName,
          'username': admin.username,
          'password_hash': admin.passwordHash,
          'pin_hash': admin.pinHash,
          'role': admin.role.name,
          'is_active': admin.isActive,
          'hourly_rate': admin.hourlyRate,
          'updated_at': admin.updatedAt.toIso8601String(),
          'created_at': admin.createdAt.toIso8601String(),
        }
      );

      if (mounted) {
        DialogUtils.showToast(context, "Store initialized successfully!");
        // Navigate to Startup (which will now see a user and show Login)
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      if (!mounted) return;
      DialogUtils.showToast(context, "Error creating admin: $e", icon: Icons.error);
    }
  }

  Future<void> _restoreFromCloud() async {
    setState(() => _step = 2); // Show loading state
    
    try {
      await SupabaseSyncService.restoreFromCloud();
      
      if (mounted) {
        if (HiveService.userBox.isNotEmpty) {
          DialogUtils.showToast(context, "Data restored successfully!");
          Navigator.pushReplacementNamed(context, '/');
        } else {
           setState(() => _step = 0);
           DialogUtils.showToast(context, "Cloud database is empty. Please create a new store.", icon: Icons.warning, accentColor: Colors.orange);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _step = 0);
        DialogUtils.showToast(context, "Restore failed: $e", icon: Icons.error, accentColor: Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: ContainerCardTitled(
              title: _getTitle(),
              subtitle: _getSubtitle(),
              centerTitle: true,
              contentPadding: const EdgeInsets.all(24),
              child: _buildContent(),
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle() {
    if (_step == 1) return "Setup Owner Account";
    if (_step == 2) return "Restoring Data...";
    return "Welcome to Coffea";
  }

  String _getSubtitle() {
    if (_step == 1) return "Create the main administrator for this device";
    if (_step == 2) return "Downloading your store data from the cloud";
    return "Is this a new store or an existing one?";
  }

  Widget _buildContent() {
    if (_step == 1) return _buildAdminForm();
    if (_step == 2) return _buildLoader();
    return _buildChoice();
  }

  // ─── STEP 0: CHOICE ───
  Widget _buildChoice() {
    return Column(
      children: [
        BasicButton(
          label: "Create New Store",
          icon: Icons.store_mall_directory,
          type: AppButtonType.primary,
          onPressed: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 16),
        const Text("- OR -", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        BasicButton(
          label: "Connect Existing Store",
          icon: Icons.cloud_download,
          type: AppButtonType.secondary,
          onPressed: _restoreFromCloud,
        ),
      ],
    );
  }

  // ─── STEP 1: ADMIN FORM ───
  Widget _buildAdminForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          BasicInputField(label: "Full Name", controller: _nameCtrl),
          const SizedBox(height: 12),
          BasicInputField(label: "Username", controller: _usernameCtrl),
          const SizedBox(height: 12),
          BasicInputField(label: "Password", controller: _passwordCtrl, isPassword: true),
          const SizedBox(height: 12),
          BasicInputField(label: "Security PIN (4 digits)", controller: _pinCtrl, isPassword: true, inputType: TextInputType.number, maxLength: 4),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: BasicButton(
                  label: "Back",
                  type: AppButtonType.secondary,
                  onPressed: () => setState(() => _step = 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BasicButton(
                  label: "Initialize Store",
                  type: AppButtonType.primary,
                  onPressed: _createAdmin,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ─── STEP 2: LOADER ───
  Widget _buildLoader() {
    return const Padding(
      padding: EdgeInsets.all(40.0),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}