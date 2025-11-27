// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payroll_record_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PayrollRecordModelAdapter extends TypeAdapter<PayrollRecordModel> {
  @override
  final int typeId = 40;

  @override
  PayrollRecordModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PayrollRecordModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      periodStart: fields[2] as DateTime,
      periodEnd: fields[3] as DateTime,
      totalHours: fields[4] as double,
      grossPay: fields[5] as double,
      netPay: fields[6] as double,
      adjustmentsJson: fields[7] as String,
      generatedAt: fields[8] as DateTime,
      generatedBy: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, PayrollRecordModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.periodStart)
      ..writeByte(3)
      ..write(obj.periodEnd)
      ..writeByte(4)
      ..write(obj.totalHours)
      ..writeByte(5)
      ..write(obj.grossPay)
      ..writeByte(6)
      ..write(obj.netPay)
      ..writeByte(7)
      ..write(obj.adjustmentsJson)
      ..writeByte(8)
      ..write(obj.generatedAt)
      ..writeByte(9)
      ..write(obj.generatedBy);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayrollRecordModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
