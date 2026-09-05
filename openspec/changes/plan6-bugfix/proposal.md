# Plan6 Bugfix — Sprint 0 Critical & High hardening

## Why

`plan6_final_prompt.md` audits Sprint-0 stability. Reviewing the code at HEAD
shows several plan items are **already implemented** (C2 onDeleted wcfg_*
cleanup — Sprint A-3; C3 native-count free limit — Sprint A-1; H3
PREFS_VERSION + migratePreferences — Sprint A-4) so those need verification
only, not new code. The genuinely open items:

- **C1 (CRITICAL)**: `main.dart` startup reconciliation compares native int
  appWidgetIds against Hive String config UUIDs — always false, dead variable
  silenced with `// ignore: unused_local_variable`. Never actually ran.
- **C4 (CRITICAL)**: rewarded "production" ad unit ID is Google's sample/test
  ID — flipping TEST_ADS=false would serve test ads in production.
- **C5 (CRITICAL)**: dead `widget_config_screen.dart` + no CI guard against
  `// ignore:` silencing real bugs.
- **H2 (HIGH)**: rewarded-ad no-fill/load-fail leaves the user with only an
  orange "Ad not finished" snackbar — no retry dialog.
- **H5 (HIGH)**: share-sheet flow auto-saves to the default collection with no
  user confirmation — a dialog (Save to X / Change collection / Cancel) is
  required instead.
- **H6 (HIGH)**: no test proving restore rollback works when a mid-way insert
  fails.

Monetization decision (user-confirmed 2026-09-05): **keep rewarded-only** —
no IAP reversal; rewarded 24h unlocks the widget limit only and ads stay on.

## Decisions

- C4 real rewarded unit: `ca-app-pub-6917313063209470/7613467914`
  (provided by the user from AdMob console).
- C1 rewrite lives in `main.dart` wrapped in `Future.microtask`, using the
  existing `WidgetDataBridge.getConfigIdForWidget()` + Hive lookup; orphan
  detection = mapping present but config deleted from Hive → clean mapping.
- H1 is a docs-only task (keep rewarded-only; banner stays for rewarded Pro).