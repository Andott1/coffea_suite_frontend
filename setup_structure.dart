import 'dart:io';

void main() async {
  final directories = [
    'lib/config',
    'lib/core/models',
    'lib/core/providers',
    'lib/core/services',
    'lib/core/utils',
    'lib/core/widgets',
    'lib/screens/startup',
    'lib/screens/pos',
    'lib/screens/inventory',
    'lib/screens/attendance',
    'lib/screens/admin',
    'lib/scripts',
    'assets/logo',
    'assets/fonts',
    'assets/icons',
  ];

  final files = {
    // config
    'lib/config/font_config.dart': '',
    'lib/config/theme_config.dart': '',
    'lib/config/pricing_config.dart': '',
    'lib/config/role_config.dart': '',

    // models
    'lib/core/models/product_model.dart': '',
    'lib/core/models/order_item_model.dart': '',
    'lib/core/models/order_model.dart': '',
    'lib/core/models/size_price_model.dart': '',
    'lib/core/models/attendance_model.dart': '',
    'lib/core/models/employee_model.dart': '',
    'lib/core/models/payroll_model.dart': '',

    // providers
    'lib/core/providers/order_provider.dart': '',
    'lib/core/providers/inventory_provider.dart': '',
    'lib/core/providers/attendance_provider.dart': '',
    'lib/core/providers/employee_provider.dart': '',

    // services
    'lib/core/services/hive_service.dart': '',
    'lib/core/services/order_service.dart': '',
    'lib/core/services/inventory_service.dart': '',
    'lib/core/services/attendance_service.dart': '',
    'lib/core/services/payroll_service.dart': '',
    'lib/core/services/employee_service.dart': '',

    // utils
    'lib/core/utils/date_utils.dart': '',
    'lib/core/utils/format_utils.dart': '',
    'lib/core/utils/dialog_utils.dart': '',

    // widgets
    'lib/core/widgets/custom_button.dart': '',
    'lib/core/widgets/custom_card.dart': '',
    'lib/core/widgets/topbar.dart': '',
    'lib/core/widgets/modal_dialog.dart': '',

    // screens
    'lib/screens/startup/startup_screen.dart': '',
    'lib/screens/pos/pos_dashboard.dart': '',
    'lib/screens/pos/cashier_screen.dart': '',
    'lib/screens/pos/transaction_history_screen.dart': '',
    'lib/screens/pos/pos_topbar.dart': '',
    'lib/screens/pos/payment_screen.dart': '',
    'lib/screens/inventory/inventory_dashboard.dart': '',
    'lib/screens/inventory/product_list_screen.dart': '',
    'lib/screens/inventory/product_edit_screen.dart': '',
    'lib/screens/inventory/stock_adjustment_screen.dart': '',
    'lib/screens/inventory/inventory_topbar.dart': '',
    'lib/screens/attendance/attendance_screen.dart': '',
    'lib/screens/attendance/attendance_logs_screen.dart': '',
    'lib/screens/attendance/payroll_screen.dart': '',
    'lib/screens/attendance/attendance_topbar.dart': '',
    'lib/screens/admin/admin_dashboard_screen.dart': '',
    'lib/screens/admin/analytics_screen.dart': '',
    'lib/screens/admin/employee_management_screen.dart': '',
    'lib/screens/admin/settings_screen.dart': '',
    'lib/screens/admin/admin_topbar.dart': '',

    // scripts
    'lib/scripts/seed_products.dart': '',

    // structure reference
    'lib/structure.txt': '',
  };

  for (final dir in directories) {
    final d = Directory(dir);
    if (!await d.exists()) {
      await d.create(recursive: true);
      print('📁 Created directory: $dir');
    }
  }

  for (final entry in files.entries) {
    final file = File(entry.key);
    if (!await file.exists()) {
      await file.writeAsString('// ${entry.key.split('/').last} generated\n');
      print('📝 Created file: ${entry.key}');
    }
  }

  print('\n✅ Project structure generated successfully!\n');
}
