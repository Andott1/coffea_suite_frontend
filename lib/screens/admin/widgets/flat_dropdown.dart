import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';

class FlatDropdown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String label;
  final IconData icon;

  const FlatDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.label,
    this.icon = Icons.filter_list,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
          borderRadius: BorderRadius.circular(12),
          items: items.map((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item == value) ...[
                    Icon(icon, size: 16, color: ThemeConfig.primaryGreen),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    item.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: item == value ? FontWeight.bold : FontWeight.w500,
                      color: item == value ? ThemeConfig.primaryGreen : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}