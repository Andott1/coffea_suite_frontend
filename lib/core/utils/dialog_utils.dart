import 'package:flutter/material.dart';
import '../../config/theme_config.dart';

class DialogUtils {
  static final List<_SnackbarRecord> _activeSnackbars = [];
  static const double _baseOffset = 30.0;
  static const double _snackbarHeight = 80.0;
  static const int _maxSnackbars = 4;

  /// Show a stackable bottom-left snackbar-style toast
  static void showToast(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
    IconData icon = Icons.check_circle_outline,
    Color accentColor = ThemeConfig.secondaryGreen,
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null) return;

    // Remove oldest immediately if exceeding limit
    if (_activeSnackbars.length >= _maxSnackbars) {
      final oldest = _activeSnackbars.removeAt(0);
      oldest.key.currentState?.playExitAnimation().then((_) {
        oldest.entry.remove();
      });

      // shift remaining snackbars downward
      for (int i = 0; i < _activeSnackbars.length; i++) {
        final rec = _activeSnackbars[i];
        rec.offset -= _snackbarHeight;
        rec.key.currentState?.updateOffset(rec.offset);
      }
    }

    final double offset = _baseOffset + (_activeSnackbars.length * _snackbarHeight);
    final key = GlobalKey<_CoffeaSnackbarState>();

    final entry = OverlayEntry(
      builder: (context) => _CoffeaSnackbar(
        key: key,
        message: message,
        icon: icon,
        accentColor: accentColor,
        bottomOffset: offset,
      ),
    );

    _activeSnackbars.add(_SnackbarRecord(key: key, entry: entry, offset: offset));
    overlay.insert(entry);

    // Auto-remove after duration with exit animation
    Future.delayed(duration, () {
      if (_activeSnackbars.isEmpty) return;

      final removed = _activeSnackbars.removeAt(0);
      removed.key.currentState?.playExitAnimation().then((_) {
        removed.entry.remove();
      });

      for (int i = 0; i < _activeSnackbars.length; i++) {
        final rec = _activeSnackbars[i];
        final newOffset = rec.offset - _snackbarHeight;
        rec.offset = newOffset;
        rec.key.currentState?.updateOffset(newOffset);
      }
    });
  }
}

class _SnackbarRecord {
  final GlobalKey<_CoffeaSnackbarState> key;
  final OverlayEntry entry;
  double offset;
  _SnackbarRecord({required this.key, required this.entry, required this.offset});
}

class _CoffeaSnackbar extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color accentColor;
  final double bottomOffset;

  const _CoffeaSnackbar({
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.bottomOffset,
    Key? key,
  }) : super(key: key);

  @override
  State<_CoffeaSnackbar> createState() => _CoffeaSnackbarState();
}

class _CoffeaSnackbarState extends State<_CoffeaSnackbar>
    with TickerProviderStateMixin {
  late AnimationController _showController;
  late AnimationController _exitController;
  late Animation<Offset> _slideIn;
  late Animation<Offset> _slideOut;
  late Animation<double> _fadeIn;
  late Animation<double> _fadeOut;

  double _currentOffset = 0;

  @override
  void initState() {
    super.initState();
    _currentOffset = widget.bottomOffset;

    _showController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..forward();

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slideIn = Tween<Offset>(
      begin: const Offset(-0.3, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _showController, curve: Curves.easeOut));

    _slideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 0.2), // slides slightly downward on exit
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));

    _fadeIn = CurvedAnimation(parent: _showController, curve: Curves.easeOut);
    _fadeOut = CurvedAnimation(parent: _exitController, curve: Curves.easeIn);
  }

  /// Smooth offset reposition
  void updateOffset(double newOffset) {
    if (!mounted) return;
    setState(() {
      _currentOffset = newOffset;
    });
  }

  /// Play exit animation
  Future<void> playExitAnimation() async {
    if (!mounted) return;
    await _exitController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      bottom: _currentOffset,
      left: 30,
      child: AnimatedBuilder(
        animation: Listenable.merge([_showController, _exitController]),
        builder: (context, child) {
          final bool isExiting = _exitController.isAnimating ||
              _exitController.status == AnimationStatus.completed;
          final double opacity =
              isExiting ? (1 - _fadeOut.value) : _fadeIn.value;
          final Offset slide =
              isExiting ? _slideOut.value : _slideIn.value;

          return Opacity(
            opacity: opacity,
            child: FractionalTranslation(
              translation: slide,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: media.width * 0.35),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border(
                left: BorderSide(color: widget.accentColor, width: 5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(widget.icon, color: widget.accentColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    softWrap: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _showController.dispose();
    _exitController.dispose();
    super.dispose();
  }
}
