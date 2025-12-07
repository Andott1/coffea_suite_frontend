import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../core/models/product_model.dart';
import '../../../core/utils/format_utils.dart';
import 'product_avatar.dart';

class ProductListItem extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  const ProductListItem({
    super.key,
    required this.product,
    required this.onEdit,
    required this.onToggleStatus,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Price Formatting logic
    final prices = product.prices.values.toList()..sort();
    String priceDisplay = "No Price";
    if (prices.isNotEmpty) {
      if (prices.first == prices.last) {
        priceDisplay = FormatUtils.formatCurrency(prices.first);
      } else {
        priceDisplay = "${FormatUtils.formatCurrency(prices.first)} - ${FormatUtils.formatCurrency(prices.last)}";
      }
    }

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
          ProductAvatar(
            name: product.name,
            category: product.category,
            size: 56,
          ),
          
          const SizedBox(width: 16),

          // 2. Info Block
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildTag(product.category),
                    if (product.subCategory.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildTag(product.subCategory, isSub: true),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 3. Price Block
          Expanded(
            flex: 2,
            child: Text(
              priceDisplay,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: ThemeConfig.primaryGreen,
                fontSize: 15,
              ),
            ),
          ),

          // 4. Status Dot
          Tooltip(
            message: product.available ? "Active" : "Hidden",
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: product.available ? Colors.green : Colors.grey[300],
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
              if (value == 'toggle') onToggleStatus();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 10), Text("Edit")]),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(product.available ? Icons.visibility_off : Icons.visibility, size: 18),
                  const SizedBox(width: 10),
                  Text(product.available ? "Hide Product" : "Activate"),
                ]),
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

  Widget _buildTag(String text, {bool isSub = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSub ? Colors.grey[100] : ThemeConfig.lightGray,
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