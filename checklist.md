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

### Phase 1–2B code quality (plan6 + phase1-correctness + phase2A/B)
- [x] **Phase 1 P0-2 reconcile full 2-way scan** — bỏ early-return fast path; full scan mỗi lần native ids có → mapping gãy dù count bằng vẫn cleanup (storage_service.dart `reconcileWidgetConfigs`), 2 tests mới + đổi 1 test fast-path cũ
- [x] **Phase 1 P0-3 backup no-phantom** — export `widgetConfigs: []`, import DROP mọi configs (const []), UI canonical copy; test phantom-restore
- [x] **Phase 1 P0-4 dead code** — `processShareText`/`ShareResult`/`getShareMessage`/`_isUrlOnly` deleted + dead tests; bridge header comment sửa favprefs file
- [x] **Phase 1 P0-5 release runbook** — ghi `--dart-define=TEST_ADS=false` vào operating_rules.md
- [x] **Phase 1 P0-6 IAP reward-only** — verified: không có buyPro/removeAds UI, không in_app_purchase dep
- [x] **Phase 1 P0-7 native onDeleted** — cleanup verified (đọc configId trước khi remove)
- [x] **Phase 2A**: Favorites (Item.favorite + All/Favorites filter + storage method), Favs-only widget (contentFilter enum + JSON pool + Kotlin pick-by-index → cũng fix tap-to-cycle text bug), Search Collection Detail (realtime in-memory), Duplicate Collection (batch putAll), Templates/Empty-state (Home empty → 5 starter packs / Start empty)
- [x] **Phase 2B**: Shuffle Bag (persist per widget, fingerprint invalidate), Daily rotation (daily_date/ daily_item_id/ daily_index/ next_rotation_at, local calendar, tap trong ngày không đốt daily slot), Auto-rotate (every_1h/3h/6h + daily), Tap action (next/open_collection/open_app/copy), Responsive 4×2 (widget_wide.xml + size branch + resize XML), Remember last collection for Share (`last_share_collection_id`)
- [x] **Phase 3 forensic review** — 2 fix code + 1 fix CI:
    - native-index preservation: `syncWidgetData` giữ native `widget_<id>_currentIndex` khi reads được từ prefs (tránh reset về 0 sau edit item)
    - shuffle-bag seed: `_syncShuffleBag` dùng `displayIndex` thay vì `config.currentIndex` (tránh lặp item hiện tại)
    - dead keys cleanup: `onDeleted` Kotlin dọn đủ keys (`_items`/`_contentFilter`/`_schedule`/`_tapAction`/`_shuffle_bag`/`_shuffle_index`/`_shuffle_source_fp`/`_daily_date`/`_daily_index`/`_next_rotation_at`)
    - test: re-sync-keeps-native-index được thêm vào widget_service_test
- [x] **Phase 3 CI fixes (real compile gate)**:
    - `widget_provider_info.xml`: comment trong start tag → parse error → comment chuyển ra ngoài tag (5 XML files parse sau fix)
    - Kotlin compile error: `(0 until n).shuffled()` trả read-only List → swap `bag[0] = bag[swapIdx]` lỗi → `MutableList` materialized, sau đó `(0 until totalItems).shuffled().toMutableList()`
- [x] Phases 1–2B toàn bộ 138 tests pass; analyze 0 issues

