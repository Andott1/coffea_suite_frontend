import 'dart:async';
import 'package:flutter/material.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';

class BasicSearchBox extends StatefulWidget {
  final String hintText;
  final Function(String) onChanged;
  final TextEditingController? controller;

  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  

  const BasicSearchBox({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.controller,
    this.height = 48,
    this.borderRadius = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
    this.width,
  });

  @override
  State<BasicSearchBox> createState() => _BasicSearchBoxState();
}

class _BasicSearchBoxState extends State<BasicSearchBox> {
  late TextEditingController _controller;
  Timer? _debounce;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {})); // listen for focus changes
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 150), () {
      widget.onChanged(text.trim());
    });

    setState(() {}); // refresh clear button
  }

  void _clearText() {
    _controller.clear();
    widget.onChanged("");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {}, // enables ripple on tap
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Ink(
            height: widget.height,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                width: 2,
                color: _focusNode.hasFocus ? ThemeConfig.primaryGreen : ThemeConfig.midGray,
              ),
            ),

            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: ThemeConfig.midGray,
                  size: 22,
                ),

                const SizedBox(width: 8),

                // TEXT FIELD
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: _onTextChanged,
                    style: FontConfig.inputLabel(context).copyWith(
                      color: ThemeConfig.primaryGreen,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: FontConfig.inputLabel(context).copyWith(
                        color: ThemeConfig.midGray,
                      ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        
                      isCollapsed: true,
                    ),
                  ),
                ),

                // CLEAR BUTTON
                if (_controller.text.isNotEmpty)
                  InkWell(
                    onTap: _clearText,
                    borderRadius: BorderRadius.circular(1),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: ThemeConfig.midGray,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
