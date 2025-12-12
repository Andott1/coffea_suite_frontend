import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../config/theme_config.dart';
import '../../config/font_config.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/dialog_utils.dart';
import '../../core/widgets/basic_button.dart'; // Reusing your button
import '../../core/widgets/basic_input_field.dart'; // Reusing input
import '../../core/widgets/numeric_pad.dart'; // Reusing keypad
import 'bloc/pos_bloc.dart';
import 'bloc/pos_state.dart';
import 'bloc/pos_event.dart';

enum PaymentMethod { cash, card, eWallet }

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  
  // Cash State
  String _tenderedStr = "";

  // Digital State
  final TextEditingController _referenceCtrl = TextEditingController();

  // ──────────────── LOGIC ────────────────
  void _onKeypadInput(String value) {
    setState(() {
      if (value == "." && _tenderedStr.contains(".")) return;
      if (_tenderedStr.length > 9) return; 
      _tenderedStr += value;
    });
  }

  void _onClear() => setState(() => _tenderedStr = "");
  
  void _onBackspace() {
    if (_tenderedStr.isNotEmpty) {
      setState(() => _tenderedStr = _tenderedStr.substring(0, _tenderedStr.length - 1));
    }
  }

  void _setExact(double total) {
    setState(() => _tenderedStr = total.toStringAsFixed(2));
  }

  void _addBill(int amount) {
    double current = double.tryParse(_tenderedStr) ?? 0;
    setState(() => _tenderedStr = (current + amount).toStringAsFixed(0));
  }

  void _processPayment(BuildContext context, double totalAmount) {
    // 1. VALIDATION
    if (_selectedMethod == PaymentMethod.cash) {
      final tendered = double.tryParse(_tenderedStr) ?? 0;
      if (tendered < FormatUtils.roundDouble(totalAmount)) { 
        DialogUtils.showToast(context, "Insufficient cash tendered.", icon: Icons.error, accentColor: Colors.red);
        return;
      }
    } else {
      // Card / E-Wallet Validation
      if (_referenceCtrl.text.trim().isEmpty) {
        DialogUtils.showToast(context, "Reference number is required.", icon: Icons.error, accentColor: Colors.red);
        return;
      }
    }

    // 2. EXECUTE BLOC EVENT
    // We calculate the final tendered amount based on method
    final finalTendered = _selectedMethod == PaymentMethod.cash 
        ? (double.tryParse(_tenderedStr) ?? 0)
        : totalAmount; // For cards, tendered = total

    context.read<PosBloc>().add(PosConfirmPayment(
      totalAmount: totalAmount,
      tenderedAmount: finalTendered,
      paymentMethod: _selectedMethod.name,
      referenceNo: _selectedMethod == PaymentMethod.cash ? null : _referenceCtrl.text,
    ));

    // 3. SHOW SUCCESS & NAVIGATE
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.check_circle, color: ThemeConfig.primaryGreen, size: 80),
            const SizedBox(height: 20),
            Text("Payment Successful!", style: FontConfig.h2(context)),
            const SizedBox(height: 8),
            if (_selectedMethod == PaymentMethod.cash)
              Text(
                "Change: ${FormatUtils.formatCurrency(finalTendered - totalAmount)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            const SizedBox(height: 30),
            BasicButton(
              label: "New Order", 
              type: AppButtonType.primary, 
              onPressed: () {
                Navigator.of(context).pop(); // Close Dialog
                Navigator.of(context).pop(); // Close Payment Screen (Back to Cashier)
              }
            )
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosBloc, PosState>(
      builder: (context, state) {
        final total = state.total;
        final tendered = double.tryParse(_tenderedStr) ?? 0;
        final change = tendered - total;
        final vatable = total / 1.12;
        final vat = total - vatable;

        return Scaffold(
          backgroundColor: ThemeConfig.lightGray,
          appBar: AppBar(
            title: const Text("Checkout"),
            centerTitle: true,
            elevation: 0,
            backgroundColor: ThemeConfig.primaryGreen,
          ),
          body: Row(
            children: [
              // ──────────────── LEFT: BILL SUMMARY (STATIC) ────────────────
              Expanded(
                flex: 4,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Due", style: FontConfig.body(context).copyWith(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        FormatUtils.formatCurrency(total),
                        style: FontConfig.h1(context).copyWith(fontSize: 48, color: ThemeConfig.primaryGreen),
                      ),
                      
                      const SizedBox(height: 30),
                      const Divider(),
                      const SizedBox(height: 10),
                      
                      // Breakdown
                      _buildLineItem("Order Items", "${state.cart.length} items"),
                      _buildLineItem("Vatable Sales", FormatUtils.formatCurrency(vatable)),
                      _buildLineItem("VAT (12%)", FormatUtils.formatCurrency(vat)),
                      const SizedBox(height: 10),
                      const Divider(),
                      const SizedBox(height: 10),
                      _buildLineItem("Order Type", state.orderType == OrderType.dineIn ? "Dine-In" : "Take-Out"),

                      const Spacer(),
                      
                      // Change Display (Only for Cash)
                      if (_selectedMethod == PaymentMethod.cash) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: change >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: change >= 0 ? Colors.green : Colors.red.shade200)
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("CHANGE", style: TextStyle(color: change >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                              Text(
                                FormatUtils.formatCurrency(change),
                                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: change >= 0 ? Colors.green : Colors.red),
                              ),
                            ],
                          ),
                        )
                      ]
                    ],
                  ),
                ),
              ),

              // ──────────────── RIGHT: INTERACTION (DYNAMIC) ────────────────
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Payment Method Toggles
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            _methodToggle(PaymentMethod.cash, "CASH", Icons.money),
                            const VerticalDivider(width: 1),
                            _methodToggle(PaymentMethod.card, "CARD", Icons.credit_card),
                            const VerticalDivider(width: 1),
                            _methodToggle(PaymentMethod.eWallet, "E-WALLET", Icons.account_balance_wallet),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Dynamic Content Area
                      Expanded(
                        child: _selectedMethod == PaymentMethod.cash 
                          ? _buildCashLayout(total)
                          : _buildDigitalLayout(),
                      ),

                      const SizedBox(height: 24),

                      // Confirm Button
                      BasicButton(
                        label: "CONFIRM PAYMENT", 
                        type: AppButtonType.primary, 
                        height: 60,
                        fontSize: 20,
                        onPressed: () => _processPayment(context, total),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  // ──────────────── LAYOUT HELPERS ────────────────

  Widget _buildCashLayout(double total) {
    return Row(
      children: [
        // Keypad
        Expanded(
          flex: 3,
          child: Column(
            children: [
               // Input Display
               Container(
                 padding: const EdgeInsets.all(16),
                 alignment: Alignment.centerRight,
                 decoration: BoxDecoration(
                   color: Colors.white,
                   border: Border.all(color: ThemeConfig.primaryGreen, width: 2),
                   borderRadius: BorderRadius.circular(12)
                 ),
                 child: Text(
                   _tenderedStr.isEmpty ? "0.00" : _tenderedStr,
                   style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: ThemeConfig.primaryGreen),
                 ),
               ),
               const SizedBox(height: 16),
               Expanded(
                 child: NumericPad(
                   onInput: _onKeypadInput,
                   onClear: _onClear,
                   onBackspace: _onBackspace,
                 ),
               ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Quick Bills
        Expanded(
          flex: 1,
          child: Column(
            children: [
            _quickIconBtn(Icons.backspace_outlined, _onBackspace, color: Colors.red.shade50, iconColor: Colors.red),
            const SizedBox(height: 8),
            _quickBillBtn("Exact", () => _setExact(total), color: Colors.blue.shade50, textColor: Colors.blue),
            const SizedBox(height: 8),
            _quickBillBtn("₱ 100", () => _addBill(100)),
            const SizedBox(height: 8),
            _quickBillBtn("₱ 500", () => _addBill(500)),
            const SizedBox(height: 8),
            _quickBillBtn("₱ 1000", () => _addBill(1000)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildDigitalLayout() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${_selectedMethod == PaymentMethod.card ? 'Card' : 'E-Wallet'} Reference Number / Trace ID",
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)
          ),
          const SizedBox(height: 12),
          BasicInputField(
            label: "Enter Reference #",
            controller: _referenceCtrl,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200)
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(child: Text("Ensure the terminal transaction is APPROVED before confirming payment here."))
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _methodToggle(PaymentMethod method, String label, IconData icon) {
    final isSelected = _selectedMethod == method;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = method),
        child: Container(
          color: isSelected ? ThemeConfig.primaryGreen : Colors.transparent,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickIconBtn(IconData icon, VoidCallback onTap, {Color? color, Color? iconColor}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0,2))]
          ),
          child: Icon(icon, color: iconColor ?? Colors.black87, size: 24),
        ),
      ),
    );
  }

  Widget _quickBillBtn(String label, VoidCallback onTap, {Color? color, Color? textColor}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color ?? Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0,2))]
          ),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor ?? Colors.black87)),
        ),
      ),
    );
  }

  Widget _buildLineItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 16)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );
  }
}
