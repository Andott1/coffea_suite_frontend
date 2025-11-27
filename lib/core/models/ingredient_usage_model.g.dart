// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ingredient_usage_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class IngredientUsageModelAdapter extends TypeAdapter<IngredientUsageModel> {
  @override
  final int typeId = 2;

  @override
  IngredientUsageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IngredientUsageModel(
      id: fields[0] as String,
      productId: fields[1] as String,
      ingredientId: fields[2] as String,
      category: fields[3] as String,
      subCategory: fields[4] as String,
      unit: fields[5] as String,
      quantities: (fields[6] as Map).cast<String, double>(),
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
      modifiedBy: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, IngredientUsageModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.productId)
      ..writeByte(2)
      ..write(obj.ingredientId)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.subCategory)
      ..writeByte(5)
      ..write(obj.unit)
      ..writeByte(6)
      ..write(obj.quantities)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.modifiedBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IngredientUsageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
