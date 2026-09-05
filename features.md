# Features — Quote Widget ("Your Words")

> Tài liệu đầy đủ tính năng + UI của app, đối chiếu trực tiếp với source code.
> **Canonical feature spec: `.plan/features_final.md`** (thắng nếu lệch — Phase 1 P0-4).
> Cập nhật lần cuối: 2026-09-05 (HEAD plan6-bugfix, CI green debug + release).

**App:** Hiển thị nội dung cá nhân (quote, từ vựng, lời nhắc…) trên Home Screen widget Android.
**Tech:** Flutter 3.47.1 / Dart 3.13.1 · Hive (local DB) · home_widget + Kotlin RemoteViews · Android only (minSdk 24, compileSdk/targetSdk 36).

---

## 1. Danh sách màn hình (screens)

| # | Screen | File | Vai trò |
|---|---|---|---|
| 1 | **Onboarding** (Welcome) | `lib/screens/onboarding_screen.dart` | Màn hình đầu tiên khi chưa hoàn tất onboarding: logo, tagline, progress 3 bước, 3 lựa chọn (Start with Sample / Add Your Own / Skip) |
| 2 | **Use Case Selection** | `lib/screens/use_case_selection_screen.dart` | Chọn 1 trong 5 starter pack → tạo sample collection → **live widget preview** (tap để cycle item, hiện index/total) → Continue tới Add Widget Guide |
| 3 | **Onboarding Create Collection** | `lib/screens/onboarding_create_collection_screen.dart` | Bước 1 luồng "Add Your Own": nhập tên collection đầu tiên (hoặc Skip) |
| 4 | **Onboarding Add Item** | `lib/screens/onboarding_add_item_screen.dart` | Bước 2: thêm item đầu tiên (hoặc Skip) |
| 5 | **Add Widget Guide** | `lib/screens/add_widget_guide_screen.dart` | Hướng dẫn thêm widget theo từng OEM (Samsung/Xiaomi/Stock, tự nhận diện qua `device_info_plus`), nút "Add Widget to Home Screen" (requestPinWidget nếu hỗ trợ), "I've added the widget" / "Skip for now" |
| 6 | **Home** | `lib/screens/home_screen.dart` | Danh sách collection (card: avatar chữ cái đầu, tên, số item, menu ⋮ → Delete), FAB "+" tạo collection, **banner ad đáy màn hình** (free tier), Settings icon |
| 7 | **Collection Detail** | `lib/screens/collection_detail_screen.dart` | Danh sách items **reorder bằng drag** (ReorderableListView), edit/delete từng item (dialog), progress badge `x/y` trên AppBar (nếu có widget config), FAB add item, nút Bulk Add |
| 8 | **Bulk Add** | `lib/screens/bulk_add_screen.dart` | Dán nhiều dòng, 1 dòng = 1 item, live preview đếm + danh sách, nút "Add All" (có confirm) |
| 9 | **Settings** | `lib/screens/settings_screen.dart` | Xem chi tiết ở §5 |
| 10 | **Recently Deleted** | `lib/screens/recently_deleted_screen.dart` | Trash: 2 section (Collections / Items), mỗi row có Restore (xanh) + Delete Forever (đỏ, có confirm), purge 30 ngày tự động |
| 11 | **Backup & Restore** | `lib/screens/backup_screen.dart` | Export backup (JSON + share sheet), Import (Append / Overwrite — chọn trước khi import), Safety Snapshots (list, restore, giữ tối đa 3) |
| 12 | **Widget Setup** | `lib/screens/widget_setup_screen.dart` | Màn hình cấu hình widget: chọn collection → "Set Up Widget". Là **điểm chặn widget limit**: Free user thêm widget thứ 2 → paywall bottom sheet (Watch Ad — Unlock 24h / Cancel) |
| 13 | **Collection Picker** (dialog) | `lib/screens/collection_picker_dialog.dart` | Khi share text và người dùng chọn "Đổi collection" trong dialog xác nhận: chọn đích lưu, kèm tùy chọn "Create New Collection" |
| — | ~~Widget Config~~ | ~~`lib/screens/widget_config_screen.dart`~~ | **ĐÃ XÓA** (plan6 C5, 2026-09-05) — dead code không được import; kèm `widget_preview.dart` cũng không còn ai dùng |

---

## 2. Tính năng core (content management)

