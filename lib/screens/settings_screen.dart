import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/iap_service.dart';

class SettingsScreen extends StatefulWidget {
  final IapService iapService;

  const SettingsScreen({super.key, required this.iapService});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRestoring = false;

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);
    try {
      final restored = await widget.iapService.restorePurchases();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(restored
                ? 'Pro features restored successfully'
                : 'No previous purchases found'),
            backgroundColor: restored ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    // TODO: Replace with your hosted privacy policy URL
    // e.g., GitHub Pages: https://<username>.github.io/quotewidget/privacy.html
    final url = Uri.parse('https://github.com/quotewidget/privacy');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Restore Purchases (required for Store review)
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore Purchases'),
            subtitle: const Text('Restore Pro features from a previous purchase'),
            trailing: _isRestoring
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _isRestoring ? null : _restorePurchases,
          ),

          const Divider(),

          // Privacy Policy (required for Google Play)
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            subtitle: const Text('How we handle your data'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: _openPrivacyPolicy,
          ),

          const Divider(),

          // Pro Status
          ListTile(
            leading: Icon(
              widget.iapService.isPro ? Icons.star : Icons.star_border,
              color: widget.iapService.isPro ? Colors.amber : null,
            ),
            title: Text(widget.iapService.isPro ? 'Pro (Unlimited Widgets)' : 'Free (1 Widget)'),
            subtitle: Text(
              widget.iapService.isPro
                  ? 'All features unlocked'
                  : 'Upgrade to Pro for unlimited widgets, photo backgrounds, and more',
            ),
          ),

          const Divider(),

          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            subtitle: const Text('Quote Widget – Your Words v1.0.0'),
          ),
        ],
      ),
    );
  }
}
