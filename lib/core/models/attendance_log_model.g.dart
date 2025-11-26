// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_log_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceLogModelAdapter extends TypeAdapter<AttendanceLogModel> {
  @override
  final int typeId = 31;

  @override
  AttendanceLogModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceLogModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      date: fields[2] as DateTime,
      timeIn: fields[3] as DateTime,
      timeOut: fields[4] as DateTime?,
      breakStart: fields[5] as DateTime?,
      breakEnd: fields[6] as DateTime?,
      status: fields[7] as AttendanceStatus,
      hourlyRateSnapshot: fields[8] as double,
      proofImage: fields[9] as String?,
      isVerified: fields[10] as bool,
      rejectionReason: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceLogModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.timeIn)
      ..writeByte(4)
      ..write(obj.timeOut)
      ..writeByte(5)
      ..write(obj.breakStart)
      ..writeByte(6)
      ..write(obj.breakEnd)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.hourlyRateSnapshot)
      ..writeByte(9)
      ..write(obj.proofImage)
      ..writeByte(10)
      ..write(obj.isVerified)
      ..writeByte(11)
      ..write(obj.rejectionReason);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceLogModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AttendanceStatusAdapter extends TypeAdapter<AttendanceStatus> {
  @override
  final int typeId = 30;

  @override
  AttendanceStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AttendanceStatus.onTime;
      case 1:
        return AttendanceStatus.late;
      case 2:
        return AttendanceStatus.overtime;
      case 3:
        return AttendanceStatus.incomplete;
      default:
        return AttendanceStatus.onTime;
    }
  }

  @override
  void write(BinaryWriter writer, AttendanceStatus obj) {
    switch (obj) {
      case AttendanceStatus.onTime:
        writer.writeByte(0);
        break;
      case AttendanceStatus.late:
        writer.writeByte(1);
        break;
      case AttendanceStatus.overtime:
        writer.writeByte(2);
        break;
      case AttendanceStatus.incomplete:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