- **Collections:** tạo (Home FAB / onboarding / share picker), đổi tên (qua `StorageService.updateCollection`), xóa (soft-delete → trash).
- **Items:** thêm (dialog 1 item), thêm hàng loạt (Bulk Add), sửa, xóa (soft-delete), **sắp xếp kéo-thả** (lưu `order`).
- **Trash / Recently Deleted (Task 7):** `isDeleted` + `deletedAt` trên cả `Collection` và `Item`. Restore nguyên cụm (collection + items) hoặc từng item. **Purge tự động sau 30 ngày** — chạy ở startup (`main.dart`) và mỗi lần mở màn hình Recently Deleted.
- **Dữ liệu lưu local:** Hive 3 boxes: `collections`, `items`, `widget_configs`. Hoàn toàn offline-first.

---

## 3. Widget Home Screen (native Android)

**Kích thước:** small (2×1, 110dp) / medium (medium layout 4 dòng) — `resizeMode="none"`.

**Các trạng thái render** (`QuoteWidgetProvider.kt` `updateAppWidget`):
| Trạng thái | Hiển thị | Tap → |
|---|---|---|
| Chưa cấu hình (`collectionId` rỗng) | "Tap to set up this widget" (xám) | Mở app → `WidgetSetupScreen` (ghi `tapped_widget_id`) |
| Collection đã bị xóa | "Collection removed. Tap to choose another." | Mở app để chọn lại |
| Collection rỗng | "Add some content to this collection." | Mở `CollectionDetailScreen` (kèm `tapped_collection_id`) |
| Có nội dung | Text item + progress `x/y` (nếu bật) | **Cycle item tiếp theo** (broadcast `com.quotewidget.WIDGET_TAP`) |
| **Free + widget thứ 2** (chưa cấu hình) | Placeholder **"Upgrade to Pro / to add more widgets"** (nền xám) | Mở app → paywall sheet (`route=paywall`, A-5) |
| **Pro 24h hết hạn + widget thứ 2** (đã cấu hình) | **"24h Pass Expired — Tap to renew"** (nền xám, plan5 §1.6) | Mở app → paywall sheet gia hạn |

**Graceful Pro-expiry (§1.6):** khi pass 24h hết hạn, widget thứ 2 KHÔNG biến mất/giữ content cũ vô thời hạn — `isExpiredLocked()` (widget cấu hình vượt free-limit 1, không phải widget cũ nhất) → render prompt gia hạn; widget cũ nhất (free slot) vẫn chạy bình thường. Check nằm trong `updateAppWidget()` nên **mọi** render path tôn trọng lock; tap content cũ sau expiry tự chuyển sang prompt. Vì `updatePeriodMillis=0` (không có system refresh), `WidgetService.syncProStatus` (chạy lúc startup) push `HomeWidget.updateWidget` sau khi ghi `is_pro` → lock tự áp dụng ngay lần mở app kế tiếp, không cần chờ tap/reboot.

**Rotation khi tap:** `rotationMode` = `sequential` (next +1, wrap) hoặc `random` (không trùng item hiện tại) — logic trong Kotlin (`handleTap`) và `RotationService` (Dart).

**Progress indicator:** `showProgress` bật → text `x/y` (x = currentIndex+1) ở góc (small) hoặc dưới text (medium). Tắt khi không có nội dung / bị remove / chưa cấu hình.

**6 Curated Themes (Task 6):** ocean · sunset · forest · midnight · rose · sand — gradient drawable `widget_bg_<id>.xml` (có bo góc) gán qua `setBackgroundResource` lên `widget_root` + màu accent cho progress. Hợp đồng: `lib/models/widget_theme.dart` id ↔ drawable ↔ `themeDrawableFor()`/`themeAccentFor()` trong Kotlin. Light/Dark/Custom fallback về màu nền solid.

**Dữ liệu widget (CRITICAL — 2 file SharedPreferences):**
- **`HomeWidgetPreferences`** — widget data qua `HomeWidget.saveWidgetData()` (keys `widget_<id>_*`: text, theme, fontSize, currentIndex…). Kotlin đọc file này trước.
- **`FlutterSharedPreferences`** — supplementary: `is_pro`, `is_pro_expires_at`, `configured_widget_ids` (Kotlin ghi cả key thường + `flutter.` prefix). Không dùng default prefs (từng gây bug critical).

**Native lifecycle:** `onUpdate` (render + enforce limit + `migratePreferencesIfNeeded`), `onAppWidgetOptionsChanged` (re-render khi resize), `onDeleted` (dọn prefs 2 file + `wcfg_*` mapping cả 2 chiều + cập nhật `configured_widget_ids`), `onReceive` (xử lý tap). `WidgetReceiver` (BroadcastReceiver) chuyển tiếp tap.

