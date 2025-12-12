import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/services/supabase_sync_service.dart';
import 'pos_event.dart';
import 'pos_state.dart';
import '../../../core/models/cart_item_model.dart';
import 'package:uuid/uuid.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/services/hive_service.dart';
import '../../../core/services/session_user.dart';
import 'stock_logic.dart';

class PosBloc extends Bloc<PosEvent, PosState> {
  PosBloc() : super(const PosState()) {
    on<PosAddToCart>(_onAddToCart);
    on<PosUpdateQuantity>(_onUpdateQuantity);
    on<PosRemoveItem>(_onRemoveItem);
    on<PosClearCart>(_onClearCart);
    on<PosToggleOrderType>(_onToggleOrderType);
    on<PosConfirmPayment>(_onConfirmPayment);
    on<PosEditCartItem>(_onEditCartItem);
  }

  void _onAddToCart(PosAddToCart event, Emitter<PosState> emit) {
    final currentCart = List<CartItemModel>.from(state.cart);

    final existingIndex = currentCart.indexWhere(
      (item) => item.product.id == event.product.id && item.variant == event.variant
    );

    if (existingIndex != -1) {
      final existing = currentCart[existingIndex];
      currentCart[existingIndex] = existing.copyWith(
        quantity: existing.quantity + event.quantity 
      );
    } else {
      currentCart.add(CartItemModel(
        product: event.product,
        variant: event.variant,
        price: event.price,
        quantity: event.quantity,
      ));
    }

    emit(state.copyWith(cart: currentCart));
  }

  void _onUpdateQuantity(PosUpdateQuantity event, Emitter<PosState> emit) {
    if (event.newQuantity <= 0) {
      add(PosRemoveItem(event.cartItemId));
      return;
    }

    final currentCart = List<CartItemModel>.from(state.cart);
    final index = currentCart.indexWhere((i) => i.id == event.cartItemId);
    
    if (index != -1) {
      currentCart[index] = currentCart[index].copyWith(quantity: event.newQuantity);
      emit(state.copyWith(cart: currentCart));
    }
  }

  void _onRemoveItem(PosRemoveItem event, Emitter<PosState> emit) {
    final currentCart = List<CartItemModel>.from(state.cart);
    currentCart.removeWhere((i) => i.id == event.cartItemId);
    emit(state.copyWith(cart: currentCart));
  }

  void _onClearCart(PosClearCart event, Emitter<PosState> emit) {
    emit(const PosState(cart: []));
  }

  void _onToggleOrderType(PosToggleOrderType event, Emitter<PosState> emit) {
    emit(state.copyWith(orderType: event.type));
  }

  void _onEditCartItem(PosEditCartItem event, Emitter<PosState> emit) {
    if (event.quantity <= 0) {
      add(PosRemoveItem(event.cartItemId));
      return;
    }

    final currentCart = List<CartItemModel>.from(state.cart);
    final index = currentCart.indexWhere((i) => i.id == event.cartItemId);
    
    if (index != -1) {
      currentCart[index] = currentCart[index].copyWith(
        quantity: event.quantity,
        discount: event.discount,
        note: event.note,
      );
      emit(state.copyWith(cart: currentCart));
    }
  }

  void _onConfirmPayment(PosConfirmPayment event, Emitter<PosState> emit) async {
    emit(state.copyWith(isLoading: true));

    final transactionId = const Uuid().v4().substring(0, 8).toUpperCase();

    final transaction = TransactionModel(
      id: transactionId,
      dateTime: DateTime.now(),
      items: List.from(state.cart),
      totalAmount: event.totalAmount,
      tenderedAmount: event.tenderedAmount,
      paymentMethod: event.paymentMethod,
      cashierName: SessionUser.current?.username ?? "Unknown",
      referenceNo: event.referenceNo,
      orderType: state.orderType.name, // "dineIn" or "takeOut"
    );

    // 2. Save to Hive History
    await HiveService.transactionBox.add(transaction);

    // 3. Sync to Supabase
    SupabaseSyncService.addToQueue(
      table: 'transactions',
      action: 'UPSERT',
      data: {
        'id': transaction.id,
        'date_time': transaction.dateTime.toIso8601String(),
        'total_amount': transaction.totalAmount,
        'tendered_amount': transaction.tenderedAmount, // Don't forget this one too if missing
        'payment_method': transaction.paymentMethod,
        'cashier_name': transaction.cashierName,
        'status': transaction.status.name,
        'is_void': transaction.isVoid,
        'reference_no': transaction.referenceNo,
        
        // ✅ SYNC ORDER TYPE
        'order_type': transaction.orderType, 

        'items': transaction.items.map((i) => {
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

    // 3. Deduct Inventory Stock
    await StockLogic.deductStock(state.cart, transactionId);
    
    await Future.delayed(const Duration(milliseconds: 500)); // UI Feedback delay
    
    // 4. Reset Cart
    emit(const PosState()); 
  }

}
