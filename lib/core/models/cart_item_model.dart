import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'product_model.dart';

part 'cart_item_model.g.dart';

@HiveType(typeId: 4) // ✅ Type 4
class CartItemModel {
  @HiveField(0)
  final String id; 

  @HiveField(1)
  final ProductModel product;

  @HiveField(2)
  final String variant; // "12oz"

  @HiveField(3)
  final double price;

  @HiveField(4)
  final int quantity;

  @HiveField(5)
  final double discount;

  CartItemModel({
    String? id,
    required this.product,
    required this.variant,
    required this.price,
    this.quantity = 1,
    this.discount = 0.0,
  }) : id = id ?? const Uuid().v4();

  double get total => (price * quantity) - discount;

  CartItemModel copyWith({
    int? quantity,
    double? discount,
  }) {
    return CartItemModel(
      id: id,
      product: product,
      variant: variant,
      price: price,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
    );
  }
}
