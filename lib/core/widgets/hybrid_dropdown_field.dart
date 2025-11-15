import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';

class HybridDropdownField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> options;
  final bool isRequired;

  const HybridDropdownField({
    super.key,
    required this.label,
    required this.controller,
    required this.options,
    this.isRequired = true,
  });

  @override
  State<HybridDropdownField> createState() => _HybridDropdownFieldState();
}

class _HybridDropdownFieldState extends State<HybridDropdownField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay(); // cleanup old ones
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final fieldSize = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // Filtered options
        final filteredOptions = widget.options
            .where((opt) => opt
                .toLowerCase()
                .contains(widget.controller.text.toLowerCase()))
            .where((opt) => opt.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

        if (filteredOptions.isEmpty) return const SizedBox.shrink();

        return Positioned(
          width: fieldSize.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, fieldSize.height + 4),
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filteredOptions.length,
                  shrinkWrap: true,
                  itemBuilder: (context, index) {
                    final opt = filteredOptions[index];
                    return InkWell(
                      onTap: () {
                        widget.controller.text = opt;
                        _removeOverlay();
                        FocusScope.of(context).unfocus();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        child: Text(
                          opt,
                          style: const TextStyle(
                            color: ThemeConfig.primaryGreen,
                            fontWeight: FontWeight.w500,
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
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: const TextStyle(
          color: ThemeConfig.primaryGreen,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: FontConfig.inputLabel(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: ThemeConfig.midGray, width: 2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          suffixIcon: IconButton(
            icon: const Icon(Icons.arrow_drop_down, color: ThemeConfig.primaryGreen),
            onPressed: () {
              if (_overlayEntry == null) {
                _focusNode.requestFocus();
              } else {
                _removeOverlay();
                FocusScope.of(context).unfocus();
              }
            },
          ),
        ),
        validator: (v) {
          if (widget.isRequired && (v == null || v.trim().isEmpty)) {
            return "${widget.label} is required";
          }
          return null;
        },
        onChanged: (_) {
          if (_focusNode.hasFocus) {
            _showOverlay(); // refresh filtered list
          }
        },
      ),
    );
  }
}
