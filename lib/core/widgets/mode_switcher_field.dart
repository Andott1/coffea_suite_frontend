import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import 'searchable_picker_dialog.dart'; // ✅ Import new dialog

class ModeSwitcherField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final List<String> options;
  final Function(String)? onChanged;

  const ModeSwitcherField({
    super.key,
    required this.label,
    required this.controller,
    required this.options,
    this.onChanged,
  });

  @override
  State<ModeSwitcherField> createState() => _ModeSwitcherFieldState();
}

class _ModeSwitcherFieldState extends State<ModeSwitcherField> {
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // Auto-detect mode based on initial value
    if (widget.controller.text.isNotEmpty && 
        !widget.options.contains(widget.controller.text)) {
      _isCreating = true;
    }
  }

  void _toggleMode() {
    setState(() {
      _isCreating = !_isCreating;
      if (_isCreating) {
        widget.controller.clear();
        widget.onChanged?.call("");
      } else {
        // Just clear, let user pick again
        widget.controller.clear();
        widget.onChanged?.call("");
      }
    });
  }

  // ✅ Open the new Searchable Dialog
  Future<void> _openPicker() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SearchablePickerDialog(
        title: "Select ${widget.label}",
        items: widget.options,
        initialSelection: widget.controller.text.isNotEmpty ? [widget.controller.text] : [],
        multiSelect: false,
      ),
    );

    if (selected != null) {
      setState(() {
        widget.controller.text = selected;
        widget.onChanged?.call(selected);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── HEADER ROW ───
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(widget.label, style: FontConfig.inputLabel(context)),
            InkWell(
              onTap: _toggleMode,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  _isCreating ? "Select Existing" : "+ Create New",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _isCreating ? Colors.blue : ThemeConfig.primaryGreen,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        
        // ─── INPUT AREA ───
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _isCreating ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          
          // 1. SELECTION MODE (Read-only Field triggering Dialog)
          firstChild: GestureDetector(
            onTap: _openPicker,
            child: AbsorbPointer( // Prevents keyboard from opening
              child: TextFormField(
                controller: widget.controller,
                readOnly: true, // Visual read-only
                decoration: _inputDecoration().copyWith(
                  hintText: "Select from list...",
                  suffixIcon: const Icon(Icons.arrow_drop_down_circle, color: ThemeConfig.primaryGreen),
                ),
              ),
            ),
          ),

          // 2. CREATION MODE (Standard Text Field)
          secondChild: TextFormField(
            controller: widget.controller,
            decoration: _inputDecoration().copyWith(
              hintText: "Type new ${widget.label.toLowerCase()} name...",
              suffixIcon: IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: _toggleMode,
                tooltip: "Cancel",
              )
            ),
            onChanged: (val) => widget.onChanged?.call(val),
            validator: (v) => _isCreating && (v == null || v.isEmpty) 
                ? "Please enter a name" 
                : null,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ThemeConfig.midGray, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: ThemeConfig.primaryGreen, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}