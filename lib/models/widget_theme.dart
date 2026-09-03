import 'package:flutter/material.dart';

/// A fixed, curated widget theme (Task 6).
///
/// Unlike free-form Custom colors, curated themes are a small closed set so
/// they can be rendered faithfully on the NATIVE RemoteViews layouts
/// (widget_small.xml / widget_medium.xml) via a matching gradient drawable on
/// the Kotlin side — no per-theme layout XML needed.
///
/// The [id] must match:
/// 1. [AppearanceConfig.theme] when the theme is selected, AND
/// 2. a `widget_bg_<id>.xml` gradient drawable resource in
///    android/app/src/main/res/drawable (Kotlin maps id → drawable).
class WidgetTheme {
  final String id;
  final String name;
  final IconData icon;
  final int backgroundColor;
  final int gradientEnd;
  final int textColor;
  final int accentColor;

  const WidgetTheme({
    required this.id,
    required this.name,
    required this.icon,
    required this.backgroundColor,
    required this.gradientEnd,
    required this.textColor,
    required this.accentColor,
  });
}

/// The fixed curated theme set. Any theme added here MUST also have:
/// 1. A matching `widget_bg_<id>.xml` gradient drawable in
///    android/app/src/main/res/drawable whose start/end colors equal
///    [backgroundColor]/[gradientEnd], AND
/// 2. An entry in QuoteWidgetProvider.kt's theme→drawable mapping.
const List<WidgetTheme> kCuratedThemes = [
  WidgetTheme(
    id: 'ocean',
    name: 'Ocean',
    icon: Icons.water_drop,
    backgroundColor: 0xFF0D47A1,
    gradientEnd: 0xFF1976D2,
    textColor: 0xFFFFFFFF,
    accentColor: 0xFF80DEEA,
  ),
  WidgetTheme(
    id: 'sunset',
    name: 'Sunset',
    icon: Icons.wb_twilight,
    backgroundColor: 0xFFE65100,
    gradientEnd: 0xFFFF8F00,
    textColor: 0xFFFFFFFF,
    accentColor: 0xFFFFCC80,
  ),
  WidgetTheme(
    id: 'forest',
    name: 'Forest',
    icon: Icons.forest,
    backgroundColor: 0xFF1B5E20,
    gradientEnd: 0xFF388E3C,
    textColor: 0xFFFFFFFF,
    accentColor: 0xFFA5D6A7,
  ),
  WidgetTheme(
    id: 'midnight',
    name: 'Midnight',
    icon: Icons.nights_stay,
    backgroundColor: 0xFF212121,
    gradientEnd: 0xFF37474F,
    textColor: 0xFFFAFAFA,
    accentColor: 0xFF90CAF9,
  ),
  WidgetTheme(
    id: 'rose',
    name: 'Rose',
    icon: Icons.local_florist,
    backgroundColor: 0xFF880E4F,
    gradientEnd: 0xFFC2185B,
    textColor: 0xFFFFFFFF,
    accentColor: 0xFFF48FB1,
  ),
  WidgetTheme(
    id: 'sand',
    name: 'Sand',
    icon: Icons.beach_access,
    backgroundColor: 0xFF6D4C41,
    gradientEnd: 0xFF8D6E63,
    textColor: 0xFFFFFFFF,
    accentColor: 0xFFFFE0B2,
  ),
];

/// Look up a curated theme by id (null if [id] is 'light'/'dark'/'custom').
WidgetTheme? curatedThemeById(String id) {
  for (final theme in kCuratedThemes) {
    if (theme.id == id) return theme;
  }
  return null;
}
