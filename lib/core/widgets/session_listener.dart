import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';

/// A wrapper widget that listens to Authentication changes.
/// When the user logs in, logs out, or switches accounts,
/// it triggers [onUserChanged] to allow the parent screen to re-evaluate permissions.
class SessionListener extends StatelessWidget {
  final Widget child;
  final VoidCallback onUserChanged;

  const SessionListener({
    super.key,
    required this.child,
    required this.onUserChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // React to any change in authentication state
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          onUserChanged();
        }
      },
      child: child,
    );
  }
}