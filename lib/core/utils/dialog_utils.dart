import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class DialogUtils {
  /// Show a custom Coffea-styled floating toast
  static void showToast(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => _CoffeaToast(message: message),
    );

    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }
}

class _CoffeaToast extends StatefulWidget {
  final String message;
  const _CoffeaToast({required this.message});

  @override
  State<_CoffeaToast> createState() => _CoffeaToastState();
}

class _CoffeaToastState extends State<_CoffeaToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;

    return Positioned(
      bottom: media.height * 0.08,
      left: media.width * 0.1,
      right: media.width * 0.1,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: ThemeConfig.primaryGreen.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.reverse();
    _controller.dispose();
    super.dispose();
  }
}
