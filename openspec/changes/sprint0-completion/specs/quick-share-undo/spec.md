# Spec: Quick Share Undo

## Behavior

Incoming share text saves directly into Hive (unchanged flow). The confirmation
now carries an **Undo** action:

1. Save succeeds → SnackBar `Saved to <Collection>` with `Undo` action, visible
   for 10 seconds (within the 10–15s window).
2. Tapping **Undo** within that window:
   - Soft-deletes the just-created item (app's Trash model — recoverable),
   - Refreshes every widget showing that collection,
   - Shows a brief `Share removed` confirmation.
3. Action expires with the SnackBar — nothing happens after the window.
4. Failures (no collections, save error) keep the system Toast — no Undo.

## Rules

- `ShareService.saveToCollection` returns the created `Item` (null on failure)
  so the Undo target is exact — never a guess.
- The share flow runs while the app UI is on screen (post-frame on app open), so
  a SnackBar is reliably visible; the native Toast is only for failure paths.
- The multi-collection picker dialog uses the MaterialApp navigator-key context —
  the app-level context sits above the Navigator and must never be passed to
  `showDialog` (latent crash with >1 collection).