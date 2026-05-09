// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WordAdapter extends TypeAdapter<Word> {
  @override
  final int typeId = 0;

  @override
  Word read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Word(
      chinese: fields[0] as String,
      french: fields[1] as String,
      pinyin: fields[5] as String,
      tags: (fields[6] as List).cast<String>(),
      exampleCn: fields[7] as String,
      exampleFr: fields[8] as String,
      createdAt: fields[2] as DateTime,
      nextReview: fields[3] as DateTime?,
      interval: fields[4] as int,
      easeFactor: fields[9] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Word obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.chinese)
      ..writeByte(1)
      ..write(obj.french)
      ..writeByte(2)
      ..write(obj.createdAt)
      ..writeByte(3)
      ..write(obj.nextReview)
      ..writeByte(4)
      ..write(obj.interval)
      ..writeByte(5)
      ..write(obj.pinyin)
      ..writeByte(6)
      ..write(obj.tags)
      ..writeByte(7)
      ..write(obj.exampleCn)
      ..writeByte(8)
      ..write(obj.exampleFr)
      ..writeByte(9)
      ..write(obj.easeFactor);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WordAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
