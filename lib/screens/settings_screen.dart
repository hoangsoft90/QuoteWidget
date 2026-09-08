import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/backup_service.dart';
import '../services/iap_service.dart';
import '../services/interstitial_ad_service.dart';
import '../services/rewarded_ad_service.dart';
import '../services/snapshot_manager.dart';
import '../services/storage_service.dart';
import '../services/ump_consent_service.dart';
import '../services/widget_service.dart';
import '../widgets/ad_unavailable_dialog.dart';
import 'backup_screen.dart';
import 'recently_deleted_screen.dart';

class SettingsScreen extends StatefulWidget {
  final IapService iapService;
  final RewardedAdService rewardedAdService;
  final StorageService storageService;
  final WidgetService widgetService;
  final BackupService backupService;
  final SnapshotManager snapshotManager;
  final InterstitialAdController interstitialAdController;

  const SettingsScreen({
    super.key,
    required this.iapService,
    required this.rewardedAdService,
    required this.storageService,
    required this.widgetService,
    required this.backupService,
    required this.snapshotManager,
    required this.interstitialAdController,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isWatchingAd = false;
  bool _privacyOptionsRequired = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _checkPrivacyOptions();
    _loadVersion();
  }

  /// B5: About shows the live version from the package metadata instead of
  /// a hardcoded string that drifts from pubspec.yaml on every release.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    }    catch (_) {
      // Non-Android / test environment — leave empty, fall back below.
    }
  }

  /// A2: the Privacy Options entry point is shown ONLY when Google's UMP
  /// config requires one for this user (region/consent state).
  Future<void> _checkPrivacyOptions() async {
    final required =
        await UmpConsentService.instance.isPrivacyOptionsRequired();
    if (mounted && required != _privacyOptionsRequired) {
      setState(() => _privacyOptionsRequired = required);
    }
  }

  Future<void> _watchAdToUnlock() async {
    if (_isWatchingAd) return;
    setState(() => _isWatchingAd = true);
    try {
      // plan6 H2: retry dialog while no ad is available instead of a silent
      // dead-end. granted → green success; dismissed early → orange try-again;
      // unavailable + user cancels → same try-again snack.
      var result = await widget.rewardedAdService.showRewardedAd();
      while (result == RewardedAdResult.unavailable) {
        if (!mounted) return;
        final retry = await showAdUnavailableDialog(context);
        if (!retry) break;
        result = await widget.rewardedAdService.showRewardedAd();
      }
      if (mounted) {
        setState(() {}); // Refresh Pro status row
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(result == RewardedAdResult.granted
                ? 'Pro unlocked for 24 hours!'
                : 'Ad not finished. Please try again.'),
            backgroundColor: result == RewardedAdResult.granted
                ? Colors.green
                : Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isWatchingAd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPro = widget.iapService.isPro;
    final hoursLeft = widget.iapService.hoursRemaining;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Pro Status — Watch ad to unlock Pro for 24h
          ListTile(
            leading: Icon(
              isPro ? Icons.star : Icons.star_border,
              color: isPro ? Colors.amber : null,
            ),
            title: Text(
              isPro
                  ? (widget.iapService.proUnlockedUntil!.year >= 9999
                      ? 'Pro (Lifetime)'
                      : 'Pro unlocked — ${hoursLeft}h left')
                  : 'Free (1 Widget)',
            ),
            subtitle: Text(
              isPro
                  ? 'Unlimited widgets — ads still active'
                  : 'Watch a short ad to unlock Pro for 24h.',
            ),
            trailing: _isWatchingAd
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: isPro ? null : _watchAdToUnlock,
          ),

          const Divider(),

          // Recently Deleted (Trash)
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Recently Deleted'),
            subtitle: const Text('Restore or permanently delete trashed content'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RecentlyDeletedScreen(
                    storageService: widget.storageService,
                    widgetService: widget.widgetService,
                    interstitialAdController: widget.interstitialAdController,
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // Backup & Restore (export/import + safety snapshots)
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup & Restore'),
            subtitle: const Text('Export, import, and safety snapshots'),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BackupScreen(
                    backupService: widget.backupService,
                    snapshotManager: widget.snapshotManager,
                    storageService: widget.storageService,
                    interstitialAdController: widget.interstitialAdController,
                  ),
                ),
              );
            },
          ),

          const Divider(),

          // Privacy Options (UMP A2) — only when Google requires the entry
          // point; lets the user review/withdraw ads consent at any time.
          if (_privacyOptionsRequired) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Privacy Options'),
              subtitle: const Text('Review or change your ads consent'),
              onTap: () => UmpConsentService.instance.showPrivacyOptions(),
            ),
          ],

          const Divider(),

          // About — B5: version read live from PackageInfo.
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: Text(_version.isEmpty
                ? 'Quote Widget – Your Words'
                : 'Quote Widget – Your Words v$_version'),
          ),
        ],
      ),
    );
  }
}
