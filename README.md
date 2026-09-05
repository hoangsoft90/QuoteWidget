# Quote Widget — "Your Words"

A personal-content Home Screen widget app for Android (quotes, vocabulary,
reminders, notes). Offline-first, ad-supported (banner + rewarded 24h unlock).

> **Canonical source is the repo ROOT** (`lib/`, `android/`, `test/`).
> There is no `source/` legacy tree — do not use any `_archive_legacy_*`
> folder for development (Phase 1 P0-1).

## Tech

- Flutter (Dart ^3.13) + Hive (local DB) + home_widget (widget bridge)
- Native Android widget: `android/.../widget/QuoteWidgetProvider.kt`
- AdMob: banner (Home) + interstitial (rare, frequency-gated) + rewarded
  (24h Pro unlock — ads stay on)

## Build

- **Never build APKs locally** — GitHub Actions builds on push
  (`.github/workflows/build-debug-apk.yml`: analyze, tests, debug + release APK).
- Production build (real ads):
  `flutter build appbundle --release --dart-define=TEST_ADS=false`
- Dev builds keep `TEST_ADS=true` (sample ad units by default).

## Tests

```bash
flutter test        # full suite (105 tests)
flutter analyze     # 0 errors / 0 warnings (CI uses --fatal-warnings)
```

## Docs

- Feature spec (canonical): `.plan/features_final.md`
- Feature summary: `features.md` (reference only)
- Plans: `.plan/` (plan1..plan7 + prompt_phase0_to_release)
- OpenSpec changes: `openspec/changes/`