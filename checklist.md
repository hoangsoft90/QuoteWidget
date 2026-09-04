# QuoteWidget — Checklist

## ✅ Done

### Infrastructure & Build
- [x] targetSdkVersion 36 (Google Play API 36 requirement) — `cf2b93a`
- [x] Cleartext HTTP allowed (network_security_config.xml) — `cf2b93a`
- [x] Gradle/AGP/Kotlin version pins for Flutter 3.47.1 — `cf2b93a..adf784b`
- [x] CI pipeline: analyze → test → debug APK → release APK (GitHub Actions) — `.github/workflows/build-debug-apk.yml`
- [x] Sentry crash reporting (native + Flutter) — `9672108`
- [x] App icon (AdaptiveIcon with custom background + foreground drawable)

### Core Content Management
- [x] Collection / Item CRUD (Hive 3 boxes)
- [x] Item reorder (drag-and-drop)
- [x] Soft-delete + 30-day purge (Recently Deleted)
- [x] Backup & Restore (export/import JSON + safety snapshots)

### Android Widget
- [x] 5 states: configured, empty, expired, placeholder, error
- [x] Rotation across collection items
- [x] 6 curated gradient themes (ocean, sunset, forest, midnight, rose, sand)
- [x] Progress indicator (n/m items)
- [x] SharedPreferences alignment (HomeWidgetPreferences ↔ FlutterSharedPreferences)
- [x] **Native free-limit gate** — Kotlin counts configured_widget_ids, not Hive (Sprint A-1)
- [x] **Hybrid reconciliation** — orphaned WidgetConfig cleanup on startup/resume (Sprint A-2)
- [x] **onDeleted() cleanup** — both wcfg ↔ id direction (Sprint A-3)
- [x] **PREFS_VERSION + migratePreferences() skeleton** (Sprint A-4)
- [x] **Deep-link Upgrade Prompt** → paywall bottom sheet (cold-start + resume) (Sprint A-5)
- [x] **Graceful Pro-expiry on widget** — "24h Pass Expired — Tap to renew" → paywall deep link (plan5 §1.6) — `7eed09c`
- [x] **Startup re-render push after expiry** — syncProStatus → HomeWidget.updateWidget (no system refresh, updatePeriodMillis=0) — `4d6ce76`

### Onboarding
- [x] 2 flows (new user / import backup)
- [x] 5 use cases with distinct sample data
- [x] Live widget preview

### Monetization
- [x] Rewarded ad — watch → unlock Pro 24h (atomic grant, plan3 Fix A)
- [x] Widget refresh after Pro state change (plan3 Fix B)
- [x] Banner ad on home screen (always shown, including Pro)
- [x] Interstitial ad after destructive actions (always shown)
- [x] Flags: `ENABLE_ADS=true`, `TEST_ADS=true`
- [x] **All IAP purchase paths removed** — only rewarded-ad 24h unlock
- [x] **Pro no longer hides ads** — ads always shown regardless of Pro status

### Settings
- [x] Watch-Ad 24h Pro unlock
- [x] Recently Deleted
- [x] Backup & Restore
- [x] Privacy Policy link (→ GitHub Pages)
- [x] About

### Share
- [x] ShareReceiverActivity (Android share sheet → save to collection)
- [x] Pending share flow (single collection auto-save, multi-collection picker)
- [x] **Quick Share Undo** — 10s "Saved to X" SnackBar + Undo action (soft-delete to Trash) (plan5 §1.7) — `7eed09c`

### Pro / Widget limits
- [x] Multi-collection share picker uses navigator-key context (fix latent above-MaterialApp crash) — `7eed09c`

### Deep Link / Cold Start
- [x] Unconfigured widget tap → WidgetSetupScreen
- [x] Pending share text → save + toast
- [x] Upgrade to Pro widget tap → paywall sheet

### Navigation
- [x] Full nav audit — no dead ends
- [x] SafeBack pattern app-wide
- [x] Deep-link edge cases handled

### Privacy Page
- [x] `docs/privacy.html` — hosted on GitHub Pages
- [x] `.github/workflows/pages.yml` — auto-deploy on push

### Verification & Docs
- [x] **93/93 tests pass** — storage 29 · trash 9 · rotation 11 · iap 7 · rewarded 3 · interstitial 6 · paywall 4 · curated themes 4 · widget_limit 11 · share_service 4 · quick_share_undo 3 · widget_service 2 · widget_test 1
- [x] `flutter analyze` — 0 errors, 0 warnings
- [x] CI green (debug + release APK): runs `33832808067` (Sprint A) · `33857086225` + `33858880548` (plan5 Sprint 0) — commits `54f5c7d` / `7eed09c` / `4d6ce76`
- [x] plan5 Sprint 0 §1.1–§1.7 code DONE — openspec `changes/sprint0-completion/`
- [x] `features.md` — full feature/UI inventory, synced to HEAD `4d6ce76`

---

## ❌ Not Done / Open TODOs

### Immediate
- [ ] **Enable GitHub Pages** in repo Settings (manual: Settings → Pages → Source: GitHub Actions) — first push to main with `docs/` will trigger deploy
- [ ] **Device test (plan5 §1.8 gate)** — real Android device(s), Samsung + Pixel/stock: xoá Collection đang gắn Widget A → thêm Widget B không bị kẹt "Upgrade to Pro"; `wcfg_*` sạch sau khi kéo widget khỏi Home Screen; force-stop + reboot vẫn render đúng; Pro 24h hết hạn khi app đóng hoàn toàn vẫn tự khoá (widget 2 → "24h Pass Expired — Tap to renew", widget 1 vẫn chạy); 2 widget rotation độc lập; Quick Share Undo (save + Undo trong 10s); FAB không đè ads; paywall chỉ Watch Ad; privacy link mở
- [ ] plan5 Sprint 1/2/3 — NOT started (hard gate: pass device test §1.8 first)

### Monetization
- [ ] **Register real rewarded ad unit ID** in AdMob console (current: Google sample test ID) — required before disabling `TEST_ADS`
- [ ] **IAP product ID `com.quotewidget.pro`** — no longer needed (IAP removed), but keep listed in Play Console for legacy purchasers

### Polish
- [ ] `widget_config_screen.dart` — dead code, never imported. Delete when convenient
- [ ] `in_app_purchase` dependency removed from pubspec; `pubspec.lock` will regenerate on CI
- [ ] Settings "About" — add version number dynamically (currently hardcoded v1.0.0)
- [ ] Consider: Ukrainian/Russian/Vietnamese localization for app text

### Testing
- [ ] Automated UI tests for paywall flow (currently only widget tests)
- [ ] Test reconciliation edge cases with >50 widgets (performance)
