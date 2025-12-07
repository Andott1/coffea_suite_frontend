import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../core/models/ingredient_model.dart';
import '../../../core/utils/format_utils.dart';
import 'ingredient_avatar.dart';

class IngredientListItem extends StatelessWidget {
  final IngredientModel ingredient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const IngredientListItem({
    super.key,
    required this.ingredient,
    required this.onEdit,
    required this.onDelete,
  });

  Color _getStockColor() {
    if (ingredient.quantity <= 0) return Colors.red;
    if (ingredient.quantity <= ingredient.reorderLevel) return Colors.orange;
    return ThemeConfig.primaryGreen;
  }

  String _getStockLabel() {
    if (ingredient.quantity <= 0) return "Out of Stock";
    if (ingredient.quantity <= ingredient.reorderLevel) return "Low Stock";
    return "Good";
  }

  @override
  Widget build(BuildContext context) {
    final stockColor = _getStockColor();
    
    // Format: "2,500.00 mL"
    final stockDisplay = "${FormatUtils.formatQuantity(ingredient.displayQuantity)} ${ingredient.unit}";
    final costDisplay = FormatUtils.formatCurrency(ingredient.unitCost);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          // 1. Avatar
          IngredientAvatar(
            name: ingredient.name,
            category: ingredient.category,
            size: 56,
          ),
          
          const SizedBox(width: 16),

          // 2. Info Block (Name & Category)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ingredient.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                _buildTag(ingredient.category),
              ],
            ),
          ),

          // 3. Stock Level
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  stockDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                Text(
                  _getStockLabel(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: stockColor,
                  ),
                ),
              ],
            ),
          ),

          // 4. Unit Cost
          Expanded(
            flex: 2,
            child: Text(
              costDisplay,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 5. Context Menu (⋮)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 10), Text("Edit Item")]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Text("Delete", style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ThemeConfig.lightGray,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }
}