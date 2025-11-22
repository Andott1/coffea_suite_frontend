import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Simple Cubit to hold the global network state
/// State: true = Online, false = Offline
class ConnectivityCubit extends Cubit<bool> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;

  ConnectivityCubit() : super(true) { // Default to true (optimistic) or check logic below
    _init();
  }

  void _init() {
    // 1. Check initial status immediately
    _connectivity.checkConnectivity().then((result) {
      _updateStatus(result);
    });

    // 2. Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      _updateStatus(result);
    });
  }

  void _updateStatus(List<ConnectivityResult> result) {
    // If result contains 'none', we are offline. Otherwise, online.
    final isOnline = !result.contains(ConnectivityResult.none);
    emit(isOnline);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}