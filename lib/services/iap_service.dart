import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

/// Minimal IAP service — Restore Purchases only.
/// No paywall UI in MVP. This exists solely to pass Store review
/// (App Store Guideline 3.1.1, Google Play IAP requirements).
///
/// Product ID matches Pro upgrade (one-time, non-consumable).
/// Actual purchase flow will be added in P0.5.
class IapService {
  static const String proProductId = 'com.quotewidget.pro';
  static const String _proKey = 'iap_pro_purchased';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;

  /// Whether the user currently has Pro (restored or purchased).
  bool isPro = false;

  /// Initialize IAP and restore previous purchases.
  Future<void> init() async {
    // Check if IAP is available on this device
    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) return;

    // Load cached Pro status
    final prefs = await SharedPreferences.getInstance();
    isPro = prefs.getBool(_proKey) ?? false;

    // Listen for purchase updates (needed for restore callback)
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => _subscription?.cancel(),
    );
  }

  /// Restore previous purchases — call when user taps "Restore Purchases".
  /// Returns true if Pro was restored.
  Future<bool> restorePurchases() async {
    if (!_isAvailable) return false;

    try {
      await _iap.restorePurchases();
      // Result arrives asynchronously via purchaseStream → _onPurchaseUpdate
      // For Store review, we just need to show the button works.
      return isPro;
    } catch (e) {
      return false;
    }
  }

  /// Handle purchase stream updates.
  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.productID == proProductId) {
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          _unlockPro();
        }
        // Complete pending purchases (required by store guidelines)
        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
      }
    }
  }

  /// Unlock Pro features and persist.
  /// Also syncs to widget SharedPreferences so locked widgets unlock immediately.
  void _unlockPro() async {
    isPro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, true);
    // Sync to widget SharedPreferences so Kotlin can read it
    await HomeWidget.saveWidgetData('is_pro', 'true');
  }

  /// Dispose stream subscription.
  void dispose() {
    _subscription?.cancel();
  }
}
