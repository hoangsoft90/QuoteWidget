import 'package:flutter/material.dart';
import '../services/iap_service.dart';
import '../services/rewarded_ad_service.dart';

/// Result of the paywall sheet.
enum PaywallResult {
  /// User watched the rewarded ad and Pro (24h) was granted.
  adGranted,

  /// User bought Remove Ads Forever and Pro (permanent) was granted.
  buyGranted,

  /// Dismissed / failed — Pro not granted.
  cancelled,
}

/// Shared paywall bottom sheet (plan4 Sprint A-5): Watch Ad (24h) / Buy Pro
/// (forever) / Cancel. Used both by [WidgetSetupScreen]'s widget-limit dialog
/// path and by the native "Upgrade to Pro" widget deep link (route=paywall),
/// so there is exactly one paywall UI in the app.
///
/// Returns the [PaywallResult] so callers can react (e.g. retry a widget
/// save after a successful unlock).
Future<PaywallResult> showPaywallSheet(
  BuildContext context, {
  required IapService iapService,
  required RewardedAdService rewardedAdService,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              'Unlock Pro',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text(
              'Add more widgets and remove all ads.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('Watch Ad — Unlock 24h'),
            subtitle: const Text('Free, lasts 24 hours'),
            onTap: () => Navigator.of(sheetContext).pop('ad'),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: const Text('Remove Ads Forever'),
            subtitle: const Text('One-time purchase, lifetime Pro'),
            onTap: () => Navigator.of(sheetContext).pop('buy'),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.of(sheetContext).pop('cancel'),
          ),
          const SizedBox(height: 8),
        ],
        ),
      ),
    ),
  );

  if (!context.mounted) return PaywallResult.cancelled;

  final messenger = ScaffoldMessenger.of(context);
  switch (action) {
    case 'ad':
      final rewarded = await rewardedAdService.showRewardedAd();
      if (rewarded && iapService.isPro) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Pro unlocked for 24h!')),
        );
        return PaywallResult.adGranted;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Ad not finished. Please try again.')),
      );
      return PaywallResult.cancelled;
    case 'buy':
      final started = await iapService.buyPro();
      if (iapService.isPro) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Pro unlocked forever!')),
        );
        return PaywallResult.buyGranted;
      }
      if (!started) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Purchase unavailable right now.')),
        );
      }
      return PaywallResult.cancelled;
    default:
      return PaywallResult.cancelled;
  }
}