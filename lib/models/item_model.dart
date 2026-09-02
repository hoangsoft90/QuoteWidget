import 'package:hive/hive.dart';

class Item extends HiveObject {
  final String id;
  final String collectionId;
  String text;
  int order;
  final DateTime createdAt;

  Item({
    required this.id,
    required this.collectionId,
    required this.text,
    required this.order,
    required this.createdAt,
  });

  factory Item.create({
    required String collectionId,
    required String text,
    required int order,
  }) {
    return Item(
      id: _generateId(),
      collectionId: collectionId,
      text: text,
      order: order,
      createdAt: DateTime.now(),
    );
  }

  static int _idCounter = 0;
  static String _generateId() {
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final seq = (_idCounter++).toRadixString(36);
    return '$ts-$seq';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collectionId': collectionId,
      'text': text,
      'order': order,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      text: json['text'] as String,
      order: json['order'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 1;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Item(
      id: fields[0] as String,
      collectionId: fields[1] as String,
      text: fields[2] as String,
      order: fields[3] as int,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer.writeByte(5); // number of fields
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.collectionId);
    writer.writeByte(2);
    writer.write(obj.text);
    writer.writeByte(3);
    writer.write(obj.order);
    writer.writeByte(4);
    writer.write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
