import 'package:flutter/material.dart';

/// No-ad available dialog (plan6 H2).
///
/// Shown when a rewarded ad could not be shown (load error / no-fill / show
/// error / timeout) so the user is never left with a silent dead-end. Returns
/// `true` when the user taps Retry (caller re-runs the ad flow), `false` when
/// dismissed.
Future<bool> showAdUnavailableDialog(BuildContext context) async {
  final retry = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Ad unavailable'),
      content: const Text(
        'Không có quảng cáo lúc này. Vui lòng thử lại sau ít phút.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
  return retry ?? false;
}