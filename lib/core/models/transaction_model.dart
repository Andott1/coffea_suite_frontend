/// <<FILE: lib/core/models/transaction_model.dart>>
import 'package:hive/hive.dart';
import 'cart_item_model.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 6) // ✅ New Enum Type ID
enum OrderStatus {
  @HiveField(0) pending,   // Just paid, waiting to be made
  @HiveField(1) preparing, // (Optional) Currently being made
  @HiveField(2) ready,     // Done, waiting for customer
  @HiveField(3) served,    // Customer picked up (Archived)
  @HiveField(4) held,      // Paused / Kitchen Hold
  @HiveField(5) voided     // Cancelled
}

@HiveType(typeId: 5)
class TransactionModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime dateTime;

  @HiveField(2)
  final List<CartItemModel> items;

  @HiveField(3)
  final double totalAmount;

  @HiveField(4)
  final double tenderedAmount;

  @HiveField(5)
  final String paymentMethod;

  @HiveField(6)
  final String cashierName;

  @HiveField(7)
  final String? referenceNo;

  @HiveField(8)
  final bool isVoid;

  // ✅ NEW: Track the order lifecycle
  @HiveField(9)
  OrderStatus status; 

  TransactionModel({
    required this.id,
    required this.dateTime,
    required this.items,
    required this.totalAmount,
    required this.tenderedAmount,
    required this.paymentMethod,
    required this.cashierName,
    this.referenceNo,
    this.isVoid = false,
    this.status = OrderStatus.pending, // Default to pending on creation
  });
}
/// <<END FILE>>