/// <<FILE: lib/core/widgets/login_dialog.dart>>
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/hive_service.dart';
import '../../core/services/session_user.dart';
import '../../core/utils/hashing_utils.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/dialog_box_titled.dart';
import '../../config/theme_config.dart'; // Added to ensure accentColor access if needed

class LoginDialog extends StatefulWidget {
  final bool isStartup; // If true, hide Cancel button

  const LoginDialog({
    super.key, 
    this.isStartup = false
  });

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  
  bool _isLoading = false;

  void _attemptLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulate small delay for UX
    await Future.delayed(const Duration(milliseconds: 500));

    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    try {
      // 1. Find User in Hive
      final users = HiveService.userBox.values;
      final user = users.firstWhere(
        (u) => u.username.toLowerCase() == username.toLowerCase() && u.isActive,
        orElse: () => throw Exception("User not found or inactive"),
      );

      // 2. Verify Password
      final isValid = HashingUtils.verifyPassword(password, user.passwordHash);

      if (isValid) {
        // 3. Set Session
        if (mounted) {
          context.read<SessionUserNotifier>().login(user);
          Navigator.of(context).pop(true); // Return true on success
          DialogUtils.showToast(context, "Welcome back, ${user.fullName}!");
        }
      } else {
        throw Exception("Invalid password");
      }
    } catch (e) {
      if (mounted) {
        DialogUtils.showToast(context, "Login Failed: Invalid credentials", icon: Icons.error_outline, accentColor: Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DialogBoxTitled(
      title: "User Login",
      width: 400,
      dismissOnOutsideTap: !widget.isStartup,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            BasicInputField(
              label: "Username",
              controller: _usernameCtrl,
            ),
            const SizedBox(height: 16),
            
            // ✅ Now using BasicInputField with isPassword
            BasicInputField(
              label: "Password",
              controller: _passwordCtrl,
              isPassword: true,
            ),
            
            const SizedBox(height: 24),

            Row(
              children: [
                if (!widget.isStartup) ...[
                  Expanded(
                    child: BasicButton(
                      label: "Cancel",
                      type: AppButtonType.secondary,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: BasicButton(
                    label: _isLoading ? "Verifying..." : "Login",
                    type: AppButtonType.primary,
                    onPressed: _isLoading ? null : _attemptLogin,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
/// <<END FILE>>