import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../../config/theme_config.dart';

/// A wrapper widget that provides two critical functions:
/// 1. Listens for Auth changes and triggers [onUserChanged] to rebuild the parent.
/// 2. Shows a "Glass Curtain" loading overlay during transitions (Login/Logout/Switch).
class SessionGuard extends StatelessWidget {
  final Widget child;
  final VoidCallback onUserChanged;

  const SessionGuard({
    super.key,
    required this.child,
    required this.onUserChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        // Trigger parent rebuild only when stable state is reached
        if (state is AuthAuthenticated || state is AuthUnauthenticated) {
          onUserChanged();
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return Stack(
          children: [
            // 1. The Actual Screen (User Interaction)
            child,

            // 2. The Glass Curtain (Loading Overlay)
            // Uses IgnorePointer to allow clicks when hidden, blocks when visible
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !isLoading, 
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  opacity: isLoading ? 1.0 : 0.0,
                  child: Container(
                    color: Colors.white.withValues(alpha: 0.85), // The "Glass" effect
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: ThemeConfig.primaryGreen,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Updating Session...",
                            style: TextStyle(
                              color: ThemeConfig.primaryGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}