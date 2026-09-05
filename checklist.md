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
- [x] **Share-target confirmation dialog** — "Lưu vào [collection gần nhất] / Đổi collection / Huỷ", no auto-save, no timer (plan6 H5)
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

### Plan6 bugfix (Sprint 0 hardening)
- [x] **C1 startup reconciliation** — orphan `wcfg_*` mapping cleanup via `getConfigIdForWidget()` + Hive lookup (thay block so int-vs-UUID giả chết) — 4 tests
- [x] **C4 rewarded real ID** — `ca-app-pub-6917313063209470/7613467914` (khác sample ID) — 2026-09-05
- [x] **C5 dead code removed** — `widget_config_screen.dart` + `widget_preview.dart` xóa; CI `flutter analyze --fatal-warnings`; rule cấm `// ignore:` trần trong operating_rules.md
- [x] **H2 rewarded no-fill** — `RewardedAdResult.unavailable` + dialog "Không có quảng cáo lúc này" + Retry (paywall + settings); test no-ad → unavailable
- [x] **H5 share-target dialog** — 5 widget tests
- [x] **H6 restore rollback** — 2 integration tests: snapshot trước clearAll, rollback về đúng trạng thái cũ
- [x] **H1/H4** — rewarded-only giữ nguyên là chiến lược chính thức (docs); no hardcoded Pro=true in lib (chỉ legacy migration)
- [x] Verified C2 (onDeleted wcfg cleanup) / C3 (native-count gate) / H3 (PREFS_VERSION) đã tồn tại từ Sprint A — không cần code mới

### Verification & Docs
- [x] **Full suite pass** — baseline 93 + mới: storage +4 (C1) · rewarded +1 (H2) · share_target_dialog +5 (H5) · restore_rollback +2 (H6) — evidence trong output test
- [x] `flutter analyze` — 0 errors, 0 warnings
- [x] CI green (debug + release APK): runs `33832808067` (Sprint A) · `33857086225` + `33858880548` (plan5 Sprint 0) · plan6 (pending)
- [x] plan5 Sprint 0 §1.1–§1.7 code DONE — openspec `changes/sprint0-completion/`
- [x] plan6 code DONE — openspec `changes/plan6-bugfix/`
- [x] `features.md` — full feature/UI inventory, synced to plan6

---

## ❌ Not Done / Open TODOs

### Immediate
- [ ] **Enable GitHub Pages** in repo Settings (manual: Settings → Pages → Source: GitHub Actions) — first push to main with `docs/` will trigger deploy
- [ ] **Device test gate (plan5 §1.8 + plan6 Device QA — 10 mục)** — real Android device(s), Samsung + Pixel/stock:
      1. Xoá Collection đang gắn Widget A → thêm Widget B → free-limit chặn NGAY trong app (không để B kẹt "Upgrade to Pro")
      2. Kéo widget khỏi Home Screen → dump prefs (adb) → không còn `wcfg_*` của appWidgetId đã xoá
      3. Configure → force-stop → mở lại → tap vẫn cycle đúng
      4. Configure → reboot → vẫn render đúng, tap hoạt động
      5. Rewarded 24h hết hạn khi app đóng hoàn toàn → mở lại → widget 2 tự khoá "Renew"/"Upgrade"
      6. 2 widget → tap widget A → widget B KHÔNG đổi theo (currentIndex độc lập)
      7. Xoá rồi thêm lại widget liên tiếp (appWidgetId reuse) → không hiển thị data cũ sai
      8. Share Sheet end-to-end (Chrome/Reddit → Share → app) → dialog "Lưu vào collection" hiện đúng → lưu đúng chỗ → widget cập nhật
      9. Tăng PREFS_VERSION thủ công → mở app → migration chạy đúng 1 lần, không lặp, không mất dữ liệu
      10. Build `TEST_ADS=false` tạm → xem rewarded → logcat đúng ad unit `.../7613467914`, không phải sample
- [ ] plan5 Sprint 1/2/3 — NOT started (hard gate: pass device test first)

### Monetization
- [x] **Rewarded real ad unit ID registered** — `ca-app-pub-6917313063209470/7613467914` (plan6 C4) — verify logcat trên device (Device QA #10)
- [ ] **IAP product ID `com.quotewidget.pro`** — no longer needed (IAP removed), but keep listed in Play Console for legacy purchasers

### Polish
- [ ] Settings "About" — add version number dynamically (currently hardcoded v1.0.0)
- [ ] Consider: Ukrainian/Russian/Vietnamese localization for app text

### Testing
- [ ] Automated UI tests for paywall retry loop (currently widget tests)
- [ ] Test reconciliation edge cases with >50 widgets (performance)
