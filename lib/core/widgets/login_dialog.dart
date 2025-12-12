import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_input_field.dart';
import '../../core/widgets/basic_button.dart';
import '../../core/widgets/dialog_box_titled.dart';

class LoginDialog extends StatefulWidget {
  final bool isStartup;

  const LoginDialog({super.key, this.isStartup = false});

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  void _attemptLogin() {
    if (!_formKey.currentState!.validate()) return;
    
    // ✅ BLoC Logic: Dispatch Event
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 🔒 Lock back button only if this is the Startup Login
      canPop: !widget.isStartup, 
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;

        // If we blocked the pop, explain why
        if (widget.isStartup) {
          DialogUtils.showToast(
            context, 
            "Authentication Required Use Home Button to Exit.", 
            icon: Icons.lock, 
            accentColor: Colors.orange
          );
        }
      },
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.of(context).pop(true);
            DialogUtils.showToast(context, "Welcome back, ${state.user.fullName}!");
          } else if (state is AuthFailure) {
            DialogUtils.showToast(context, state.message, icon: Icons.error_outline, accentColor: Colors.red);
          }
        },
        child: DialogBoxTitled(
          title: "User Login",
          width: 400,
          dismissOnOutsideTap: !widget.isStartup,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                BasicInputField(label: "Username", controller: _usernameCtrl),
                const SizedBox(height: 16),
                BasicInputField(label: "Password", controller: _passwordCtrl, isPassword: true),
                const SizedBox(height: 24),
                
                // ✅ BLoC Builder: React to state changes (UI Rebuild)
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) {
                    final isLoading = state is AuthLoading;
                    
                    return Row(
                      children: [
                        if (!widget.isStartup) ...[
                          Expanded(
                            child: BasicButton(
                              label: "Cancel",
                              type: AppButtonType.secondary,
                              onPressed: isLoading ? null : () => Navigator.pop(context, false),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: BasicButton(
                            label: isLoading ? "Verifying..." : "Login",
                            type: AppButtonType.primary,
                            onPressed: isLoading ? null : _attemptLogin,
                          ),
                        ),
                      ],
                    );
                  },
                )
              ],
            ),
          ),
        ),
      )
    );
  }
}
