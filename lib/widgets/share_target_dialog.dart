import 'package:flutter/material.dart';
import '../models/collection_model.dart';

/// Result of the share-target dialog (plan6 H5).
enum ShareTargetAction {
  /// Save to the default (most recent) collection.
  saveDefault,

  /// Open the collection picker to choose a different collection.
  changeCollection,

  /// Abort the save.
  cancel,
}

/// Share confirmation dialog (plan6 H5).
///
/// Shown on app open when `pending_share_text` exists. Instead of silently
/// auto-saving to the default collection, the user explicitly confirms the
/// target: "Lưu vào [collection mặc định/gần nhất]" / "Đổi collection" /
/// "Huỷ". Returns [ShareTargetAction.saveDefault] for the primary action,
/// [ShareTargetAction.changeCollection] to open the picker, or null / cancel
/// to abort.
Future<ShareTargetAction?> showShareTargetDialog(
  BuildContext context, {
  required Collection defaultCollection,
}) async {
  final action = await showDialog<ShareTargetAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Save shared text'),
      content: Text('Lưu vào "${defaultCollection.name}"?'),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(ShareTargetAction.cancel),
          child: const Text('Huỷ'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext)
              .pop(ShareTargetAction.changeCollection),
          child: const Text('Đổi collection'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(ShareTargetAction.saveDefault),
          child: const Text('Lưu vào'),
        ),
      ],
    ),
  );
  return action ?? ShareTargetAction.cancel;
}