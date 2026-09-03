import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

/// IAP + rewarded-ad unlock service.
///
/// Pro is now **time-bound**: `proUnlockedUntil` is null (never unlocked) or a
/// timestamp. `isPro` is true only while `now < proUnlockedUntil`.
///
/// Two unlock paths:
/// 1. **IAP one-time purchase** ("Remove Ads – Unlock Pro Forever") — on a
///    successful permanent purchase, `proUnlockedUntil = DateTime(9999)`,
///    i.e. effectively forever.
/// 2. **Rewarded-ad unlock 24h** — `unlockProFor24h()` sets
///    `proUnlockedUntil = now + 24h`. When it expires, the app re-locks
///    automatically (widget limit re-engages).
class IapService {
  static const String proProductId = 'com.quotewidget.pro';
  static const String _proKey = 'iap_pro_purchased';
  static const String _proExpiryKey = 'iap_pro_expires_at';

  /// Lazily created so plain unit tests (which never touch the store) can
  /// construct [IapService] without platform-channel side effects.
  InAppPurchase? _iap;
  InAppPurchase get _iapInstance => _iap ??= InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;

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

  /// Initialize IAP and restore previous purchases.
  Future<void> init() async {
    // Check if IAP is available on this device
    try {
      _isAvailable = await _iapInstance.isAvailable();
    } catch (_) {
      _isAvailable = false;
      return;
    }
    if (!_isAvailable) return;

    // Load cached Pro status
    final prefs = await SharedPreferences.getInstance();
    final expiryMillis = prefs.getInt(_proExpiryKey);
    if (expiryMillis != null && expiryMillis > 0) {
      proUnlockedUntil = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
    } else if (prefs.getBool(_proKey) ?? false) {
      // Legacy: previously purchased forever → migrate to permanent Pro.
      proUnlockedUntil = DateTime(9999);
      await _persist();
    }

    // Listen for purchase updates (needed for restore callback)
    try {
      _subscription = _iapInstance.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => _subscription?.cancel(),
        onError: (error) => _subscription?.cancel(),
      );
    } catch (_) {
      // No store available — subscription is optional.
    }
  }

  /// Restore previous purchases — call when user taps "Restore Purchases".
  /// Returns true if Pro was restored.
  Future<bool> restorePurchases() async {
    if (!_isAvailable) return false;

    try {
      await _iapInstance.restorePurchases();
      // Result arrives asynchronously via purchaseStream → _onPurchaseUpdate
      return isPro;
    } catch (e) {
      return false;
    }
  }

  /// Start the one-time Pro purchase flow ("Remove Ads – Unlock Pro Forever").
  /// The store handles the UI; `_onPurchaseUpdate` grants Pro on success.
  Future<bool> buyPro() async {
    if (!_isAvailable) return false;
    try {
      // Resolve product details for the Pro product first.
      final response = await _iapInstance.queryProductDetails({proProductId});
      if (response.productDetails.isEmpty) return false;
      final details = response.productDetails.first;
      await _iapInstance.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: details));
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Unlock Pro for the next 24 hours (rewarded-ad path).
  /// Persists + syncs `is_pro` and `is_pro_expires_at` to the widget layer so
  /// Kotlin can self-lock when the window expires even if the app is closed.
  Future<void> unlockProFor24h() async {
    proUnlockedUntil = DateTime.now().add(const Duration(hours: 24));
    await _persist();
  }

  /// Handle purchase stream updates.
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID == proProductId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          // Permanent purchase → never expires.
          proUnlockedUntil = DateTime(9999);
          _persist();
        }
        // Complete pending purchases (required by store guidelines)
        if (purchase.pendingCompletePurchase) {
          _iapInstance.completePurchase(purchase);
        }
      }
    }
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
    // Sync to widget SharedPreferences so Kotlin can read is_pro + expiry.
    // Best-effort: widget sync must never break purchase persistence.
    try {
      await HomeWidget.saveWidgetData('is_pro', isPro.toString());
      await HomeWidget.saveWidgetData(
          'is_pro_expires_at', expiryMillis.toString());
    } catch (_) {
      // No widget host (e.g. unit test) — ignore.
    }
  }

  /// Dispose stream subscription.
  void dispose() {
    _subscription?.cancel();
  }
}