import 'package:flutter/services.dart';

/// Shows a native Android Toast (not a SnackBar).
///
/// A Toast is a system-level confirmation that works regardless of app UI
/// state — required for the background share flow (Task 2), where a SnackBar
/// would be invisible.
class ToastService {
  static const MethodChannel _channel = MethodChannel('quotewidget/toast');

  /// Show a long native Toast. No-op on non-Android (channel missing).
  static Future<void> show(String message) async {
    try {
      await _channel.invokeMethod('show', {'message': message});
    } catch (_) {
      // Channel unavailable (e.g. tests, iOS) — silently ignore.
    }
  }
}