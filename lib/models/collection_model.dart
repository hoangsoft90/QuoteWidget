import 'package:hive/hive.dart';

class Collection extends HiveObject {
  final String id;
  String name;
  final DateTime createdAt;

  Collection({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory Collection.create({required String name}) {
    return Collection(
      id: _generateId(),
      name: name,
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
      'name': name,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class CollectionAdapter extends TypeAdapter<Collection> {
  @override
  final int typeId = 0;

  @override
  Collection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return Collection(
      id: fields[0] as String,
      name: fields[1] as String,
      createdAt: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Collection obj) {
    writer.writeByte(3); // number of fields
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.name);
    writer.writeByte(2);
    writer.write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
