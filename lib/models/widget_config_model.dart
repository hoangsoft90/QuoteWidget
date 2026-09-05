import 'package:hive/hive.dart';

class WidgetConfig extends HiveObject {
  final String id;
  String collectionId;
  int currentIndex;
  RotationMode rotationMode;
  AppearanceConfig appearance;
  SizeCategory sizeCategory;
  bool showProgress;

  /// Phase 2A — Favorites-only widget (features_final §1.4): when
  /// [ContentFilter.favoritesOnly], rotation only draws from favorite items.
  ContentFilter contentFilter;

  /// Phase 2B — rotation schedule (features_final §3).
  ScheduleMode schedule;

  /// Phase 2B — what a tap on the widget does (features_final §3).
  TapAction tapAction;

  WidgetConfig({
    required this.id,
    required this.collectionId,
    this.currentIndex = 0,
    this.rotationMode = RotationMode.sequential,
    required this.appearance,
    this.sizeCategory = SizeCategory.small,
    this.showProgress = true,
    this.contentFilter = ContentFilter.all,
    this.schedule = ScheduleMode.manual,
    this.tapAction = TapAction.next,
  });

  factory WidgetConfig.create({
    required String collectionId,
    SizeCategory sizeCategory = SizeCategory.small,
    ContentFilter contentFilter = ContentFilter.all,
    RotationMode rotationMode = RotationMode.sequential,
    ScheduleMode schedule = ScheduleMode.manual,
    TapAction tapAction = TapAction.next,
  }) {
    return WidgetConfig(
      id: _generateId(),
      collectionId: collectionId,
      appearance: AppearanceConfig.create(),
      sizeCategory: sizeCategory,
      contentFilter: contentFilter,
      rotationMode: rotationMode,
      schedule: schedule,
      tapAction: tapAction,
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
      'contentFilter': contentFilter.name,
      'schedule': schedule.name,
      'tapAction': tapAction.name,
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
      contentFilter: ContentFilter.values.firstWhere(
        (e) => e.name == json['contentFilter'],
        orElse: () => ContentFilter.all,
      ),
      schedule: ScheduleMode.values.firstWhere(
        (e) => e.name == json['schedule'],
        orElse: () => ScheduleMode.manual,
      ),
      tapAction: TapAction.values.firstWhere(
        (e) => e.name == json['tapAction'],
        orElse: () => TapAction.next,
      ),
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
  /// Phase 2B — no-repeat until exhausted (features_final §2 Shuffle Bag):
  /// each cycle shows every item exactly once in a random order, then a new
  /// bag is drawn (never starting with the item just shown).
  shuffleBag,
}

/// Phase 2A — content filter for widget rotation: all items, or favorites
/// only (features_final §1.4 Favorites-only widget).
enum ContentFilter {
  all,
  favoritesOnly,
}

/// Phase 2B — rotation schedule (features_final §3). Manual = change only on
/// tap; daily = one item per local calendar day (snaps back after refresh);
/// every_1h/3h/6h = auto-advance on a timer.
enum ScheduleMode {
  manual,
  daily,
  every1h,
  every3h,
  every6h,
}

/// Phase 2B — what a tap on the widget does (features_final §3).
enum TapAction {
  /// Cycle to the next item (default).
  next,
  /// Open the app at the bound collection.
  openCollection,
  /// Just open the app.
  openApp,
  /// Copy the current text to the clipboard (+ native toast).
  copy,
}

/// Phase 2B — per-widget shuffle-bag state (features_final §2). Persisted in
/// SharedPreferences as flat primitives: `shuffle_bag` (JSON ids),
/// `shuffle_index`, `shuffle_source_fp`.
class ShuffleBagState {
  final List<String> bag;
  final int index;
  final String sourceFingerprint;

  const ShuffleBagState({
    required this.bag,
    required this.index,
    required this.sourceFingerprint,
  });

  Map<String, dynamic> toJson() => {
        'bag': bag,
        'index': index,
        'sourceFingerprint': sourceFingerprint,
      };

  factory ShuffleBagState.fromJson(Map<String, dynamic> json) => ShuffleBagState(
        bag: (json['bag'] as List? ?? const []).cast<String>(),
        index: json['index'] as int? ?? 0,
        sourceFingerprint: json['sourceFingerprint'] as String? ?? '',
      );
}

enum SizeCategory {
  small,
  medium,
  /// Phase 2B — responsive 4×2 (features_final §1.4). One main content area
  /// with more room; chosen by the widget's measured size on resize.
  wide,
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
      contentFilter: fields[7] as ContentFilter? ?? ContentFilter.all,
      schedule: fields[8] as ScheduleMode? ?? ScheduleMode.manual,
      tapAction: fields[9] as TapAction? ?? TapAction.next,
    );
  }

  @override
  void write(BinaryWriter writer, WidgetConfig obj) {
    writer.writeByte(10); // number of fields
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
    writer.writeByte(7);
    writer.write(obj.contentFilter);
    writer.writeByte(8);
    writer.write(obj.schedule);
    writer.writeByte(9);
    writer.write(obj.tapAction);
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

class ScheduleModeAdapter extends TypeAdapter<ScheduleMode> {
  @override
  final int typeId = 8;

  @override
  ScheduleMode read(BinaryReader reader) {
    return ScheduleMode.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ScheduleMode obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleModeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TapActionAdapter extends TypeAdapter<TapAction> {
  @override
  final int typeId = 9;

  @override
  TapAction read(BinaryReader reader) {
    return TapAction.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, TapAction obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TapActionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ContentFilterAdapter extends TypeAdapter<ContentFilter> {
  @override
  final int typeId = 7;

  @override
  ContentFilter read(BinaryReader reader) {
    return ContentFilter.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ContentFilter obj) {
    writer.writeByte(obj.index);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentFilterAdapter &&
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
