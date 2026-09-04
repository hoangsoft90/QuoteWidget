import 'package:flutter/material.dart';

/// Confirmation for a Quick Share save (plan5 Sprint 0 §1.7).
///
/// Shows "Saved to `collectionName`" with an **Undo** action that stays live for
/// [duration] (10s) then expires with the SnackBar. Tapping Undo runs
/// [onUndo] (delete the just-saved item + refresh affected widgets), then
/// swaps in a brief "Share removed" confirmation.
///
/// Kept as a standalone helper (not inline in main.dart) so the UI contract —
/// visible Undo action, expiry, follow-up confirmation — is widget-testable
/// without a Hive-backed app (Hive file I/O cannot run under testWidgets'
/// FakeAsync zone; the Hive-level undo semantics live in ShareService tests).
void showShareUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String collectionName,
  required Future<void> Function() onUndo,
  Duration duration = const Duration(seconds: 10),
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Saved to $collectionName'),
        duration: duration,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await onUndo();
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(const SnackBar(
              content: Text('Share removed'),
              duration: Duration(seconds: 2),
            ));
          },
        ),
      ),
    );
}
