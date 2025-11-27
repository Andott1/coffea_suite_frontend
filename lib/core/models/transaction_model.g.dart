// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 5;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      dateTime: fields[1] as DateTime,
      items: (fields[2] as List).cast<CartItemModel>(),
      totalAmount: fields[3] as double,
      tenderedAmount: fields[4] as double,
      paymentMethod: fields[5] as String,
      cashierName: fields[6] as String,
      referenceNo: fields[7] as String?,
      isVoid: fields[8] as bool,
      status: fields[9] as OrderStatus,
      orderType: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.totalAmount)
      ..writeByte(4)
      ..write(obj.tenderedAmount)
      ..writeByte(5)
      ..write(obj.paymentMethod)
      ..writeByte(6)
      ..write(obj.cashierName)
      ..writeByte(7)
      ..write(obj.referenceNo)
      ..writeByte(8)
      ..write(obj.isVoid)
      ..writeByte(9)
      ..write(obj.status)
      ..writeByte(10)
      ..write(obj.orderType);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderStatusAdapter extends TypeAdapter<OrderStatus> {
  @override
  final int typeId = 6;

  @override
  OrderStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OrderStatus.pending;
      case 1:
        return OrderStatus.preparing;
      case 2:
        return OrderStatus.ready;
      case 3:
        return OrderStatus.served;
      case 4:
        return OrderStatus.held;
      case 5:
        return OrderStatus.voided;
      default:
        return OrderStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, OrderStatus obj) {
    switch (obj) {
      case OrderStatus.pending:
        writer.writeByte(0);
        break;
      case OrderStatus.preparing:
        writer.writeByte(1);
        break;
      case OrderStatus.ready:
        writer.writeByte(2);
        break;
      case OrderStatus.served:
        writer.writeByte(3);
        break;
      case OrderStatus.held:
        writer.writeByte(4);
        break;
      case OrderStatus.voided:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