**Registry consistency (Sprint A, plan4 + Phase 1 P0-2):** free-limit gate đọc NATIVE `configured_widget_ids` qua MethodChannel `quotewidget/widgets` (không tin Hive box — tránh dead-end trap). `reconcileWidgetConfigs()` chạy **full 2-way scan mỗi lần** native ids có sẵn (đã bỏ early-return "count == count → skip" — Phase 1 P0-2 fix lỗi P1 "count bằng nhau nhưng mapping gãy"): (1) Hive config không có `wcfg_*` mapping → xóa (phantom); mapping trỏ widget đã biến mất → xóa config + mapping cả 2 chiều; (2) native id có mapping trỏ config không còn trong Hive → xóa mapping cũ; native id chưa mapping → giữ nguyên ("Tap to set up").

**Startup orphan-mapping cleanup (plan6 C1):** `main.dart` sau khi init đọc `configured_widget_ids` → với mỗi native id, resolve `wcfg_<id>_configId` qua `WidgetDataBridge.getConfigIdForWidget()` → nếu mapping tồn tại NHƯNG config tương ứng không còn trong Hive (collection đã bị xóa) → gọi `removeWidgetMapping()` dọn mapping cũ (2 chiều). Widget chưa có mapping = "Tap to set up" — không đụng tới. Chạy trong `Future.microtask` (không chặn frame đầu). Fix thay thế block so sánh int-vs-UUID luôn-false trước đó (bị `// ignore: unused_local_variable` che giấu).

---

## 4. Onboarding & Sample data

- **2 luồng bắt đầu:** "Start with Sample" (chọn use case → tạo sẵn) hoặc "Add Your Own" (Create Collection → Add Item → Add Widget Guide) hoặc "Skip".
- **5 use cases** (`SampleDataService`): Vocabulary · Motivation & Affirmation · Work & Focus · Gym & Workout · Personal Quotes. Mỗi bộ 7–8 item **tự viết** (không quote người nổi tiếng), tạo 1 collection.
- **Live preview:** sau khi tạo sample → màn hình preview hiển thị `QuoteCard` (kích thước medium) đúng appearance, tap để cycle + đếm `x/y`.

---

## 5. Settings (chi tiết)

1. **Pro status row** (động): `Free (1 Widget)` / `Pro unlocked — Xh left` (24h) / `Pro (Lifetime)` (legacy purchasers). Tap khi free → xem rewarded ad unlock 24h.
2. **Recently Deleted** → màn hình trash.
3. **Backup & Restore** → export/import/snapshots.
4. **Privacy Policy** — mở `https://hoangsoft90.github.io/QuoteWidget/privacy.html` (url_launcher, external).
5. **About** — "Quote Widget – Your Words v1.0.0".

> **2026-09-04:** Toàn bộ tính năng purchase đã gỡ (Remove Ads Forever + Restore Purchases + dependency `in_app_purchase`). Monetization chỉ còn rewarded-ad 24h. Pro **không** ẩn ads nữa.

---

## 6. Monetization (Ads + IAP)

| Nguồn | Vị trí | Chi tiết |
|---|---|---|
| **Rewarded ad** (duy nhất) | Settings Pro row · paywall sheet (widget-limit + deep-link) | Xem hết ad → **Pro 24h** (time-bound, tự khóa lại sau hết hạn, cả khi app đóng — Kotlin check `is_pro_expires_at`). Grant chỉ báo thành công **sau khi persist xong** (Fix A) |
| **Banner** | Home đáy (`bottomNavigationBar`) | Anchored adaptive banner + bottom inset tránh 3-button nav; **luôn hiển thị kể cả Pro** (2026-09-04 — Pro không ẩn ads); Scaffold tự nâng FAB [+] lên khỏi ad (không đè nhau) |
| **Interstitial** | Sau destructive actions | delete-forever (collection/item), overwrite import, restore snapshot — tần suất: **1 lần mỗi 5 action** + cooldown 5 phút, preload nền, fail im lặng. Không gate theo Pro |

**Config (`AdConfig`):**
- `ENABLE_ADS=true` (default) — tắt ads bằng `--dart-define=ENABLE_ADS=false`.
- `TEST_ADS=true` (default) — mọi unit ID resolve về sample ID của Google (không bị AdMob giới hạn khi test). Bật ads thật: `--dart-define=TEST_ADS=false`.
- App ID thật trong manifest (`ca-app-pub-6917313063209470~9587990603`); **cả 3 unit ID real** trong code — rewarded `ca-app-pub-6917313063209470/7613467914` đã đăng ký & thay thế (plan6 C4, 2026-09-05), KHÁC sample ID `_testRewarded`.
- `nonPersonalizedExtras = {'npa': '1'}` — quảng cáo không cá nhân hóa.

