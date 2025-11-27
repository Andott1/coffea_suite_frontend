// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 21;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      fullName: fields[1] as String,
      username: fields[2] as String,
      passwordHash: fields[3] as String,
      pinHash: fields[4] as String,
      role: fields[5] as UserRoleLevel,
      isActive: fields[6] as bool,
      hourlyRate: fields[9] as double,
      createdAt: fields[7] as DateTime?,
      updatedAt: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.fullName)
      ..writeByte(2)
      ..write(obj.username)
      ..writeByte(3)
      ..write(obj.passwordHash)
      ..writeByte(4)
      ..write(obj.pinHash)
      ..writeByte(5)
      ..write(obj.role)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt)
      ..writeByte(9)
      ..write(obj.hourlyRate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class UserRoleLevelAdapter extends TypeAdapter<UserRoleLevel> {
  @override
  final int typeId = 20;

  @override
  UserRoleLevel read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return UserRoleLevel.employee;
      case 1:
        return UserRoleLevel.manager;
      case 2:
        return UserRoleLevel.admin;
      default:
        return UserRoleLevel.employee;
    }
  }

  @override
  void write(BinaryWriter writer, UserRoleLevel obj) {
    switch (obj) {
      case UserRoleLevel.employee:
        writer.writeByte(0);
        break;
      case UserRoleLevel.manager:
        writer.writeByte(1);
        break;
      case UserRoleLevel.admin:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserRoleLevelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
