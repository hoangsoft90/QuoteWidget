# Share target dialog (H5)

## Requirements

- Native `ShareReceiverActivity` keeps writing `flutter.pending_share_text` +
  `flutter.share_timestamp` to FlutterSharedPreferences then `finish()` —
  NO direct Hive write from Kotlin (verify only).
- On app open, when `pending_share_text` is present → show a dialog:
  - Primary action: "Lưu vào [collection mặc định/gần nhất]"
    (default = most recent collection, or first in sorted order).
  - Secondary: "Đổi collection" → opens the existing collection picker.
  - Dismiss: "Huỷ" — aborts the save.
- No auto-save, no 5-second timer.
- After a confirmed save, the existing "Saved to X" + Undo (10s) SnackBar
  (plan5 §1.7) still applies.

## Test

- Widget test: dialog renders the three options; primary action resolves with
  the default collection; "Đổi collection" opens picker path; "Huỷ" returns null.