### Feature Close Batch (2026-09-06 — prompt_feature_close_batch_final.md)
- [x] **A1 privacy.html** — root stale copy removed (docs/ là canonical)
- [x] **A2 UMP consent** — `UmpConsentService` (requestConsentInfoUpdate → loadAndShowConsentFormIfRequired → canRequestAds); mọi ad path (banner/rewarded/interstitial) gate sau `canShowAds`; Privacy Options trong Settings khi Google yêu cầu; form suppressed trong onboarding (user decision), re-resolve ở HomeScreen
- [x] **A3 delete-collection ↔ free-limit** — `unbindWidgetConfig` (Hive + wcfg_* + configured_widget_ids qua cùng file Kotlin đọc/ghi + clear native display data) + Kotlin `unsaveConfiguredWidgetId` khi render không có collection; 3 tests
- [x] **A4 sizeCategory** — `syncWidgetData` chỉ ghi khi native chưa có giá trị; resize-derived layout không bị đè; 2 tests
- [x] **A5 reorder sync** — `reorderAndSyncItems` (reorder + updateWidgetsForCollection ngay lập tức); bulk-add defensive sync; 1 test
- [x] **A6 restore reconcile** — `reconcileAfterRestore` detach widget orphan ngay (không chờ resume) + refresh; 1 test
- [x] **A7 onRestored** — Kotlin override: clear old mapping + strip display data + registry rỗng + render "Tap to set up"
- [x] **A8 dead code + cleartext** — đã sạch từ phase trước (verify lại 0 refs); cleartext GIỮ (AdMob SDK doc: một số mediation serve creative qua HTTP) — verdict ghi trong network_security_config.xml
- [x] **Gate A** — analyze 0 issues, 145 tests pass
- [x] **B1 Author** — Item.author (String?, Hive field 9, backward-compat) + optional input add/edit + widget `<id>_author` key + Kotlin render "— author" (1 style) + cleanup keys; 1 test
- [x] **B2 Export/Import 1 collection** — `exportCollection`/`importCollection` + preview + confirm dialog (New collection / Add here); 4 tests
- [x] **B3 Share quote as image** — `renderQuoteCardPng` (pure Canvas renderer, testable) + ShareQuoteCardScreen + entry từ item menu; 4 tests
- [x] **B4 Widget Setup expose đủ engine** — verified: RotationMode.values / ScheduleMode.values / TapAction.values + favoritesOnly toggle đều có trong UI (không cần sửa)
- [x] **B5 About version động** — PackageInfo (`package_info_plus`); 1 test
- [x] **Gate B** — analyze 0 issues, 155 tests pass
- [x] **Block C** — features_final.md sync + Deferred V1.1 list + progress_feature_close.md + **FEATURE FREEZE**

### Phase 4 prep (Device QA gate — prompt_device_qa.md)
- [x] Openspec change `device-qa-gate` (proposal + tasks)
- [x] CI workflow_dispatch input `test_ads` (release APK `--dart-define=TEST_ADS=${{ inputs.test_ads || 'true' }}`) — chạy production ads build khi dispatch test_ads=false
- [x] QA candidate build dispatch với test_ads=false → run **33972687792** = success (release APK 30.6 MB, unit thật)
- [x] Run sheet `.plan/device_qa_run_sheet.md` — metadata + đủ MUST A1–A6/B1–B3/C1–C4/D1–D2/E1–E4/F1–F5/G1–G2/H1–H2 + SHOULD I1–I5 + tick boxes + triage hints
- [x] features_final.md sync (Phase 1–2B shipped → F4/F5 = MUST)

### Final Hardening Batch (2026-09-07 — prompt_final_hardening_batch.md)
- [x] **P0-1 — Snapshot không tạo phantom WidgetConfig** — `snapshot_manager.dart`: `createSnapshot` content-only (bỏ param `widgetConfigs`), `restoreFromSnapshot` restore với `widgetConfigs: const []`; 2 caller cập nhật (deleteCollection, importBackup). Snapshot FILE không còn chứa config (test assert file JSON). 2 test mới PASS (file content-only + config-unbound không resurrect)
- [x] **P1-1 — Reorder an toàn khi Search/Favorites active** — `collection_detail_screen.dart`: `_filterActive` guard trong `handleReorder` + snackbar "Tắt tìm kiếm/lọc để sắp xếp lại thứ tự"; drag bị disable (bọc tile bằng `ReorderableDelayedDragStartListener` chỉ khi không filter; handle disabled = IconButton → snackbar). 3 test widget mới PASS
- [x] **P1-2 — Daily lưu `daily_item_id`** — `widget_service.dart` `_pinDailyItem` (index + id); same-day revalidation (item còn → giữ id + re-derive index; item bị xóa → chọn lại giữ `daily_date`); Kotlin native day-advance clear id stale + `onDeleted`/`onRestored` dọn key `_daily_item_id`. 3 test mới + extend 1 test PASS
- [x] **P1-3 — Widget setup rollback** — `widget_setup_screen.dart` `_bindWidget` bọc mapping→sync→update; fail → `unbindWidgetConfig` + snackbar lỗi; cả 2 flow (`_save`, `_saveAndNavigateToDetail`). 1 test widget mới PASS (config không còn sau sync fail + không còn key `wcfg_*` + snackbar)
- [x] **P2-1 — Duplicate copy author** — `duplicateCollection` thêm `author: item.author`. 1 test mới PASS
- [x] **P2-2 — Dead code verify** — `widget_config_screen.dart` + `widget_preview.dart` **đã xóa từ trước**: `ls` No such file, grep lib/ = 0 ref, git ls-files = 0, analyze 0 issue (không import gãy). features.md/checklist.md đã ghi đúng
- [x] **P2-3 — AddWidgetGuide không auto-pin** — bỏ `_tryPinWidget()` khỏi initState → `_probePinSupport` (query support, không dialog); nút bấm mới request pin; xóa `_pinRequested`; `WidgetService.isRequestPinSupported` mới. 1 test widget mới PASS (0 request khi mở màn, đúng 1 khi bấm nút)
- [x] **Gate** — `flutter analyze` 0 issue, **`flutter test` 170/170** (159 cũ + 11 mới). Commit local `fix(final-hardening)` — chưa push
- [x] **Review fix `4dc6def`** — review sau commit phát hiện crash: `_pinDailyItem` có thể persist `daily_index = -1` (pool rỗng — vector mới từ P1-2) → Kotlin snap/ render `items[-1]` (IndexOutOfBounds). Fix: Dart không ghi index âm; Kotlin snap chỉ nhận index hợp lệ + render guard `>= 0`. +2 regression test → **172/172**

