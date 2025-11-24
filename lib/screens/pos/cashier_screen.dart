import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // For time formatting
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/product_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/dialog_utils.dart';
import 'bloc/pos_bloc.dart';
import 'bloc/pos_state.dart';
import 'bloc/pos_event.dart';

import '../../core/models/transaction_model.dart'; // ✅ Import

import '../../core/widgets/basic_button.dart'; // Used in dialog

import '../../core/services/supabase_sync_service.dart';

import 'product_builder_dialog.dart';
import 'payment_screen.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  // ──────────────── STATE ────────────────
  String _selectedCategory = "Drinks"; 
  String _selectedSubCategory = "Coffee"; 
  String _searchQuery = "";
  
  // ✅ NEW: Queue Drawer State
  bool _isQueueOpen = false;

  // ──────────────── HELPER: DATA FILTERING ────────────────
  List<ProductModel> _getFilteredProducts() {
    final box = HiveService.productBox;
    return box.values.where((p) {
      if (p.category != _selectedCategory) return false;
      if (_selectedSubCategory.isNotEmpty && p.subCategory != _selectedSubCategory) return false;
      if (_searchQuery.isNotEmpty && !p.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
  }

  Color _getProductColor(ProductModel p) {
    if (p.isDrink) return const Color(0xFF8D6E63); 
    if (p.subCategory == "Non-Coffee") return const Color(0xFF81C784); 
    if (p.isMeal) return const Color(0xFFFFCC80); 
    if (p.isDessert) return const Color(0xFFF48FB1); 
    return Colors.grey.shade300;
  }

  // ──────────────── QUEUE LOGIC ────────────────
  
  void _updateStatus(TransactionModel txn, OrderStatus newStatus) async {
    // 1. Update Local Hive
    txn.status = newStatus;
    await txn.save(); 

    // 2. ✅ Sync to Supabase
    SupabaseSyncService.addToQueue(
      table: 'transactions',
      action: 'UPSERT',
      data: {
        'id': txn.id,
        'date_time': txn.dateTime.toIso8601String(),
        'total_amount': txn.totalAmount,
        'tendered_amount': txn.tenderedAmount,
        'payment_method': txn.paymentMethod,
        'cashier_name': txn.cashierName,
        'reference_no': txn.referenceNo,
        'is_void': txn.isVoid,
        
        // ✅ SYNC UPDATED STATUS
        'status': newStatus.name, 
        
        // Don't forget order_type!
        'order_type': txn.orderType, 

        // We must resend items because UPSERT replaces the row
        'items': txn.items.map((i) => {
          'product_name': i.product.name,
          'variant': i.variant,
          'qty': i.quantity,
          'price': i.price,
          'total': i.total
        }).toList(),
      }
    );

    if(mounted) Navigator.pop(context); // Close dialog
  }

  void _voidTransaction(TransactionModel txn) async {
    // 1. Create a new copy with isVoid = true
    final newTxn = TransactionModel(
      id: txn.id,
      dateTime: txn.dateTime,
      items: txn.items,
      totalAmount: txn.totalAmount,
      tenderedAmount: txn.tenderedAmount,
      paymentMethod: txn.paymentMethod,
      cashierName: txn.cashierName,
      referenceNo: txn.referenceNo,
      isVoid: true,               // ✅ FORCE TRUE
      status: OrderStatus.voided, // ✅ FORCE STATUS
      orderType: txn.orderType,
    );

    // 2. Replace in Local Hive (using the same key to overwrite)
    await HiveService.transactionBox.put(txn.key, newTxn);

    // 3. Sync to Supabase with correct flags
    SupabaseSyncService.addToQueue(
      table: 'transactions',
      action: 'UPSERT',
      data: {
        'id': newTxn.id,
        'date_time': newTxn.dateTime.toIso8601String(),
        'total_amount': newTxn.totalAmount,
        'tendered_amount': newTxn.tenderedAmount,
        'payment_method': newTxn.paymentMethod,
        'cashier_name': newTxn.cashierName,
        'reference_no': newTxn.referenceNo,
        'is_void': true, // ✅ Explicitly sending TRUE
        'status': 'voided',
        'order_type': newTxn.orderType,
        'items': newTxn.items.map((i) => {
          'product_name': i.product.name,
          'variant': i.variant,
          'qty': i.quantity,
          'price': i.price,
          'total': i.total
        }).toList(),
      }
    );

    if (mounted) {
      Navigator.pop(context); // Close dialog
      DialogUtils.showToast(context, "Order Voided", accentColor: Colors.red);
    }
  }

  void _showOrderOptions(TransactionModel txn) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Order #${txn.id.substring(0,4)} Options"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Current Status: ${txn.status.name.toUpperCase()}"),
              const SizedBox(height: 20),
              
              // ACTIONS FOR PENDING
              if (txn.status == OrderStatus.pending) ...[
                _actionBtn("Mark Ready", Colors.green, () => _updateStatus(txn, OrderStatus.ready)),
                _actionBtn("Hold Order", Colors.orange, () => _updateStatus(txn, OrderStatus.held)),
              ],

              // ACTIONS FOR READY
              if (txn.status == OrderStatus.ready) ...[
                _actionBtn("Serve / Complete", Colors.blue, () => _updateStatus(txn, OrderStatus.served)),
                _actionBtn("Return to Pending", Colors.grey, () => _updateStatus(txn, OrderStatus.pending)),
              ],

              // ACTIONS FOR HELD
              if (txn.status == OrderStatus.held) ...[
                _actionBtn("Resume (Pending)", Colors.blue, () => _updateStatus(txn, OrderStatus.pending)),
              ],

              const Divider(height: 30),
              
              _actionBtn("Void Transaction", Colors.red, () {
                 // Future: Add logic to refund stock?
                 _voidTransaction(txn);
                 DialogUtils.showToast(context, "Order Voided");
              }),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))
          ],
        );
      }
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: BasicButton(
        label: label,
        type: AppButtonType.primary, // Using primary for simplicity, customizing color via container if needed or just rely on text
        // Since BasicButton wraps logic, let's just use ElevatedButton for custom colors in this specific dialog
        // or create a custom BasicButton style. For speed, I'll use standard ElevatedButton here.
        onPressed: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ────────────────────────────────────────────
          // LEFT SIDE: PRODUCT SELECTION & QUEUE DRAWER (Flex 3)
          // ────────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                // ─── LAYER 1: THE MAIN CASHIER UI ───
                // We add padding top so it sits BELOW the handle
                Padding(
                  padding: const EdgeInsets.only(top: 70), 
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Selector
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          child: Row(
                            children: [
                              _buildBigCategoryCard("Drinks", Icons.local_cafe, const Color(0xFF1B3E2F)),
                              const SizedBox(width: 12),
                              _buildBigCategoryCard("Meals", Icons.restaurant, const Color(0xFFE0F2F1)),
                              const SizedBox(width: 12),
                              _buildBigCategoryCard("Desserts", Icons.cake, const Color(0xFFE0F2F1)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Sub-Categories
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _getSubCategories().map((sub) {
                              final isSelected = _selectedSubCategory == sub;
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: FilterChip(
                                  label: Text(sub),
                                  selected: isSelected,
                                  onSelected: (v) => setState(() => _selectedSubCategory = sub),
                                  backgroundColor: Colors.white,
                                  selectedColor: const Color(0xFF6D4C41),
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  checkmarkColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  side: BorderSide.none,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Product Grid
                      Expanded(
                        child: ValueListenableBuilder(
                          valueListenable: HiveService.productBox.listenable(),
                          builder: (context, _, __) {
                            final products = _getFilteredProducts();
                            if (products.isEmpty) return const Center(child: Text("No products found."));

                            return GridView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: products.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 1,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemBuilder: (context, index) => _buildProductCard(products[index]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── LAYER 2: KANBAN OVERLAY (UPDATED) ───
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  top: _isQueueOpen ? 60 : -MediaQuery.of(context).size.height,
                  left: 0, right: 0,
                  bottom: _isQueueOpen ? 0 : MediaQuery.of(context).size.height,
                  child: Container(
                    color: const Color(0xFFF5F5F5),
                    // ✅ FIX: Load Real Data
                    child: ValueListenableBuilder(
                      valueListenable: HiveService.transactionBox.listenable(),
                      builder: (context, Box<TransactionModel> box, _) {
                        final all = box.values.toList();
                        // Filter active orders (ignore voided/served for this view usually, 
                        // but you might want served in a separate "Done" column. 
                        // For now, sticking to your request: Pending / Ready / Held)
                        
                        final pending = all.where((t) => t.status == OrderStatus.pending).toList();
                        final ready = all.where((t) => t.status == OrderStatus.ready).toList();
                        final held = all.where((t) => t.status == OrderStatus.held).toList();

                        return _buildKanbanBoard(pending, ready, held);
                      },
                    ),
                  ),
                ),

                // ─── LAYER 3: HANDLE (UPDATED BADGE) ───
                Positioned(
                  top: 0, left: 0, right: 0, height: 80,
                  child: GestureDetector(
                    onTap: () => setState(() => _isQueueOpen = !_isQueueOpen),
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: ThemeConfig.primaryGreen,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_isQueueOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white),
                          const SizedBox(width: 12),
                          const Text("ORDER QUEUE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(width: 12),
                          // ✅ Live Badge
                          ValueListenableBuilder(
                            valueListenable: HiveService.transactionBox.listenable(),
                            builder: (context, Box<TransactionModel> box, _) {
                              final activeCount = box.values.where((t) => 
                                t.status == OrderStatus.pending || t.status == OrderStatus.ready
                              ).length;
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                child: Text("$activeCount Active", style: const TextStyle(color: Colors.white, fontSize: 12)),
                              );
                            }
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ────────────────────────────────────────────
          // RIGHT SIDE: CART SIDEBAR (Unchanged)
          // ────────────────────────────────────────────
          Container(
            width: 400, 
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: _buildCartSidebar(),
          ),
        ],
      ),
    );
  }

  // ──────────────── REAL KANBAN BOARD ────────────────
  Widget _buildKanbanBoard(
    List<TransactionModel> pending, 
    List<TransactionModel> ready, 
    List<TransactionModel> held
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Held
          _buildKanbanColumn("Held / Parked", Colors.orange, held),
          const SizedBox(width: 16),
          // Pending
          _buildKanbanColumn("Pending", Colors.blue, pending),
          const SizedBox(width: 16),
          // Ready
          _buildKanbanColumn("Ready to Serve", Colors.green, ready),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(String title, Color color, List<TransactionModel> transactions) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
              ),
              width: double.infinity,
              child: Text(
                "${title.toUpperCase()} (${transactions.length})",
                textAlign: TextAlign.center,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
            // List
            Expanded(
              child: transactions.isEmpty 
                ? Center(child: Text("No orders", style: TextStyle(color: Colors.grey[400])))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      
                      // Summarize items
                      String summary = "${t.items.length} Items";
                      if (t.items.isNotEmpty) {
                        summary = "${t.items[0].quantity}x ${t.items[0].product.name}";
                        if (t.items.length > 1) summary += " +${t.items.length - 1} more";
                      }

                      return InkWell(
                        onTap: () => _showOrderOptions(t),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0,2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("#${t.id.substring(0,4)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text(DateFormat('hh:mm a').format(t.dateTime), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(summary, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                                child: Text("Total: ${FormatUtils.formatCurrency(t.totalAmount)}", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── CART SIDEBAR ────────────────
  Widget _buildCartSidebar() {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        final vatableSales = state.total / 1.12;
        final vatAmount = state.total - vatableSales;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Current Order", style: FontConfig.h2(context)),
                Text("${state.cart.length} items", style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 20),

            // Toggle
            Container(
              height: 45,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  _buildOrderTypeToggle("Dine-In", OrderType.dineIn, state.orderType),
                  _buildOrderTypeToggle("Take-Out", OrderType.takeOut, state.orderType),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Items
            Expanded(
              child: state.cart.isEmpty
                ? Center(child: Text("Cart is empty", style: TextStyle(color: Colors.grey[400])))
                : ListView.separated(
                    itemCount: state.cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = state.cart[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                  Text(item.variant, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                                ],
                              ),
                            ),
                            Text(FormatUtils.formatCurrency(item.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    },
                  ),
            ),

            const Divider(thickness: 2),
            const SizedBox(height: 16),

            _buildSummaryRow("Vatable Sales", vatableSales),
            _buildSummaryRow("VAT (12%)", vatAmount),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("TOTAL", style: FontConfig.h2(context).copyWith(fontWeight: FontWeight.w800)),
                Text(FormatUtils.formatCurrency(state.total), style: FontConfig.h1(context).copyWith(color: ThemeConfig.primaryGreen)),
              ],
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      DialogUtils.showToast(context, "Clearing Cart...");
                      context.read<PosBloc>().add(PosClearCart());
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: ThemeConfig.primaryGreen),
                    ),
                    child: const Text("Clear Cart", style: TextStyle(color: ThemeConfig.primaryGreen, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      if (state.cart.isEmpty) {
                        DialogUtils.showToast(context, "Cart is empty!", icon: Icons.warning, accentColor: Colors.orange);
                        return;
                      }
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const PaymentScreen())
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeConfig.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Proceed to Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        );
      }
    );
  }

  // ──────────────── CATEGORY & PRODUCT WIDGETS ────────────────
  Widget _buildBigCategoryCard(String title, IconData icon, Color bgColor) {
    final isSelected = _selectedCategory == title;
    final fgColor = isSelected ? Colors.white : Colors.black87;
    final activeBg = isSelected ? const Color(0xFF1B3E2F) : Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() { _selectedCategory = title; _selectedSubCategory = _getSubCategories().first; }),
        child: Container(
          decoration: BoxDecoration(
            color: activeBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Stack(
            children: [
              Positioned(right: -10, bottom: -10, child: Icon(icon, size: 80, color: fgColor.withValues(alpha: 0.1))),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: fgColor)),
                    const Spacer(),
                    if(isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 18)
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final color = _getProductColor(product);
    final bool isAvailable = product.available;

    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        final qtyInCart = state.cart.where((item) => item.product.id == product.id).fold(0, (sum, item) => sum + item.quantity);

        return GestureDetector(
          onTap: () {
            if (!isAvailable) {
              DialogUtils.showToast(context, "Item is unavailable", icon: Icons.block, accentColor: Colors.red);
              return;
            }
            // TEMPORARY: Direct Add (Simulate selecting first variant)
            if (product.prices.isNotEmpty) {
              showDialog(
                context: context, 
                builder: (_) => ProductBuilderDialog(product: product)
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        color: isAvailable ? color : Colors.grey[400],
                        child: Icon(product.isDrink ? Icons.local_cafe : Icons.restaurant, color: Colors.white.withValues(alpha: 0.5), size: 40),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            Text(
                              FormatUtils.formatCurrency(product.prices.values.isEmpty ? 0 : product.prices.values.reduce((a, b) => a < b ? a : b)),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isAvailable)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    alignment: Alignment.center,
                    child: const Text("NOT\nAVAILABLE", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                if (qtyInCart > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(color: ThemeConfig.primaryGreen, shape: BoxShape.circle),
                      child: Text("$qtyInCart", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildOrderTypeToggle(String label, OrderType type, OrderType current) {
    final isSelected = type == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<PosBloc>().add(PosToggleOrderType(type)),
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1B3E2F) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black54, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          Text(FormatUtils.formatCurrency(value), style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<String> _getSubCategories() {
    return HiveService.productBox.values.where((p) => p.category == _selectedCategory).map((p) => p.subCategory).toSet().toList()..sort();
  }
}
/// <<END FILE>>