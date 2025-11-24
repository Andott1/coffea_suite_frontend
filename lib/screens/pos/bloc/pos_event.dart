import 'package:equatable/equatable.dart';
import '../../../core/models/product_model.dart';
// ignore: unused_import
import '../../../core/models/cart_item_model.dart';
import 'pos_state.dart'; // Need this for OrderType enum if not in a shared file

abstract class PosEvent extends Equatable {
  const PosEvent();
  @override
  List<Object?> get props => [];
}

class PosAddToCart extends PosEvent {
  final ProductModel product;
  final String variant; 
  final double price;
  final int quantity; // ✅ NEW FIELD

  const PosAddToCart({
    required this.product, 
    required this.variant, 
    required this.price,
    this.quantity = 1, // Default to 1
  });

  @override
  List<Object?> get props => [product, variant, price, quantity];
}

class PosUpdateQuantity extends PosEvent {
  final String cartItemId;
  final int newQuantity;

  const PosUpdateQuantity({required this.cartItemId, required this.newQuantity});

  @override
  List<Object?> get props => [cartItemId, newQuantity];
}

class PosRemoveItem extends PosEvent {
  final String cartItemId;
  const PosRemoveItem(this.cartItemId);
}

class PosClearCart extends PosEvent {}

// ✅ NEW: Event to toggle Dine-In / Take-Out
class PosToggleOrderType extends PosEvent {
  final OrderType type;
  const PosToggleOrderType(this.type);

  @override
  List<Object?> get props => [type];
}

// ✅ NEW: Finalize the transaction
class PosConfirmPayment extends PosEvent {
  final double totalAmount;
  final double tenderedAmount; // For Cash (Total if Card)
  final String paymentMethod; // "Cash", "Card", "E-Wallet"
  final String? referenceNo;  // Null if Cash

  const PosConfirmPayment({
    required this.totalAmount,
    required this.tenderedAmount,
    required this.paymentMethod,
    this.referenceNo,
  });

  @override
  List<Object?> get props => [totalAmount, tenderedAmount, paymentMethod, referenceNo];
}