### Review + QA candidate (2026-09-07)
- [x] **Commit batch** — `c3b6f73` (35 files, +2285/−467) pushed to main; secret-scan sạch; session artifacts (handoffs/.project/skills-lock) cố tình không commit
- [x] **CI push run 34074858578** — success (analyze → test → debug APK → release APK)
- [x] **QA candidate MỚI — dispatch run 34074951700, input `test_ads=false`** — success; artifact `release-apk` sẵn sàng tải về
- [x] **Code review batch (OCR không khả dụng → review thủ công theo fallback + ponytail-review skill):** 0 blocker; 1 minor đã fix — ghi registry dư key rác `flutter.flutter.configured_widget_ids` (`f54623f`: 1 write duy nhất, plugin tự thêm prefix đúng key Kotlin đọc; test mới assert không sinh key rác); nguy cơ author-stale B1 xác nhận đã có test bọc (`widget_service_test.dart:399-421`)
- [x] **Cleanup `f54623f`** — analyze 0 issue, 155/155 tests (local; **chưa push** — no-op trên thiết bị, không bắt buộc build lại QA candidate)
- [x] **Cleanup `1fff5bc` (mirror f54623f)** — `widget_data_bridge.dart`: bỏ write dư `flutter.is_pro_expires_at` (key rác `flutter.flutter.*`) + cắt term đọc chết trong `getProExpiry`; test mới `widget_data_bridge_test.dart` (4 test: contract key + cấm mọi key `flutter.flutter.*`) — analyze 0 issue, **159/159 tests** (local; **chưa push**)

### Verification (current state — sau Final Hardening Batch)
- [x] `flutter analyze` — 0 errors, 0 warnings
- [x] `flutter test` — 172/172 All tests passed (138 gốc + 17 feature-close + 4 bridge-hygiene + 11 final-hardening + 2 review-fix)
- [x] Dead code: `source/` gone, `widget_config_screen.dart`/`widget_preview.dart` deleted, 0 references
- [x] CI green: debug APK + release APK artifact (push build) + QA candidate success (TEST_ADS=false, run 33972687792)
- [x] Canonical feature spec `.plan/features_final.md` synced (Phase 1–2B ship, deferred ghi rõ)

---

## ❌ Not Done / Open TODOs

