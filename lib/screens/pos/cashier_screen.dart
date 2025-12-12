import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../config/font_config.dart';
import '../../config/theme_config.dart';
import '../../core/models/product_model.dart';
import '../../core/services/hive_service.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/dialog_utils.dart';
import 'bloc/pos_bloc.dart';
import 'bloc/pos_state.dart';
import 'bloc/pos_event.dart';

import '../../core/models/transaction_model.dart';
import '../../core/widgets/basic_button.dart'; 
import '../../core/services/supabase_sync_service.dart';
import 'bloc/stock_logic.dart';
import 'product_builder_dialog.dart';
import 'payment_screen.dart';
import 'widgets/cart_item_edit_dialog.dart';

class CashierScreen extends StatefulWidget {
  const CashierScreen({super.key});

  @override
  State<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends State<CashierScreen> {
  // ──────────────── STATE ────────────────
  String _selectedCategory = ""; 
  String _selectedSubCategory = ""; 
  String _searchQuery = "";
  
  bool _isQueueOpen = false; // Controls Mode A vs Mode B
  TransactionModel? _selectedOrder;

  // ──────────────── DATA HELPERS ────────────────
  
  List<ProductModel> _getFilteredProducts(List<ProductModel> allProducts) {
    return allProducts.where((p) {
      if (_searchQuery.isNotEmpty) {
        return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      if (p.category != _selectedCategory) return false;
      if (_selectedSubCategory.isNotEmpty && p.subCategory != _selectedSubCategory) return false;
      
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

  // ──────────────── QUEUE ACTIONS ────────────────
  
  Future<void> _updateStatus(TransactionModel txn, OrderStatus newStatus) async {
    txn.status = newStatus;
    await txn.save(); 

    SupabaseSyncService.addToQueue(
      table: 'transactions',
      action: 'UPDATE',
      data: {
        'id': txn.id,
        'status': newStatus.name,
      }
    );
    
    if (mounted) setState(() {});
  }

  Future<void> _confirmVoid(TransactionModel txn) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Void"),
        content: const Text("Are you sure you want to void this order?\nInventory will be restored."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Void Order", style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );

    if (confirm == true) {
      await _executeVoid(txn);
    }
  }

  Future<void> _executeVoid(TransactionModel txn) async {
    await StockLogic.restoreStock(txn.items, txn.id);

    final newTxn = TransactionModel(
      id: txn.id,
      dateTime: txn.dateTime,
      items: txn.items,
      totalAmount: txn.totalAmount,
      tenderedAmount: txn.tenderedAmount,
      paymentMethod: txn.paymentMethod,
      cashierName: txn.cashierName,
      referenceNo: txn.referenceNo,
      isVoid: true,               
      status: OrderStatus.voided, 
      orderType: txn.orderType,
    );

    await HiveService.transactionBox.put(txn.key, newTxn);

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
        'is_void': true, 
        'status': 'voided',
        'order_type': newTxn.orderType,
        'items': newTxn.items.map((i) => {
          'product_name': i.product.name,
          'variant': i.variant,
          'qty': i.quantity,
          'price': i.price,
          'discount': i.discount,
          'note': i.note ?? '',
          'total': i.total
        }).toList(),
      }
    );

    if (mounted) {
      DialogUtils.showToast(context, "Order Voided", accentColor: Colors.red);
      setState(() {
        if (_selectedOrder?.id == txn.id) _selectedOrder = null;
      });
    }
  }

  // ──────────────── MAIN LAYOUT ────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeConfig.lightGray,
      resizeToAvoidBottomInset: false, 
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─── LEFT PANEL (70%) ───
                Expanded(
                  flex: 7,
                  child: Column(
                    children: [
                      _buildHeaderBar(), // Mode Switcher
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isQueueOpen 
                              ? _buildKanbanBoard()       // MODE B: QUEUE
                              : _buildProductSelection(), // MODE A: PRODUCT GRID
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── RIGHT PANEL (30%) ───
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(left: BorderSide(color: Colors.grey.shade300)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(-2, 0))]
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _isQueueOpen 
                          ? _buildInspectorPane() // MODE B: INSPECTOR
                          : _buildCartSidebar(),  // MODE A: CART
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── HEADER / MODE SWITCHER ────────────────
  Widget _buildHeaderBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // TITLE
          Text(
            _isQueueOpen ? "Order Management" : "Cashier",
            style: FontConfig.h2(context).copyWith(color: Colors.black87),
          ),

          // MODE TOGGLE BUTTON
          ValueListenableBuilder(
            valueListenable: HiveService.transactionBox.listenable(),
            builder: (context, Box<TransactionModel> box, _) {
              final activeCount = box.values.where((t) => 
                t.status == OrderStatus.pending || t.status == OrderStatus.ready
              ).length;

              return InkWell(
                onTap: () => setState(() => _isQueueOpen = !_isQueueOpen),
                borderRadius: BorderRadius.circular(12),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isQueueOpen ? ThemeConfig.primaryGreen : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _isQueueOpen ? ThemeConfig.primaryGreen : Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.list_alt, 
                        color: _isQueueOpen ? Colors.white : Colors.black87
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Queue ($activeCount)",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isQueueOpen ? Colors.white : Colors.black87
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          ),
        ],
      ),
    );
  }

  // ──────────────── MODE A: PRODUCT SELECTION ────────────────
  Widget _buildProductSelection() {
    return ValueListenableBuilder(
      valueListenable: HiveService.productBox.listenable(),
      builder: (context, Box<ProductModel> box, _) {
        final allProducts = box.values.toList();
        final categories = allProducts.map((p) => p.category).where((c) => c.isNotEmpty).toSet().toList()..sort();

        if (categories.isEmpty) {
          return Center(child: Text("No products found.", style: FontConfig.h2(context).copyWith(color: Colors.grey)));
        }

        // Auto-Select Logic
        if (_selectedCategory.isEmpty || !categories.contains(_selectedCategory)) {
          _selectedCategory = categories.first;
          _selectedSubCategory = ""; 
        }

        final subCategories = allProducts
            .where((p) => p.category == _selectedCategory)
            .map((p) => p.subCategory).where((s) => s.isNotEmpty).toSet().toList()..sort();

        if (subCategories.isNotEmpty && (_selectedSubCategory.isEmpty || !subCategories.contains(_selectedSubCategory))) {
          _selectedSubCategory = subCategories.first;
        } else if (subCategories.isEmpty) {
          _selectedSubCategory = "";
        }

        final products = _getFilteredProducts(allProducts);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Categories
            SizedBox(
              height: 70, 
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_,__) => const SizedBox(width: 16),
                itemBuilder: (context, index) => _buildWideCategoryCard(categories[index]),
              ),
            ),
            const SizedBox(height: 16),
            // Sub-Categories
            if (subCategories.isNotEmpty)
              SizedBox(
                height: 45,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: subCategories.length,
                  separatorBuilder: (_,__) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final sub = subCategories[index];
                    final isSelected = _selectedSubCategory == sub;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSubCategory = sub),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? ThemeConfig.coffeeBrown : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isSelected ? ThemeConfig.coffeeBrown : Colors.grey.shade300),
                          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
                        ),
                        child: Text(sub, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.grey[700])),
                      ),
                    );
                  },
                ),
              ),
            
            // Grid
            Expanded(
              child: products.isEmpty
                ? Center(child: Text("No products here.", style: FontConfig.body(context).copyWith(color: Colors.grey)))
                : GridView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: products.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, 
                      childAspectRatio: 1.1, 
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemBuilder: (context, index) => _buildProductCard(products[index]),
                  ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWideCategoryCard(String category) {
    final isSelected = _selectedCategory == category;
    final color = ThemeConfig.primaryGreen;
    return GestureDetector(
      onTap: () => setState(() { _selectedCategory = category; _selectedSubCategory = ""; }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 180, 
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isSelected ? 0.3 : 0.05), blurRadius: isSelected ? 8 : 4, offset: const Offset(0, 4))],
          border: isSelected ? null : Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 24, color: isSelected ? Colors.white.withValues(alpha: 0.9) : color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                category.toUpperCase(),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isSelected ? Colors.white : Colors.black87, letterSpacing: 0.5),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductModel product) {
    final color = _getProductColor(product);
    final bool isVisible = product.available;

    return ValueListenableBuilder(
      valueListenable: HiveService.ingredientBox.listenable(),
      builder: (context, _, __) {
          final bool inStock = StockLogic.isProductAvailable(product);
          final bool isSellable = isVisible && inStock;

          return BlocBuilder<PosBloc, PosState>(
            builder: (context, state) {
              final qtyInCart = state.cart.where((item) => item.product.id == product.id).fold(0, (sum, item) => sum + item.quantity);

              return GestureDetector(
                onTap: () {
                  if (!isVisible) return DialogUtils.showToast(context, "Item INACTIVE", icon: Icons.block, accentColor: Colors.red);
                  if (!inStock) return DialogUtils.showToast(context, "Item SOLD OUT", icon: Icons.block, accentColor: Colors.red);
                  if (product.prices.isNotEmpty) showDialog(context: context, builder: (_) => ProductBuilderDialog(product: product));
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
                              color: isSellable ? color : Colors.grey[400],
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
      },
    );
  }

  // ──────────────── MODE B: KANBAN BOARD ────────────────
  Widget _buildKanbanBoard() {
    return ValueListenableBuilder(
      valueListenable: HiveService.transactionBox.listenable(),
      builder: (context, Box<TransactionModel> box, _) {
        final all = box.values.toList();
        all.sort((a,b) => a.dateTime.compareTo(b.dateTime));
        
        final pending = all.where((t) => t.status == OrderStatus.pending).toList();
        final ready = all.where((t) => t.status == OrderStatus.ready).toList();
        final held = all.where((t) => t.status == OrderStatus.held).toList();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              _buildKanbanColumn("Held / Parked", Colors.orange, held),
              const SizedBox(width: 16),
              _buildKanbanColumn("Pending", Colors.blue, pending),
              const SizedBox(width: 16),
              _buildKanbanColumn("Ready to Serve", Colors.green, ready),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKanbanColumn(String title, Color color, List<TransactionModel> transactions) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Text(title.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  Text("${transactions.length} Orders", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Expanded(
              child: transactions.isEmpty 
                ? Center(child: Text("Empty", style: TextStyle(color: Colors.grey[400])))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final t = transactions[index];
                      final isSelected = _selectedOrder?.id == t.id;
                      
                      return InkWell(
                        onTap: () => setState(() => _selectedOrder = t),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected ? ThemeConfig.midGray.withValues(alpha: 0.05) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? ThemeConfig.primaryGreen : Colors.transparent,
                              width: 2
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2)
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "#${t.id.substring(0,4)}", 
                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.black87)
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4)),
                                    child: Text(DateFormat('hh:mm a').format(t.dateTime), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Items Preview (First 2)
                              ...t.items.take(2).map((i) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Text(
                                  "${i.quantity}x ${i.product.name}",
                                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  overflow: TextOverflow.ellipsis
                                ),
                              )),
                              if (t.items.length > 2)
                                Text("+ ${t.items.length - 2} more...", style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
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

  // ──────────────── RIGHT PANEL: INSPECTOR ────────────────
  Widget _buildInspectorPane() {
    if (_selectedOrder == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text("Select an order to view details", style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    final t = _selectedOrder!;
    final timeElapsed = DateTime.now().difference(t.dateTime);
    String timeStr = "${timeElapsed.inMinutes}m ago";
    if (timeElapsed.inMinutes > 60) timeStr = "${timeElapsed.inHours}h ago";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. HEADER
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200))
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Order #${t.id.substring(0,8)}", style: FontConfig.h2(context)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                    child: Text(timeStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text("Cashier: ${t.cashierName}", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  const SizedBox(width: 16),
                  if (t.orderType == "takeOut") 
                    const Chip(label: Text("Take Out", style: TextStyle(fontSize: 10)), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
                ],
              ),
            ],
          ),
        ),

        // 2. ITEM LIST
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: t.items.length,
            separatorBuilder: (_,__) => const Divider(height: 24),
            itemBuilder: (context, index) {
              final item = t.items[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("${item.quantity}x", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            if (item.variant.isNotEmpty)
                              Text(item.variant, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            
                            if (item.note != null && item.note!.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.yellow.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text("📝 ${item.note}", style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w600)),
                              ),
                            
                            if (item.discount > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text("🏷️ Discount: -${FormatUtils.formatCurrency(item.discount)}", style: const TextStyle(fontSize: 12, color: Colors.red)),
                              )
                          ],
                        ),
                      ),
                      Text(FormatUtils.formatCurrency(item.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),

        // 3. FOOTER ACTIONS
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(top: BorderSide(color: Colors.grey.shade200))
          ),
          child: Column(
            children: [
              // PENDING ACTIONS
              if (t.status == OrderStatus.pending) ...[
                // Primary: Ready
                BasicButton(
                  label: "MARK READY", 
                  type: AppButtonType.primary, 
                  height: 60, // Jumbo Height
                  fontSize: 18,
                  icon: Icons.check_circle_outline, 
                  onPressed: () => _updateStatus(t, OrderStatus.ready)
                ),
                const SizedBox(height: 12),
                
                // Secondary: Hold
                BasicButton(
                  label: "Hold Order", 
                  type: AppButtonType.neutral, 
                  height: 50, 
                  icon: Icons.pause_circle_outline,
                  onPressed: () => _updateStatus(t, OrderStatus.held)
                ),
              ],
              
              // READY ACTIONS
              if (t.status == OrderStatus.ready) ...[
                // Primary: Serve
                BasicButton(
                  label: "SERVE / COMPLETE", 
                  type: AppButtonType.primary, 
                  height: 60, // Jumbo Height
                  fontSize: 18,
                  icon: Icons.done_all, 
                  onPressed: () => _updateStatus(t, OrderStatus.served)
                ),
                const SizedBox(height: 12),
                
                // Secondary: Return
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => _updateStatus(t, OrderStatus.pending),
                    icon: const Icon(Icons.undo, size: 20),
                    label: const Text("Return to Pending", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                    ),
                  ),
                ),
              ],

              // HELD ACTIONS
              if (t.status == OrderStatus.held) ...[
                BasicButton(
                  label: "Resume Order", 
                  type: AppButtonType.primary, 
                  height: 60, 
                  fontSize: 18,
                  icon: Icons.play_arrow, 
                  onPressed: () => _updateStatus(t, OrderStatus.pending)
                ),
              ],

              const SizedBox(height: 16),
              
              // UNIVERSAL VOID (Small & Safe at bottom)
              TextButton.icon(
                onPressed: () => _confirmVoid(t),
                icon: const Icon(Icons.delete_forever, color: Colors.red, size: 20),
                label: const Text("Void Transaction", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              )
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────── RIGHT PANEL: CART ────────────────
  Widget _buildCartSidebar() {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        final vatableSales = state.total / 1.12;
        final vatAmount = state.total - vatableSales;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Current Order", style: FontConfig.h2(context)),
                  Text("${state.cart.length} items", style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 45,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    _buildOrderTypeToggle("Dine-In", OrderType.dineIn, state.orderType),
                    _buildOrderTypeToggle("Take-Out", OrderType.takeOut, state.orderType),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: state.cart.isEmpty
                ? Center(child: Text("Cart is empty", style: TextStyle(color: Colors.grey[400])))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: state.cart.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = state.cart[index];
                      return Material(
                        color: Colors.white,
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (_) => CartItemEditDialog(
                                item: item,
                                onRemove: () {
                                  context.read<PosBloc>().add(PosRemoveItem(item.id));
                                },
                                onUpdate: (qty, discount, note) {
                                  context.read<PosBloc>().add(PosEditCartItem(
                                    cartItemId: item.id,
                                    quantity: qty,
                                    discount: discount,
                                    note: note,
                                  ));
                                },
                              )
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                          Text(
                                            item.variant.isNotEmpty ? item.variant : "Standard", 
                                            style: const TextStyle(fontSize: 13, color: Colors.grey)
                                          ),
                                          if (item.note != null && item.note!.isNotEmpty)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 2),
                                              child: Text(
                                                "Note: ${item.note}", 
                                                style: const TextStyle(fontSize: 12, color: Colors.orange, fontStyle: FontStyle.italic)
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(FormatUtils.formatCurrency(item.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                                        if (item.discount > 0)
                                          Text(
                                            "-${FormatUtils.formatCurrency(item.discount)}",
                                            style: const TextStyle(fontSize: 11, color: Colors.red),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
            ),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
              child: Column(
                children: [
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
                          child: const Text("Clear", style: TextStyle(color: ThemeConfig.primaryGreen, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (state.cart.isEmpty) return DialogUtils.showToast(context, "Cart is empty!", icon: Icons.warning, accentColor: Colors.orange);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ThemeConfig.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text("Proceed to Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
}