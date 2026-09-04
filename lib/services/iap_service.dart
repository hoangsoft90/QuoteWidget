import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

/// Pro-unlock service.
///
/// Pro is **time-bound**: `proUnlockedUntil` is null (never unlocked) or a
/// timestamp. `isPro` is true only while `now < proUnlockedUntil`.
///
/// Single unlock path (user decision 2026-09-03 — all IAP removed):
/// **Rewarded-ad unlock 24h** — `unlockProFor24h()` sets
/// `proUnlockedUntil = now + 24h`. When it expires, the app re-locks
/// automatically (widget limit re-engages).
///
/// Pro does NOT remove ads — the banner and interstitials keep showing
/// (user decision 2026-09-03). The only Pro benefit is the widget limit.
///
/// Legacy: users who purchased "Pro forever" before IAP was removed keep a
/// permanent `proUnlockedUntil = DateTime(9999)` via the legacy prefs key.
class IapService {
  static const String _proKey = 'iap_pro_purchased';
  static const String _proExpiryKey = 'iap_pro_expires_at';

  /// When Pro access expires. Null = never unlocked.
  DateTime? proUnlockedUntil;

  /// Whether the user currently has Pro (time-bound).
  bool get isPro =>
      proUnlockedUntil != null && DateTime.now().isBefore(proUnlockedUntil!);

  /// Hours remaining of Pro access (for UI countdown), 0 if not Pro.
  int get hoursRemaining {
    if (!isPro || proUnlockedUntil == null) return 0;
    return proUnlockedUntil!
        .difference(DateTime.now())
        .inHours
        .clamp(0, 24 * 365);
  }

  /// Load the cached Pro status (expiry or legacy permanent purchase).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMillis = prefs.getInt(_proExpiryKey);
    if (expiryMillis != null && expiryMillis > 0) {
      proUnlockedUntil = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    } else if (prefs.getBool(_proKey) ?? false) {
      // Legacy: previously purchased forever → migrate to permanent Pro.
      proUnlockedUntil = DateTime(9999);
      await _persist();
    }
  }

  /// Unlock Pro for the next 24 hours (rewarded-ad path).
  /// Persists + syncs `is_pro` and `is_pro_expires_at` to the widget layer so
  /// Kotlin can self-lock when the window expires even if the app is closed.
  Future<void> unlockProFor24h() async {
    proUnlockedUntil = DateTime.now().add(const Duration(hours: 24));
    await _persist();
  }

  /// Persist Pro state + sync to widget SharedPreferences so Kotlin can read.
  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryMillis = proUnlockedUntil?.millisecondsSinceEpoch ?? 0;
    await prefs.setBool(_proKey, isPro);
    await prefs.setInt(_proExpiryKey, expiryMillis);
    // Also write to FlutterSharedPreferences via the bridge file convention
    await prefs.setString('is_pro', isPro.toString());
    await prefs.setString('is_pro_expires_at', expiryMillis.toString());
    // Sync to widget SharedPreferences so Kotlin can read is_pro + expiry,
    // then push an update so Kotlin re-renders (a 2nd-widget "Upgrade to
    // Pro" placeholder becomes a tappable set-up prompt once Pro is active).
    // Best-effort: widget sync must never break the unlock persistence.
    try {
      await HomeWidget.saveWidgetData('is_pro', isPro.toString());
      await HomeWidget.saveWidgetData(
          'is_pro_expires_at', expiryMillis.toString());
      // plan3 Fix B: without this push, unlocking from Settings leaves an
      // existing native placeholder stale until some unrelated update.
      await HomeWidget.updateWidget(
        name: 'QuoteWidgetProvider',
        androidName: 'QuoteWidgetProvider',
      );
    } catch (_) {
      // No widget host (e.g. unit test) — ignore.
    }
  }
}