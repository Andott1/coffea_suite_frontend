import 'package:flutter/material.dart';
import '../config/permissions_config.dart';
import '../services/session_user.dart';
import '../utils/dialog_utils.dart';

class AccessControlWrapper extends StatelessWidget {
  final AppPermission permission;
  final Widget child;
  
  /// Optional: Message to show when access is denied
  final String deniedMessage;

  const AccessControlWrapper({
    super.key,
    required this.permission,
    required this.child,
    this.deniedMessage = "Restricted: You do not have permission.",
  });

  @override
  Widget build(BuildContext context) {
    // 1. Check Permission
    if (SessionUser.hasPermission(permission)) {
      return child; // ✅ Access Granted
    }

    // 2. Access Denied Logic
    // We use GestureDetector to intercept touches + AbsorbPointer to kill child interactions
    return GestureDetector(
      onTap: () {
        DialogUtils.showToast(
          context, 
          deniedMessage, 
          icon: Icons.lock, 
          accentColor: Colors.orange
        );
      },
      // AbsorbPointer prevents the child (e.g. Button) from receiving the tap
      child: AbsorbPointer(
        absorbing: true,
        child: child,
      ),
    );
  }
}