**Widget limit (free = 1 widget):** enforce 2 tầng — `StorageService.createWidgetConfig` ném `WidgetLimitReachedException` (Flutter) + placeholder native "Upgrade to Pro" khi kéo widget thứ 2 (Kotlin `onUpdate`). Pro provider live (`setProStatusProvider`) → hết 24h là tự khóa lại ngay.

> **Chiến lược chính thức (2026-09-05, plan6 H1 — KHÔNG đảo ngược):** rewarded-ad 24h **chỉ mở thêm widget limit**, KHÔNG tắt banner/interstitial. IAP đã gỡ là chủ đích (2026-09-03, giữ nguyên) — không phải "phần còn sót cần dọn". Banner luôn hiện kể cả Pro.

---

## 7. Share từ app khác (Task 2)

- `ShareReceiverActivity` nhận `ACTION_SEND text/plain` → ghi `flutter.pending_share_text` + `flutter.share_timestamp` vào **đúng file `FlutterSharedPreferences`** (key prefix `flutter.`) bằng `.commit()` đồng bộ → `finish()` **không mở app UI** (translucent theme, noHistory, excludeFromRecents → không flash). Kotlin KHÔNG ghi Hive — chỉ prefs (plan6 H5 verify).
- `main.dart` `_handlePendingShare()` khi mở app (plan6 H5): 0 collection → toast nhắc tạo; có collection → **dialog xác nhận** `lib/widgets/share_target_dialog.dart`: "Lưu vào [collection mặc định/gần nhất]" / "Đổi collection" (mở picker) / "Huỷ" — **KHÔNG auto-save, không timer 5s**. Sau khi xác nhận lưu → refresh widget + SnackBar "Saved to <name>" có nút Undo (10s, §1.7).
- **Quick Share Undo (§1.7):** `ShareService.saveToCollection` trả đúng `Item` vừa tạo (Undo target chính xác, không đoán). Tap **Undo** trong ~10s → soft-delete item đó (về Trash — recoverable) + refresh widget collection → xác nhận "Share removed". UI nằm trong `lib/widgets/share_undo_snackbar.dart` (helper testable). SnackBar tự hết hạn — không Undo sau cửa sổ.
- Toast native (channel `quotewidget/toast` trong `MainActivity`) chỉ còn cho các path không có gì để undo (fail / chưa có collection).

---

## 8. Backup & Safety (Task 3)

- **Export:** JSON `quotewidget-backup-<ts>.json` (format `quote-widget-backup`, schema v1) → share sheet. **Chỉ chứa Collections + Items — KHÔNG export WidgetConfig active** (field `widgetConfigs: []` — Phase 1 P0-3).
- **Import:** picker `.json` (giới hạn 20MB), validate format/schema/fields/dupes/refs; **mọi `widgetConfigs` trong file bị bỏ qua — không bao giờ tạo phantom Hive config** (P0-3); 2 chế độ:
  - **Append** — thêm mới, bỏ qua ID trùng.
  - **Overwrite** — **tạo safety snapshot trước**, restore thay thế, rollback tự động nếu thất bại, trigger interstitial.
- **Safety Snapshots:** tạo trước destructive ops (delete collection, overwrite import) + restore từng snapshot, giữ tối đa 3, tự xóa cũ.

---

## 9. Deep link / cold start

- **Tap widget chưa cấu hình** (cold start): Kotlin ghi `tapped_widget_id`/`tapped_collection_id` → `main.dart` mở thẳng `WidgetSetupScreen` làm root. **Edge case đã fix:** nếu screen này là root route, `_save()` không pop (black screen) mà `pushReplacement` Home.
- **Tap "Upgrade to Pro" / "24h Pass Expired" trên widget** → launch intent kèm `route=paywall` → MainActivity persist `pending_route` (cả 2 file prefs) → Flutter đọc lúc cold-start (`showPaywallOnStart`) hoặc warm-start (`_checkPendingPaywallRoute` trên resume) → mở thẳng paywall bottom sheet (`lib/widgets/paywall_sheet.dart`, Watch Ad 24h / Cancel).
- **Warm start** (app đang chạy, tap widget cấu hình): `MainActivity.onNewIntent` ghi prefs → `didChangeAppLifecycleState(resumed)` → `_checkPendingWidgetTap()` → push `WidgetSetupScreen`.
- **Kèm reconciliation trên resume** (`didChangeAppLifecycleState`): widget có thể bị thêm/gỡ trên Home Screen lúc app ở nền → `reconcileWidgetConfigs()` chạy lại.
- No formal router — Navigator 1.0 imperative; mọi `showDialog`/`SnackBar` từ app-level dùng `navigatorKey` context (context trên MaterialApp không có Navigator — từng là latent crash ở share multi-collection, đã fix).

