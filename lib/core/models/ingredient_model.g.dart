// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IngredientModelAdapter extends TypeAdapter<IngredientModel> {
  @override
  final int typeId = 1;

  @override
  IngredientModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IngredientModel(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      unit: fields[3] as String,
      quantity: fields[4] as double,
      reorderLevel: fields[5] as double,
      updatedAt: fields[6] as DateTime,
      baseUnit: fields[7] as String?,
      conversionFactor: fields[8] as double?,
      isCustomConversion: fields[9] as bool,
      unitCost: fields[10] as double,
      purchaseSize: fields[11] as double,
    );
  }

  @override
  void write(BinaryWriter writer, IngredientModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.unit)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.reorderLevel)
      ..writeByte(6)
      ..write(obj.updatedAt)
      ..writeByte(7)
      ..write(obj.baseUnit)
      ..writeByte(8)
      ..write(obj.conversionFactor)
      ..writeByte(9)
      ..write(obj.isCustomConversion)
      ..writeByte(10)
      ..write(obj.unitCost)
      ..writeByte(11)
      ..write(obj.purchaseSize);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
