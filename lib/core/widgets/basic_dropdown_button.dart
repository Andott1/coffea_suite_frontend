import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';

class BasicDropdownButton<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String Function(T)? itemLabel;
  final void Function(T?) onChanged;

  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  /// 🔥 Optional override width
  final double? width;

  const BasicDropdownButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.itemLabel,
    this.height = 48,
    this.borderRadius = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.enabled = true,
    this.width,  // ⬅ NEW
  });

  @override
  State<BasicDropdownButton<T>> createState() => _BasicDropdownButtonState<T>();
}

class _BasicDropdownButtonState<T> extends State<BasicDropdownButton<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  bool _isOpen = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // TOGGLE OVERLAY
  // ─────────────────────────────────────────────
  void _toggleOverlay() {
    if (_isOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (_) {
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            offset: Offset(0, size.height + 4),
            showWhenUnlinked: false,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),

                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final label = widget.itemLabel?.call(item) ??
                        item.toString();

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          widget.onChanged(item);
                          _removeOverlay();
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Ink(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 16,
                              color: ThemeConfig.primaryGreen,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    setState(() => _isOpen = false);
  }

  // ─────────────────────────────────────────────
  // MAIN UI
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDisabled = !widget.enabled;

    final labelText = widget.value != null
        ? (widget.itemLabel?.call(widget.value as T) ??
            widget.value.toString())
        : "Select";

    return SizedBox(
      width: widget.width,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isDisabled ? null : _toggleOverlay,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Ink(
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  width: 2,
                  color: isDisabled
                      ? ThemeConfig.midGray.withOpacity(0.4)
                      : ThemeConfig.primaryGreen,
                ),
              ),
              child: Row(
                children: [
                  // TEXT VALUE
                  Expanded(
                    child: Text(
                      labelText,
                      style: FontConfig.inputLabel(context).copyWith(
                        color: isDisabled
                            ? ThemeConfig.midGray
                            : ThemeConfig.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  // ARROW ICON WITH ROTATION
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 180),
                    turns: _isOpen ? 0.5 : 0.0,
                    child: Icon(
                      Icons.arrow_drop_down,
                      size: 26,
                      color: isDisabled
                          ? ThemeConfig.midGray.withOpacity(0.4)
                          : ThemeConfig.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