---

## 10. Hạ tầng / Release

- **Sentry:** `sentry_flutter ^9.28.0` (DSN trong code + manifest `io.sentry.dsn` cho native crash), `tracesSampleRate = 0.0`.
- **targetSdk/compileSdk 36** (yêu cầu Google Play 31/8/2026) · AGP 8.11.1 · Gradle 8.14.3 · Kotlin 2.2.20 · Java 17.
- **Cleartext HTTP:** `network_security_config.xml` (base-config cleartextTrafficPermitted=true) + manifest attribute — http hoạt động trong release APK.
- **App icon:** adaptive (gradient + `format_quote` vector) + legacy PNG đủ mipmap.
- **CI (GH Actions):** Flutter 3.47.1 → `flutter analyze` → `flutter test` → **build debug APK + release APK** (2 artifacts, đọc log thật nếu fail).
- **Theme app:** Material 3, seed `#6750A4`, light + dark.
- **Điện thoại duy nhất:** Android-only (iOS scaffold có sẵn nhưng chưa setup ads/không trong scope).

---

## 11. Test suite

- `flutter test` → **toàn bộ pass**; `flutter analyze` → 0 errors, 0 warnings (`--fatal-warnings` chạy trên CI — plan6 C5).
- Phủ: storage (collections/items/widget-configs/trash/purge/limit + A1 native-count gate + A2 reconciliation + **C1 orphan-mapping cleanup**), rotation service, IAP (time-bound Pro, permanent, Fix B widget-push), rewarded outcome gate (Fix A) + **H2 no-ad → unavailable enum**, interstitial frequency gate, backup import/export, curated themes consistency, widget limit, **share service (§1.7 Undo target)**, **share-undo SnackBar UI (3 widget tests §1.7)**, **share-target dialog UI (5 widget tests plan6 H5)**, **restore rollback (2 integration tests plan6 H6 — snapshot trước clearAll, rollback về đúng trạng thái cũ)**, **syncProStatus startup-push (§1.6)**, paywall sheet, onboarding/sample data.
- Mô phỏng: Hive `init(testPath:)`, SharedPreferences `setMockInitialValues`, MethodChannel mock (`home_widget`, toast), `PathProviderPlatform` fake (H6).

---

## 12. Non-goals / lưu ý

- **KHÔNG** thêm: photo background, custom fonts, iOS widget, cloud sync (feature freeze — plan3).
- **KHÔNG** tạo/đổi file SharedPreferences hay key Pro (rule critical).
- **Dead code:** `widget_config_screen.dart` + `widget_preview.dart` **đã xóa** (plan6 C5) — không còn nữa.
- **2026-09-04:** `in_app_purchase` đã gỡ khỏi pubspec (IAP removed) — chỉ còn rewarded-ad 24h. `proUnlockedUntil = DateTime(9999)` chỉ còn từ legacy migration (`iap_pro_purchased`). **Giữ nguyên là chủ đích** (plan6 H1 xác nhận lại).
- **2026-09-04 (plan5 Sprint 0):** §1.6 Graceful Pro-expiry + startup re-render push; §1.7 Quick Share Undo + fix latent crash share multi-collection. Sprint 1/2/3 chưa mở — gate cứng: pass device test §1.8 trước.
- **2026-09-05 (plan6):** C1 startup orphan-mapping cleanup (fix reconciliation giả chết); C4 rewarded real ID `.../7613467914`; C5 xóa dead code + CI `--fatal-warnings` + rule cấm ignore trần; H2 rewarded no-ad → dialog Retry; H5 share dialog xác nhận đích lưu; H6 test rollback restore.
- TODO còn mở: **bật GitHub Pages** trong repo settings (Settings → Pages → Source: GitHub Actions) để `privacy.html` deploy; **device test thật (plan5 §1.8 + plan6 Device QA Gate, danh sách chi tiết trong `checklist.md`)** — free-limit chặn trong app, `wcfg_*` sạch sau khi kéo widget, force-stop/reboot render đúng, Pro hết hạn tự khóa, 2 widget rotation độc lập, appWidgetId reuse, share sheet dialog, migration idempotent, TEST_ADS=false logcat đúng ad unit.