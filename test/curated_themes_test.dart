import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quotewidget/models/widget_theme.dart';

/// Cross-layer parity (Task 6): the Flutter curated-theme set and the native
/// gradient drawables MUST stay in sync, or a theme selected in the app would
/// silently render as the default background on the actual widget.
void main() {
  final drawableDir = Directory(
      'android/app/src/main/res/drawable');

  test('every curated theme has a matching native gradient drawable', () {
    expect(drawableDir.existsSync(), isTrue,
        reason: 'res/drawable dir must exist');

    final drawableFiles = drawableDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.startsWith('widget_bg_') && name.endsWith('.xml'))
        .toSet();

    for (final theme in kCuratedThemes) {
      expect(
        drawableFiles.contains('widget_bg_${theme.id}.xml'),
        isTrue,
        reason: 'Theme "${theme.id}" is missing widget_bg_${theme.id}.xml — '
            'Kotlin QuoteWidgetProvider.themeDrawableFor() maps it at build time.',
      );
    }
  });

  test('no orphan theme drawables (every native bg has a Flutter theme)', () {
    final drawableFiles = drawableDir
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((name) => name.startsWith('widget_bg_') && name.endsWith('.xml'))
        .toList();

    final themeIds = kCuratedThemes.map((t) => t.id).toSet();
    for (final file in drawableFiles) {
      final id = file
          .replaceFirst('widget_bg_', '')
          .replaceFirst('.xml', '');
      expect(themeIds.contains(id), isTrue,
          reason: 'widget_bg_$id.xml has no matching Flutter theme in '
              'kCuratedThemes — orphan native resource');
    }
  });

  test('curated theme colors are valid 32-bit ARGB', () {
    for (final theme in kCuratedThemes) {
      expect(theme.backgroundColor & 0xFF000000, 0xFF000000,
          reason: '${theme.id} backgroundColor must be fully opaque');
      expect(theme.gradientEnd & 0xFF000000, 0xFF000000,
          reason: '${theme.id} gradientEnd must be fully opaque');
      expect(theme.textColor & 0xFF000000, 0xFF000000,
          reason: '${theme.id} textColor must be fully opaque');
      expect(theme.accentColor & 0xFF000000, 0xFF000000,
          reason: '${theme.id} accentColor must be fully opaque');
    }
  });

  test('curated themes have unique ids', () {
    final ids = kCuratedThemes.map((t) => t.id).toSet();
    expect(ids.length, kCuratedThemes.length,
        reason: 'Theme ids must be unique');
    expect(kCuratedThemes.length, greaterThanOrEqualTo(5),
        reason: 'Task 6 requires 5-6 fixed themes');
  });
}