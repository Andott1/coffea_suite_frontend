import 'package:flutter/material.dart';
import '../../../config/theme_config.dart';
import '../../../core/models/user_model.dart';
import '../../../core/utils/format_utils.dart';
import 'employee_avatar.dart';

class EmployeeListItem extends StatelessWidget {
  final UserModel user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const EmployeeListItem({
    super.key,
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isInactive = !user.isActive;

    return Opacity(
      opacity: isInactive ? 0.6 : 1.0,
      child: Container(
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
            // 1. AVATAR (Matches Product/Ingredient style)
            EmployeeAvatar(
              name: user.fullName,
              role: user.role,
              size: 56,
            ),
            
            const SizedBox(width: 16),

            // 2. IDENTITY (Name & Username)
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700, 
                      fontSize: 16, 
                      color: Colors.black87
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "@${user.username}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            // 3. ROLE (Styled like Product Category Tag)
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildTag(user.role.name),
              ),
            ),

            // 4. RATE (Styled like Product Price)
            Expanded(
              flex: 2,
              child: Text(
                "${FormatUtils.formatCurrency(user.hourlyRate)} / hr",
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: ThemeConfig.primaryGreen, 
                  fontSize: 15
                ),
              ),
            ),

            // 5. STATUS DOT
            Tooltip(
              message: user.isActive ? "Active" : "Inactive",
              child: Container(
                width: 10, height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: user.isActive ? Colors.green : Colors.grey[300],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // 6. CONTEXT MENU
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
                  child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 10), Text("Edit Profile")]),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(user.isActive ? Icons.block : Icons.check_circle, size: 18, color: user.isActive ? Colors.orange : Colors.green),
                    const SizedBox(width: 10),
                    Text(user.isActive ? "Deactivate" : "Activate"),
                  ]),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 10), Text("Delete", style: TextStyle(color: Colors.red))]),
                ),
              ],
            ),
          ],
        ),
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