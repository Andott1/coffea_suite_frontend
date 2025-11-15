// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 0;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      name: fields[1] as String,
      category: fields[2] as String,
      subCategory: fields[3] as String,
      pricingType: fields[4] as String,
      prices: (fields[5] as Map).cast<String, double>(),
      ingredientUsage: (fields[6] as Map).map((dynamic k, dynamic v) =>
          MapEntry(k as String, (v as Map).cast<String, double>())),
      available: fields[7] as bool,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.subCategory)
      ..writeByte(4)
      ..write(obj.pricingType)
      ..writeByte(5)
      ..write(obj.prices)
      ..writeByte(6)
      ..write(obj.ingredientUsage)
      ..writeByte(7)
      ..write(obj.available)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