### Immediate (agent không làm được — cần human + device)
> **✅ 2026-09-07 update:** batch đã commit `c3b6f73` + push; QA candidate mới = **run 34074951700 (TEST_ADS=false, success)** — chỉ còn: (1) tải artifact `release-apk` từ run đó, (2) chạy Wave 1 trên Device A. Cleanup `f54623f` chưa push nhưng là no-op trên thiết bị (không đổi hành vi) → APK candidate vẫn hợp lệ cho Wave 1.
- [ ] **Device test gate (plan5 §1.8 + Phase 4)** — chờ human tester chạy Wave 1–6 theo `.plan/device_qa_run_sheet.md`:
    1. A1–A5 (Wave 1 lifecycle/limit blockers)
    2. B1 reboot / B2 force-stop / B3 update simulation
    3. C1 rewarded-unlock-24h (QA build TEST_ADS=false) + C2 no-fill + C3/C4 expiry
    4. D1–D2 share + E1–E4 backup (E3 restore không phantom)
    5. F1–F5 rotation + G1–G2 OEM (Device B)
    6. H1/H2 ads production
    7. SHOULD I1–I5 (ghi risk nếu fail, không block tự)
- [ ] **CLOSED_TESTING_OK verdict** chỉ có sau khi tất cả MUST PASS (hoặc N/A khi feature chưa ship — nhưng F4/F5 đã ship)

### Release prep (trước wide)
- [x] **GitHub Pages** — ✅ 2026-09-08: Pages đã BẬT, source = branch `gh-pages` (orphan, chỉ chứa index.html). API verify: status=built, source={branch: gh-pages, path: /}. Trang cũ `docs/privacy.html` không đủ (thiếu email liên hệ) → đã sync nội dung mới vào `docs/` + `store_assets/privacy-policy.html` (1 nguồn, email haibasoftware@gmail.com); `pages.yml` (deploy docs/ qua Actions — sẽ ghi đè nhánh gh-pages) đã xóa để không xung đột source.
- [x] **Privacy URL live verify**: ✅ `https://hoangsoft90.github.io/QuoteWidget/` HTTP 200 + title "Privacy Policy — Your Words" (curl 2026-09-08). URL dán vào Play Console.

