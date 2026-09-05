import 'package:hive/hive.dart';

class Item extends HiveObject {
  final String id;
  final String collectionId;
  String text;
  int order;
  final DateTime createdAt;

  /// Soft-delete flag (Trash / Recently Deleted — Task 7).
  bool isDeleted;
  DateTime? deletedAt;

  /// Favorite flag (Phase 2A — Favorites feature, features_final §1.4).
  /// Default false for Hive backward-compat (missing field → false).
  bool favorite;

  Item({
    required this.id,
    required this.collectionId,
    required this.text,
    required this.order,
    required this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
    this.favorite = false,
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

  bool get isTrashed => isDeleted;

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
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
      'favorite': favorite,
    };
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      text: json['text'] as String,
      order: json['order'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'] as String)
          : null,
      favorite: json['favorite'] as bool? ?? false,
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
      isDeleted: fields[5] as bool? ?? false,
      deletedAt: fields[6] as DateTime?,
      favorite: fields[7] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer.writeByte(8); // number of fields
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
    writer.writeByte(5);
    writer.write(obj.isDeleted);
    writer.writeByte(6);
    writer.write(obj.deletedAt);
    writer.writeByte(7);
    writer.write(obj.favorite);
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
