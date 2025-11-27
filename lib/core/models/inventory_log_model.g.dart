// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InventoryLogModelAdapter extends TypeAdapter<InventoryLogModel> {
  @override
  final int typeId = 3;

  @override
  InventoryLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InventoryLogModel(
      id: fields[0] as String,
      dateTime: fields[1] as DateTime,
      ingredientName: fields[2] as String,
      action: fields[3] as String,
      changeAmount: fields[4] as double,
      unit: fields[5] as String,
      userName: fields[6] as String,
      reason: fields[7] as String,
    );
  }

  @override
  void write(BinaryWriter writer, InventoryLogModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dateTime)
      ..writeByte(2)
      ..write(obj.ingredientName)
      ..writeByte(3)
      ..write(obj.action)
      ..writeByte(4)
      ..write(obj.changeAmount)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.userName)
      ..writeByte(7)
      ..write(obj.reason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
