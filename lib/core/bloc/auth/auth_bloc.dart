import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/hive_service.dart';
import '../../services/session_user.dart';
import '../../utils/hashing_utils.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event, 
    Emitter<AuthState> emit
  ) async {
    emit(AuthUnauthenticated());
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // Simulated network delay
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      final users = HiveService.userBox.values;
      final user = users.firstWhere(
        (u) => u.username.toLowerCase() == event.username.toLowerCase() && u.isActive,
        orElse: () => throw Exception("User not found or inactive"),
      );

      if (HashingUtils.verifyPassword(event.password, user.passwordHash)) {
        SessionUser.set(user);
        emit(AuthAuthenticated(user));
      } else {
        emit(const AuthFailure("Invalid password"));
      }
    } catch (e) {
      emit(const AuthFailure("Invalid credentials"));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // 1. 🏁 Trigger the "Glass Curtain"
    emit(AuthLoading());

    // 2. ⏳ Artificial Delay (Smoothens the UI transition)
    await Future.delayed(const Duration(milliseconds: 500));

    // 3. 🧹 Cleanup
    SessionUser.clear();
    emit(AuthUnauthenticated());
  }
}