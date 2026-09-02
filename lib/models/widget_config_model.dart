import 'package:hive/hive.dart';

class WidgetConfig extends HiveObject {
  final String id;
  String collectionId;
  int currentIndex;
  RotationMode rotationMode;
  AppearanceConfig appearance;
  SizeCategory sizeCategory;
  bool showProgress;

  WidgetConfig({
    required this.id,
    required this.collectionId,
    this.currentIndex = 0,
    this.rotationMode = RotationMode.sequential,
    required this.appearance,
    this.sizeCategory = SizeCategory.small,
    this.showProgress = true,
  });

  factory WidgetConfig.create({
    required String collectionId,
    SizeCategory sizeCategory = SizeCategory.small,
  }) {
    return WidgetConfig(
      id: _generateId(),
      collectionId: collectionId,
      appearance: AppearanceConfig.create(),
      sizeCategory: sizeCategory,
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
      'currentIndex': currentIndex,
      'rotationMode': rotationMode.name,
      'appearance': appearance.toJson(),
      'sizeCategory': sizeCategory.name,
      'showProgress': showProgress,
    };
  }

  factory WidgetConfig.fromJson(Map<String, dynamic> json) {
    return WidgetConfig(
      id: json['id'] as String,
      collectionId: json['collectionId'] as String,
      currentIndex: json['currentIndex'] as int? ?? 0,
      rotationMode: RotationMode.values.firstWhere(
        (e) => e.name == json['rotationMode'],
        orElse: () => RotationMode.sequential,
      ),
      appearance: AppearanceConfig.fromJson(json['appearance'] as Map<String, dynamic>),
      sizeCategory: SizeCategory.values.firstWhere(
        (e) => e.name == json['sizeCategory'],
        orElse: () => SizeCategory.small,
      ),
      showProgress: json['showProgress'] as bool? ?? true,
    );
  }
}

class AppearanceConfig extends HiveObject {
  String theme;
  double fontSize;
  int textColor;
  int background;
  TextAlignment alignment;

  AppearanceConfig({
    this.theme = 'light',
    this.fontSize = 18.0,
    this.textColor = 0xFF000000,
    this.background = 0xFFFFFFFF,
    this.alignment = TextAlignment.center,
  });

  factory AppearanceConfig.create() {
    return AppearanceConfig();
  }

  Map<String, dynamic> toJson() {
    return {
      'theme': theme,
      'fontSize': fontSize,
      'textColor': textColor,
      'background': background,
      'alignment': alignment.name,
    };
  }

  factory AppearanceConfig.fromJson(Map<String, dynamic> json) {
    return AppearanceConfig(
      theme: json['theme'] as String? ?? 'light',
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 18.0,
      textColor: json['textColor'] as int? ?? 0xFF000000,
      background: json['background'] as int? ?? 0xFFFFFFFF,
      alignment: TextAlignment.values.firstWhere(
        (e) => e.name == json['alignment'],
        orElse: () => TextAlignment.center,
      ),
    );
  }

  factory AppearanceConfig.light() {
    return AppearanceConfig(
      theme: 'light',
      textColor: 0xFF000000,
      background: 0xFFFFFFFF,
    );
  }

  factory AppearanceConfig.dark() {
    return AppearanceConfig(
      theme: 'dark',
      textColor: 0xFFFFFFFF,
      background: 0xFF1A1A1A,
    );
  }
}

enum RotationMode {
  sequential,
  random,
}

enum SizeCategory {
  small,
  medium,
}

enum TextAlignment {
  left,
  center,
  right,
}

// TypeAdapters for Hive

class WidgetConfigAdapter extends TypeAdapter<WidgetConfig> {
  @override
  final int typeId = 2;

  @override
  WidgetConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return WidgetConfig(
      id: fields[0] as String,
      collectionId: fields[1] as String,
      currentIndex: fields[2] as int,
      rotationMode: fields[3] as RotationMode,
      appearance: fields[4] as AppearanceConfig,
      sizeCategory: fields[5] as SizeCategory,
      showProgress: fields[6] as bool? ?? true,
    );
  }

  @override
  void write(BinaryWriter writer, WidgetConfig obj) {
    writer.writeByte(7); // number of fields
    writer.writeByte(0);
    writer.write(obj.id);
    writer.writeByte(1);
    writer.write(obj.collectionId);
    writer.writeByte(2);
    writer.write(obj.currentIndex);
    writer.writeByte(3);
    writer.write(obj.rotationMode);
    writer.writeByte(4);
    writer.write(obj.appearance);
    writer.writeByte(5);
    writer.write(obj.sizeCategory);
    writer.writeByte(6);
    writer.write(obj.showProgress);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WidgetConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppearanceConfigAdapter extends TypeAdapter<AppearanceConfig> {
  @override
  final int typeId = 3;

  @override
  AppearanceConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numOfFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return AppearanceConfig(
      theme: fields[0] as String,
      fontSize: fields[1] as double,
      textColor: fields[2] as int,
      background: fields[3] as int,
      alignment: fields[4] as TextAlignment,
    );
  }

  @override
  void write(BinaryWriter writer, AppearanceConfig obj) {
    writer.writeByte(5); // number of fields
    writer.writeByte(0);
    writer.write(obj.theme);
    writer.writeByte(1);
    writer.write(obj.fontSize);
    writer.writeByte(2);
    writer.write(obj.textColor);
    writer.writeByte(3);
    writer.write(obj.background);
    writer.writeByte(4);
    writer.write(obj.alignment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppearanceConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class RotationModeAdapter extends TypeAdapter<RotationMode> {
  @override
  final int typeId = 4;

  @override
  RotationMode read(BinaryReader reader) {
    return RotationMode.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, RotationMode obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RotationModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SizeCategoryAdapter extends TypeAdapter<SizeCategory> {
  @override
  final int typeId = 5;

  @override
  SizeCategory read(BinaryReader reader) {
    return SizeCategory.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, SizeCategory obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SizeCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TextAlignmentAdapter extends TypeAdapter<TextAlignment> {
  @override
  final int typeId = 6;

  @override
  TextAlignment read(BinaryReader reader) {
    return TextAlignment.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, TextAlignment obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TextAlignmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
