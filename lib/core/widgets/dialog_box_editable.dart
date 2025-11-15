import 'package:flutter/material.dart';
import 'basic_button.dart';
import 'dialog_box_titled.dart';

/// A reusable titled dialog designed specifically for editable content.
/// 
/// Features:
/// - Uses DialogBoxTitled internally (consistent UI)
/// - Wraps children inside a Form
/// - Provides Cancel/Save buttons
/// - Handles validation using a global formKey
/// - Child is ANY input widgets (BasicInputField, HybridDropdownField, etc.)
///
/// This dialog is perfect for editing ingredients, products, and any data item.
class DialogBoxEditable extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// The form key from the parent widget.
  final GlobalKey<FormState> formKey;

  /// The input fields or form content.
  final Widget child;

  /// Called when Save is pressed AND validation succeeds.
  final VoidCallback onSave;

  /// Optional callback for Cancel.
  final VoidCallback? onCancel;

  /// Width of dialog.
  final double width;

  /// Spacing between title and fields.
  final double contentSpacing;

  final List<Widget>? actions;

  const DialogBoxEditable({
    super.key,
    required this.title,
    this.actions,
    this.subtitle,
    required this.child,
    required this.formKey,
    required this.onSave,
    this.onCancel,
    this.width = 500,
    this.contentSpacing = 20,
  });

  @override
  Widget build(BuildContext context) {
    return DialogBoxTitled(
      title: title,
      subtitle: subtitle,
      width: width,

      actions: actions,

      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Form content
            child,

            SizedBox(height: contentSpacing),

            // Action Buttons (Cancel | Save)
          Row(
            children: [
              Expanded(
                child: BasicButton(
                  label: "Cancel",
                  type: AppButtonType.secondary,
                  onPressed: onCancel ?? () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BasicButton(
                  label: "Save",
                  type: AppButtonType.primary,
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      onSave();
                    }
                  },
                ),
              ),
            ],
            )
          ],
        ),
      ),
    );
  }
}
