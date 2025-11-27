import 'package:equatable/equatable.dart';
import '../../../core/models/cart_item_model.dart';
import '../../../core/utils/format_utils.dart';

// ✅ NEW: Enum for Order Type
enum OrderType { dineIn, takeOut }

class PosState extends Equatable {
  final List<CartItemModel> cart;
  final double subtotal;
  final double tax;
  final double total;
  final bool isLoading;
  final OrderType orderType; // ✅ NEW: Store the selection

  const PosState({
    this.cart = const [],
    this.subtotal = 0.0,
    this.tax = 0.0,
    this.total = 0.0,
    this.isLoading = false,
    this.orderType = OrderType.dineIn, // ✅ Default to Dine-In
  });

  PosState copyWith({
    List<CartItemModel>? cart,
    bool? isLoading,
    OrderType? orderType,
  }) {
    // Auto-recalc totals whenever cart changes
    final newCart = cart ?? this.cart;
    
    // ✅ FIX: Round the raw sum immediately
    final rawSubtotal = newCart.fold(0.0, (sum, item) => sum + item.total);
    final newSubtotal = FormatUtils.roundDouble(rawSubtotal);
    
    final newTax = 0.0; 
    final newTotal = FormatUtils.roundDouble(newSubtotal + newTax);

    return PosState(
      cart: newCart,
      subtotal: newSubtotal,
      tax: newTax,
      total: newTotal,
      isLoading: isLoading ?? this.isLoading,
      orderType: orderType ?? this.orderType,
    );
  }

  @override
  List<Object?> get props => [cart, total, isLoading, orderType];
}
