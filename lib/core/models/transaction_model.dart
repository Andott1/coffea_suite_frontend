import 'package:hive/hive.dart';
import 'cart_item_model.dart';

part 'transaction_model.g.dart';

@HiveType(typeId: 6)
enum OrderStatus {
  @HiveField(0) pending,
  @HiveField(1) preparing,
  @HiveField(2) ready,
  @HiveField(3) served,
  @HiveField(4) held,
  @HiveField(5) voided
}

@HiveType(typeId: 5)
class TransactionModel extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final DateTime dateTime;
  @HiveField(2) final List<CartItemModel> items;
  @HiveField(3) final double totalAmount;
  @HiveField(4) final double tenderedAmount;
  @HiveField(5) final String paymentMethod;
  @HiveField(6) final String cashierName;
  @HiveField(7) final String? referenceNo;
  @HiveField(8) final bool isVoid;
  @HiveField(9) OrderStatus status;

  // ✅ NEW FIELD
  @HiveField(10) 
  final String orderType; // "dineIn" or "takeOut"

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
    this.status = OrderStatus.pending,
    this.orderType = "dineIn", // ✅ Default
  });
}