### Release signing / AAB / version (nếu cần upload Play Store)
- [ ] **Version bump** — bạn muốn versionName+versionCode là bao nhiêu trước production (vd 1.0.0 → 1.0.1 / 1.1.0)?
- [x] **AAB artifact** — ✅ ĐÃ SHIP (release-engineering Task 2): step `Build release AAB` + `Upload AAB artifact` trong `.github/workflows/build-debug-apk.yml`, dùng chung input `test_ads`, APK step giữ nguyên cho QA candidate
- [x] **Release signing config** — ✅ ĐÃ SHIP (Task 1): `android/app/build.gradle.kts` đọc `android/key.properties` nếu tồn tại, fallback debug signing + warning nếu không (CI/build local không bao giờ fail); template `android/key.properties.example` đã commit; thật `key.properties`/`upload-keystore.jks` bị gitignore (root + android)
- [x] **CI keystore decode step** — ✅ ĐÃ SHIP (Task 4): step `Decode release keystore from CI secrets` decode base64 → `android/app/upload-keystore.jks` + sinh `android/key.properties` trên runner. **Lưu ý (fix `e1a0060` sau review):** gate bằng `if: secrets.X != ''` là KHÔNG đáng tin (GitHub docs: secrets không dùng được trong `if:`) → step luôn chạy, gate nằm TRONG script qua env (`[ -z "$RELEASE_KEYSTORE_BASE64" ] → exit 0`), secrets được wire qua step-level `env:`
- [ ] **Cần user làm (không thể agent tự làm):**
  1. ~~Tạo keystore thật~~ — ✅ ĐÃ LÀM 2026-09-08: `android/app/upload-keystore.jks` (PKCS12, RSA 2048, alias `upload`, validity 10000d) đã sinh bằng keytool; verify 1 entry; `android/key.properties` đã điền (cả 2 file gitignored — `git check-ignore` pass)
  2. ~~Điền `android/key.properties` thật~~ — ✅ ĐÃ LÀM (cùng lúc, local only, không commit) — password được giao cho user qua chat để set secrets
  3. ~~Thêm 4 secret vào GitHub repo~~ — ✅ ĐÃ LÀM 2026-09-08 qua `gh secret set` (đọc trực tiếp từ `android/key.properties` + base64 từ `.jks`, không echo giá trị) — `gh secret list` verify đủ 4: `RELEASE_KEYSTORE_BASE64`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`. **⚠️ Gotcha PKCS12 (đã gặp, run 34186957708 FAIL):** keystore PKCS12 (mặc định JDK mới) KHÔNG hỗ trợ key password khác store password — `keytool -keypass` bị bỏ qua, key luôn mã hoá bằng **store password** → gradle đọc key với keyPassword ≠ storePassword ném `Given final block not properly padded`. Fix: `RELEASE_KEY_PASSWORD` = `RELEASE_STORE_PASSWORD` (cùng giá trị).  Run OK: **34187629369** — success, AAB verify ký release `CN=Your Words` (META-INF/UPLOAD.RSA, SHA256 C6:FC:...:67:B7, valid tới 2054).
  **⚠️ Gotcha #2 (GitHub Actions boolean input):** expression `${{ inputs.test_ads || 'true' }}` nuốt boolean `false` (falsy → fall về `'true'`) — dispatch kiểu gì (`-f` lẫn JSON `false`) cũng ra TEST_ADS=true. Fix (2026-09-08): **ads thật là code default** — `ad_config.dart` `TEST_ADS` defaultValue `false` + workflow fallback `|| 'false'` (commit `fdbe2cf`); không cần dispatch nữa. Verify: push run **34188757417** → `dart-define=TEST_ADS=false` → AAB chứa 3 unit ID THẬT, không unit test nào.
  4. Sau khi secrets có: dispatch CI → AAB artifact `release-aab` sẽ ký bằng key thật, upload được Play Console (Closed Testing)
  - Ghi chú: cho tới khi secrets được cấu hình, AAB trong CI ký debug key → Play sẽ từ chối upload; APK QA candidate vẫn dùng như cũ

### Polish (không block)
- [x] Settings "About" — version động (B5 — PackageInfo)
- [ ] Localization (Unicode/Vietnamese/Russian) — nếu có ý định

### Testing (nâng cao — không block release)
- [ ] Automated UI tests cho paywall retry loop (hiện widget tests)
- [ ] Reconciliation performance edge case (>50 widget configs)

### Feature-deferred (ghi rõ để tránh claim ảo)
- [x] Export collection JSON — ✅ ĐÃ SHIP (Feature Close B2); CSV deferred V1.1
- [ ] App shortcuts — 🚫 Deferred V1.1 (FEATURE FREEZE)
- [ ] Material You — 🚫 Deferred V1.1 (FEATURE FREEZE)
- [ ] TXT/clipboard import entry — 🚫 Deferred V1.1 (FEATURE FREEZE)
- [ ] Tags / Time-of-day / Multi-source / History-Statistics / Widget prev-fav-next buttons / Preset marketplace / Notification reminders — 🚫 Deferred V1.1 (FEATURE FREEZE — list đầy đủ trong features_final.md §8)

> **⚠️ FEATURE FREEZE (2026-09-06):** từ giờ chỉ nhận bugfix + Device QA. Không nhận feature mới cho tới khi có verdict CLOSED_TESTING_OK. Bước tiếp theo: chạy `.plan/prompt_device_qa.md` (Wave 1) trên APK build với `TEST_ADS=false`.

### Cần hỏi lại user (chờ quyết định — đã ghi trong next.md)
1. ~~Push cleanup commits?~~ → ✅ ĐÃ PUSH (release-engineering Bước 0: `f54623f` + `1fff5bc` + `c29e1b5` → origin/main)
2. ~~AAB có cần không?~~ → ✅ ĐÃ SHIP (Task 2 — xem section trên)
3. **Version bump** trước release (vd 1.0.0 → 1.0.1 / 1.1.0)?
4. ~~Release signing pattern?~~ → ✅ config đã ship (Task 1, chuẩn key.properties của Flutter docs); còn lại việc tạo keystore + secrets là của user (4 bước trong section trên)
5. **Privacy URL live** — verify `https://hoangsoft90.github.io/QuoteWidget/privacy.html` resolving?
6. **Revoke PAT cũ** trên GitHub Settings → Developer settings (agent đã dọn token khỏi remote URL, nhưng token cũ vẫn còn hiệu lực cho tới khi bạn revoke)
7. **Cấu hình credential mới để push GỘP 4 commit** — sau khi dọn PAT khỏi remote URL (Task 3), `git push` cần SSH key hoặc fine-grained PAT mới; local ahead gồm `fix(final-hardening)` + docs + `70deddb` + `e1a0060` (hardening + release engineering)
