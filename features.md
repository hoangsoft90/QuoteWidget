# Features — Quote Widget ("Your Words")

> Tài liệu đầy đủ tính năng + UI của app, đối chiếu trực tiếp với source code.
> **Canonical feature spec: `.plan/features_final.md`** (thắng nếu lệch — Phase 1 P0-1).
> Cập nhật lần cuối: **2026-09-06** (Feature Close Batch — analyze 0 issue, 155/155 tests pass; chưa commit).
> ⚠️ **FEATURE FREEZE 2026-09-06** — chỉ nhận bugfix + Device QA, không feature mới tới CLOSED_TESTING_OK (Deferred V1.1: `features_final.md` §8).

**App:** Hiển thị nội dung cá nhân (quote, từ vựng, lời nhắc…) trên Home Screen widget Android.
**Tech:** Flutter 3.47.1 / Dart 3.x · Hive (local DB) · home_widget + Kotlin RemoteViews · Android-only (minSdk 24, compileSdk/targetSdk 36) · Offline-first không INTERNET (cleartext HTTP cho document/ads platform).
**Device:** 1 thiết bị Android (thường Pixel/stock hoặc Samsung/Xiaomi). Không iOS target.
**Monetization V1:** Rewarded ad 24h mở thêm widget limit (không tắt banner/interstitial). Free = 1 widget. Pro 24h tự khóa lại sau hết hạn (kể cả app đóng). Banner luôn hiện kể cả Pro. Không IAP.

---

## 1. Danh sách màn hình (screens)

| # | Screen | File | Vai trò |
|---|---|---|---|
| 1 | **Onboarding** (Welcome) | `lib/screens/onboarding_screen.dart` | Màn hình đầu tiền khi chưa hoàn tất onboarding: logo, tagline, progress 3 bước, 3 lựa chọn (Start with Sample / Add Your Own / Skip) |
| 2 | **Use Case Selection** | `lib/screens/use_case_selection_screen.dart` | Chọn 1 trong 5 starter pack → tạo sample collection → **live widget preview** (tap để cycle item, hiện index/total) → Continue tới Add Widget Guide |
| 3 | **Onboarding Create Collection** | `lib/screens/onboarding_create_collection_screen.dart` | Bước 1 luồng "Add Your Own": nhập tên collection đầu tiền (hoặc Skip) |
| 4 | **Onboarding Add Item** | `lib/screens/onboarding_add_item_screen.dart` | Bước 2: thêm item đầu tiền (hoặc Skip) |
| 5 | **Add Widget Guide** | `lib/screens/add_widget_guide_screen.dart` | Hướng dẫn thêm widget theo OEM (Samsung/Xiaomi/Stock, nhận diện qua `android.os.Build.MANUFACTURER`), nút "Add Widget to Home Screen", "I've added the widget" / "Skip for now" |
| 6 | **Home** | `lib/screens/home_screen.dart` | Danh sách collection (card: avatar chữ cái đầu, tên, số item, menu ⋮ → Delete), FAB "+", **banner ad đáy màn hình**, Settings icon. **Khi 0 collection**: empty-state offer 5 starter packs / "Start empty" (Phase 2A) |
| 7 | **Collection Detail** | `lib/screens/collection_detail_screen.dart` | Danh sách items **drag reorder** (ReorderableListView), edit/delete (dialog — có ô **Author optional** B1), progress badge `x/y` trên AppBar (nếu có widget config), FAB add item, nút Bulk Add. **Search bar** (Phase 2A realtime in-memory): lọc All/Favorites khi dùng filter toggle. **Star toggle** từng item. **AppBar menu ⋮ (B2):** Export collection (.json) / Import items (confirm: New collection / Add here). **Item menu (B3):** Edit / **Share as image** / Delete |
| 8 | **Bulk Add** | `lib/screens/bulk_add_screen.dart` | Dán nhiều dòng, 1 dòng = 1 item, live preview đếm + danh sách, nút "Add All" (có confirm) |
| 9 | **Settings** | `lib/screens/settings_screen.dart` | Chi tiết §5 |
| 10 | **Recently Deleted** | `lib/screens/recently_deleted_screen.dart` | Trash: 2 section (Collections / Items), mỗi row Restore (xanh) + Delete Forever (đỏ, confirm), purge 30 ngày tự động |
| 11 | **Backup & Restore** | `lib/screens/backup_screen.dart` | Export (JSON + share sheet), Import (Append / Overwrite — chọn trước import), Safety Snapshots (list, restore, max 3). Callback Kotlin ← Flutter |
| 12 | **Widget Setup** | `lib/screens/widget_setup_screen.dart` | Cấu hình widget: chọn collection → "Set Up Widget". Điểm chặn widget limit: Free user thêm widget thứ 2 → paywall bottom sheet (Watch Ad — Unlock 24h / Cancel). **contentFilter** toggle (Phase 2A): All / Favorites-only |
| 13 | **Collection Picker** (dialog) | `lib/screens/collection_picker_dialog.dart` | Khi share text chọn "Đổi collection": chọn đích lưu, có tùy chọn "Create New Collection" |
| 14 | **Share as image** | `lib/screens/share_quote_card_screen.dart` | **B3**: preview card quote (text + author + app name) + nút share → PNG qua share_plus |
| — | ~~Widget Config~~ | ~~`lib/screens/widget_config_screen.dart`~~ | **ĐÃ XÓA** (plan6 C5, 2026-09-05) — dead code không import; kèm `widget_preview.dart` cũng không cònใคร dùng |

---

## 2. Tính năng core (content management)

- **Collections:** tạo (Home FAB / onboarding / share picker), đổi tên (`StorageService.updateCollection`), xóa soft-delete → trash.
- **Items:** thêm (dialog 1 item), hàng loạt (Bulk Add), sửa, xóa soft-delete, **sắp xếp kéo-thả** (lưu `order`).
- **Trash / Recently Deleted:** `isDeleted` + `deletedAt` trên `Collection` và `Item`. Restore nguyên cụm (collection + items) hoặc từng item. Purge tự động sau 30 ngày — chạy startup (`main.dart`) và mỗi khi mở màn hình Recently Deleted.
- **Favorites (Phase 2A):** `Item.favorite: bool` (Hive, default false → không cần migration schema). Star toggle trong Collection Detail, All/Favorites filter cho danh sách items. Widget có tùy chọn `contentFilter` (all / favoritesOnly).
- **Search (Phase 2A):** thanh tìm kiếm trong Collection Detail (realtime in-memory, filter theo text + status, kết hợp All/Favorites filter).
- **Duplicate Collection (Phase 2A):** `StorageService.duplicateCollection` batch putAll (một tap → copy toàn bộ items sang collection mới). Menu item trong collection list.
- **Templates / Empty-state (Phase 2A):** khi Home 0 collection, offer 5 starter packs (reuse SampleDataService) hoặc "Start empty" (FAB tạo collection thuần). Hoạt động trên empty Home.
- **Author (B1):** `Item.author: String?` (Hive field 9, backward-compat — missing → null). Nhập optional trong Add/Edit dialog. Widget hiển thị 1 dòng nhỏ `— author` phía dưới text (single style, `widget_author` trong cả 3 layouts), ẩn khi rỗng/removed/empty. Key native: `widget_<id>_author` (theo item đang hiển thị, không stale sau native tap).
- **Export/Import 1 collection (B2):** `BackupService.exportCollection`/`importCollection`/`previewCollectionImport` (schema `quote-widget-collection` v1, có author, KHÔNG WidgetConfig). Export → share sheet; Import → FilePicker + dialog confirm (New collection — name "(imported)" / Add here — append items, order tiếp tục).
- **Share quote as image (B3):** `renderQuoteCardPng` (pure Canvas: text wrap + author + app name, 320×220) → PNG file → share_plus. Entry: item menu trong Collection Detail.
- **UMP consent (A2):** `UmpConsentService` — requestConsentInfoUpdate → form nếu cần → `canRequestAds` gate mọi ad path; Privacy Options entry trong Settings chỉ khi Google yêu cầu; suppressed trong onboarding, re-resolve ở HomeScreen.
- **About version (B5):** Settings About hiển thị version động từ `PackageInfo` (`package_info_plus`).
- **Dữ liệu lưu local:** Hive 3 boxes: `collections`, `items`, `widget_configs`. Hoàn toàn offline-first.

---

## 3. Widget Home Screen (native Android)

**Kích thước:** small (2×1, 110dp) / medium (medium layout 4 dòng) / **wide (4×2 — Phase 2B)** — `resizeMode="none"` + resize enabled trong provider XML (Phase 2B). Layout XML: `widget_small.xml`, `widget_medium.xml`, `widget_wide.xml`, `widget_loading.xml`, `widget_small_preview.xml`.

**Các trạng thái render** (`QuoteWidgetProvider.kt` `updateAppWidget`):

| Trạng thái | Hiển thị | Tap → |
|---|---|---|
| Chưa cấu hình (`collectionId` rỗng) | "Tap to set up this widget" (xám) | Mở app → `WidgetSetupScreen` (ghi `tapped_widget_id`) |
| Collection đã bị xóa | "Collection removed. Tap to choose another." | Mở app để chọn lại |
| Collection rỗng | "Add some content to this collection." | Mở `CollectionDetailScreen` (kèm `tapped_collection_id`) |
| Có nội dung | Text item + progress `x/y` (nếu bật) | **Cycle item tiếp theo** (broadcast `com.quotewidget.WIDGET_TAP`) |
| **Free + widget thứ 2** (chưa cấu hình) | Placeholder **"Upgrade to Pro / to add more widgets"** (nền xám) | Mở app → paywall sheet (`route=paywall`, A-5) |
| **Pro 24h hết hạn + widget thứ 2** (đã cấu hình) | **"24h Pass Expired — Tap to renew"** (nền xám, plan5 §1.6) | Mở app → paywall sheet gia hạn |

**Graceful Pro-expiry (§1.6):** khi pass 24h hết hạn, widget thứ 2 KHÔNG biến mất/giữ content cũ vô thời hạn — `isExpiredLocked()` (widget cấu hình vượt free-limit 1, không phải widget cũ nhất) → render prompt gia hạn; widget cũ nhất (free slot) vẫn chạy bình thường. Check nằm trong `updateAppWidget()` nên **mọi** render path tôn trọng lock; tap content cũ sau expiry tự chuyển sang prompt. Vì `updatePeriodMillis=0` (không có system refresh), `WidgetService.syncProStatus` (chạy lúc startup) push `HomeWidget.updateWidget` sau khi ghi `is_pro` → lock tự áp dụng ngay lần mở app kế tiếp, không cần chờ tap/reboot. **Forensic fix (2026-09-05):** `syncWidgetData` không write `config.currentIndex` (Hive luôn 0) khi sync — đọc native `widget_<id>_currentIndex` từ prefs và giữ lại khi đọc được, tránh reset tiến trình tap sau khi edit item.

**Rotation khi tap:** `rotationMode` = `sequential` (next +1, wrap) hoặc `random` (không trùng item hiện tại) hoặc **shuffle bag (Phase 2B)** — logic dalam Kotlin (`handleTap`) và `RotationService` (Dart). Freeze bag persists per physical widget in SharedPreferences (Phase 2B spec §2).

**Shuffle Bag (Phase 2B):**
- Tạo bag = list item IDs nguồn hiện tại, xáo trộn 1 lần, `shuffleIndex = 0`.
- Mỗi next: hiện `bag[shuffleIndex]`, `shuffleIndex++`.
- Khi `shuffleIndex >= bag.length`: tạo bag mới, xáo lại, prefer không bắt đầu bằng item vừa hiện (nếu length > 1), `shuffleIndex = 0`.
- Persist per widget (`widget_<id>_shuffle_bag` JSON ids, `widget_<id>_shuffle_index`, `widget_<id>_shuffle_source_fp` fingerprint nguồn).
- Invalidate khi nguồn thay đổi (thêm/xóa item, đổi Favorites-only): fingerprint rebuild → stale index avoid out-of-range.

**Daily rotation (Phase 2B spec §3):**
- Mỗi ngày lịch (local timezone) gắn **1 item chủ đạo** cho widget.
- Fields per widget: `widget_<id>_schedule`, `widget_<id>_daily_date` (`yyyy-MM-dd`), `widget_<id>_daily_item_id`, `widget_<id>_daily_index`, `widget_<id>_current_index`, `widget_<id>_next_rotation_at` (epoch millis).
- Rules: lần đầu / không daily_date → chọn item sequential (hoặc shuffle nếu kết hợp), gán `daily_date = today`, `daily_item_id = that item`. Cùng ngày → render mặc định = `daily_item_id`, user tap có thể cycle tạm trong ngày, khi refresh/sau 0h local snap về daily item. Đổi ngày → advance pointer, gán item mới, `daily_date = today`.

**Auto-rotate (Phase 2B):** hỗ trợ 1h/3h/6h/Daily (không 15 phút V1). Bộ đếm `next_rotation_at`; worker/alar chỉ chạy khi `now >= next_rotation_at` → next item → set `next_rotation_at`. UI disclaimer: "Auto-rotate may be delayed on some devices to save battery." **Test Spike bắt buộc trên Xiaomi/Samsung trước khi ship Auto-rotate.**

**Tap action (Phase 2B):** `TapAction` enum: next / open_collection / open_app / copy. Dispatch từ Kotlin `handleTap` (copy → clip board + toast native). Dart `RotationService` mirror logic khi sync.

**Progress indicator:** `showProgress` bật → text `x/y` (x = currentIndex+1) ở góc (small) hoặc dưới text (medium). Turn off khi không có nội dung / bị remove / chưa cấu hình.

**6 Curated Themes (Task 6):** ocean · sunset · forest · midnight · rose · sand — gradient drawable `widget_bg_<id>.xml` (có bo góc) gán qua `setBackgroundResource` lên `widget_root` + màu accent cho progress. Hợp đồng: `lib/models/widget_theme.dart` id ↔ drawable ↔ `themeDrawableFor()`/`themeAccentFor()` trong Kotlin. Light/Dark/Custom fallback về màu nền solid.

**Dữ liệu widget (CRITICAL — 2 file SharedPreferences):**
- **`HomeWidgetPreferences`** — widget data qua `HomeWidget.saveWidgetData()` (keys `widget_<id>_*`: text, theme, fontSize, currentIndex, items, contentFilter, schedule, tapAction, shuffle_*, daily_*, next_rotation_at). Kotlin đọc file này trước.
- **`FlutterSharedPreferences`** — supplementary: `is_pro`, `is_pro_expires_at`, `configured_widget_ids`, `last_share_collection_id` (Kotlin ghi cả key thường + `flutter.` prefix). Không dùng default prefs (từng gây bug critical).

**Native lifecycle:** `onUpdate` (render + enforce limit + `migratePreferencesIfNeeded` — **A3**: nếu widget render không có collectionId → `unsaveConfiguredWidgetId` gỡ khỏi registry), `onAppWidgetOptionsChanged` (re-render khi resize — Phase 2B size branch), `onDeleted` (dọn prefs 2 file + `wcfg_*` mapping cả 2 chiều + **full key cleanup Phase 2B**), **`onRestored` (A7, Feature Close 2026-09-06)** — sau backup restore: xóa mapping cũ `wcfg_<oldId>_*`, strip display data `widget_<newId>_*`, registry rỗng, render "Tap to set up", `onReceive` (xử lý tap — broadcast `com.quotewidget.WIDGET_TAP` hoặc open app). `WidgetReceiver` (BroadcastReceiver) chuyển tiếp tap.

**Registry consistency (Sprint A, plan4 + Phase 1 P0-2 + Phase 3 forensic + A3/A6/A7 Feature Close):** free-limit gate đọc NATIVE `configured_widget_ids` qua MethodChannel (không tin Hive box). `reconcileWidgetConfigs()` chạy **full 2-way scan mỗi lần** native ids có sẵn (bỏ early-return fast path — Phase 1 fix). **Phase 3 forensic fix:** `onDeleted` Kotlin dọn đủ keys (`_items`, `_contentFilter`, `_schedule`, `_tapAction`, `_shuffle_bag`, `_shuffle_index`, `_shuffle_source_fp`, `_daily_date`, `_daily_index`, `_next_rotation_at`) — trước đó chỉ xóa `_items`/`_contentFilter`. **A3 (2026-09-06):** xóa collection → `unbindWidgetConfig` (Hive + wcfg_* + `configured_widget_ids` cả 2 prefix + clear display data) + Kotlin `unsaveConfiguredWidgetId` khi render unconfigured — fix kẹt Free-limit. **A6:** `reconcileAfterRestore` detach widget orphan ngay sau restore (không chờ resume).

**Startup orphan-mapping cleanup (plan6 C1 + Phase 1 P0-2):** `main.dart` sau init đọc `configured_widget_ids` → với mỗi native id, resolve `wcfg_<id>_configId` qua `WidgetDataBridge.getConfigIdForWidget()` → nếu mapping tồn tại NHƯNG config không còn trong Hive (collection đã xóa) → gọi `removeWidgetMapping()` dọn mapping cũ (2 chiều). Widget chưa có mapping = "Tap to set up" — không đụng tới.

**Phase 2B remember last collection for share:** `main.dart` `_handlePendingShare` dùng `last_share_collection_id` (FlutterSharedPreferences) làm default picker; xác nhận lưu → set lại key. Default picker khi có nhiều collection → chọn gần nhất, có nút "Change collection" → picker.

---

## 4. Onboarding & Sample data

- **2 luồng bắt đầu:** "Start with Sample" (chọn use case → tạo sẵn) hoặc "Add Your Own" (Create Collection → Add Item → Add Widget Guide) hoặc "Skip".
- **5 use cases** (`SampleDataService`): Vocabulary · Motivation & Affirmation · Work & Focus · Gym & Workout · Personal Quotes. Mỗi bộ 7–8 item tự viết (không quote người nổi tiếng), tạo 1 collection.
- **Live preview:** sau khi tạo sample → màn hình preview hiển thị `QuoteCard` (kích thước medium) đúng appearance, tap để cycle + đếm `x/y`.

---

## 5. Settings (chi tiết)

1. **Pro status row** (động): `Free (1 Widget)` / `Pro unlocked — Xh left` (24h) / `Pro (Lifetime)` (legacy purchasers). Tap khi free → xem rewarded ad unlock 24h.
2. **Recently Deleted** → màn hình trash.
3. **Backup & Restore** → export/import/snapshots.
4. **Privacy Policy** — mở `https://hoangsoft90.github.io/QuoteWidget/privacy.html` (url_launcher, external). File `docs/privacy.html` + workflow `pages.yml` deploy trên GitHub Pages (chưa verify URL live).
5. **About** — "Quote Widget – Your Words v<version>" — version đọc live từ `PackageInfo` (package_info_plus; Feature Close B5).
6. **Privacy Options** (UMP A2) — chỉ hiện khi Google yêu cầu entry point cho user/region đó; mở form consent để user xem/thay đổi.
7. **Export/Import 1 collection** (B2) — từ AppBar menu của Collection Detail: xuất 1 collection + items ra `.json` (share sheet), import file `.json` với confirm (New collection / Add here).
8. **Share quote as image** (B3) — menu từng item → card PNG (text + author + app name) qua share_plus.

> **2026-09-04:** Toàn bộ tính năng purchase đã gỡ (Remove Ads Forever + Restore Purchases + dependency `in_app_purchase`). Monetization chỉ còn rewarded-ad 24h. Pro **không** ẩn ads nữa.

---

## 6. Monetization (Ads + IAP)

| Nguồn | Vị trí | Chi tiết |
|---|---|---|
| **Rewarded ad** (duy nhất) | Settings Pro row · paywall sheet (widget-limit + deep-link) | Xem hết ad → **Pro 24h** (time-bound, tự khóa lại sau hết hạn, kể cả app đóng — Kotlin check `is_pro_expires_at`). Grant chỉ báo thành công **sau khi persist xong** (plan3 Fix A) |
| **Banner** | Home đáy (`bottomNavigationBar`) | Anchored adaptive banner + bottom inset tránh 3-button nav; **luôn hiển thị kể cả Pro** (2026-09-04 — Pro không ẩn ads); Scaffold tự nâng FAB [+] lên khỏi ad (không đè) |
| **Interstitial** | Sau destructive actions | delete-forever (collection/item), overwrite import, restore snapshot — tần suất: **1 lần mỗi 5 action** + cooldown 5 phút, preload nền, fail im lặng. Không gate theo Pro |

**Config (`AdConfig`):**
- `ENABLE_ADS=true` (default) — tắt ads bằng `--dart-define=ENABLE_ADS=false`.
- `TEST_ADS=true` (default) — mọi unit ID resolve về sample ID của Google (không bị AdMob giới hạn khi test). Bật ads thật: `--dart-define=TEST_ADS=false`.
- App ID thật trong manifest (`ca-app-pub-6917313063209470~9587990603`); **cả 3 unit ID real** trong code — rewarded `ca-app-pub-6917313063209470/7613467914` đã đăng ký & thay thế (plan6 C4, 2026-09-05), khác sample ID `_testRewarded`.
- `nonPersonalizedExtras = {'npa': '1'}` — quảng cáo không cá nhân hóa.

**Widget limit (free = 1 widget):** enforce 2 tầng — `StorageService.createWidgetConfig` ném `WidgetLimitReachedException` (Flutter) + placeholder native "Upgrade to Pro" khi kéo widget thứ 2 (Kotlin `onUpdate`). Pro provider live (`setProStatusProvider`) → hết 24h là tự khóa lại ngay. **Phase 3 forensic fix:** `syncWidgetData` không ghi `config.currentIndex` (Hive luôn 0) khi sync — đọc native `widget_<id>_currentIndex` từ prefs và giữ lại khi đọc được, tránh reset tiến trình tap sau khi edit item.

> **Chiến lược chính thức (2026-09-05, plan6 H1 — KHÔNG đảo ngược):** rewarded-ad 24h **chỉ mở thêm widget limit**, KHÔNG tắt banner/interstitial. IAP đã gỡ là chủ đích (2026-09-03, giữ nguyên) — không phải "phần còn sót cần dọn". Banner luôn hiện kể cả Pro.

---

## 7. Share từ app khác (Task 2)

- `ShareReceiverActivity` nhận `ACTION_SEND text/plain` → ghi `flutter.pending_share_text` + `flutter.share_timestamp` vào **đúng file `FlutterSharedPreferences`** (key prefix `flutter.`) bằng `.commit()` đồng bộ → `finish()` **không mở app UI** (translucent theme, noHistory, excludeFromRecents → không flash). Kotlin KHÔNG ghi Hive — chỉ prefs (plan6 H5 verify).
- `main.dart` `_handlePendingShare()` khi mở app (plan6 H5): 0 collection → toast nhắc tạo; có collection → **dialog xác nhận** `lib/widgets/share_target_dialog.dart`: "Lưu vào [collection mặc định/gần nhất]" / "Đổi collection" (mở picker) / "Huỷ" — **KHÔNG auto-save, không timer 5s**. Sau khi xác nhận lưu → refresh widget + SnackBar "Saved to <name>" có nút Undo (10s, §1.7).
- **Quick Share Undo (§1.7):** `ShareService.saveToCollection` trả đúng `Item` vừa tạo (Undo target chính xác, không đoán). Tap **Undo** trong ~10s → soft-delete item đó (về Trash — recoverable) + refresh widget collection → xác nhận "Share removed". UI nằm trong `lib/widgets/share_undo_snackbar.dart` (helper testable). SnackBar tự hết hạn — không Undo sau cửa sổ.
- **Phase 2B remember last collection:** `last_share_collection_id` (FlutterSharedPreferences) — default picker khi share, xác nhận lưu → set lại.
- Toast native (channel `quotewidget/toast` trong `MainActivity`) chỉ còn cho các path không có gì để undo (fail / chưa có collection).

---

## 8. Backup & Safety (Task 3)

- **Export:** JSON `quotewidget-backup-<ts>.json` (format `quote-widget-backup`, schema v1) → share sheet. **Chỉ chứa Collections + Items — KHÔNG export WidgetConfig active** (field `widgetConfigs: []` — Phase 1 P0-3).
- **Import:** picker `.json` (giới hạn 20MB), validate format/schema/fields/dupes/refs; **mọi `widgetConfigs` trong file bị bỏ qua — không bao giờ tạo phantom Hive config** (P0-3); 2 chế độ:
  - **Append** — thêm mới, bỏ qua ID trùng.
  - **Overwrite** — **tạo safety snapshot trước**, restore thay thế, rollback tự động nếu thất bại, trigger interstitial.
- **Safety Snapshots:** tạo trước destructive ops (delete collection, overwrite import) + restore từng snapshot, giữ tối đa 3, tự xóa cũ.
- **Phase 3 forensics on restore:** restore không tạo phantom WidgetConfig, không kẹt free-limit oan (P0-3 + Phase 1). UI message rõ: "Backup restores your collections and items. Home Screen widgets need to be set up again."

---

## 9. Deep link / cold start

- **Tap widget chưa cấu hình** (cold start): Kotlin ghi `tapped_widget_id`/`tapped_collection_id` → `main.dart` mở thẳng `WidgetSetupScreen` làm root. **Edge case đã fix:** nếu screen này là root route, `_save()` không pop (black screen) mà `pushReplacement` Home.
- **Tap "Upgrade to Pro" / "24h Pass Expired" trên widget** → launch intent kèm `route=paywall` → MainActivity persist `pending_route` (cả 2 file prefs) → Flutter đọc lúc cold-start (`showPaywallOnStart`) hoặc warm-start (`_checkPendingPaywallRoute` trên resume) → mở thẳng paywall bottom sheet (`lib/widgets/paywall_sheet.dart`, Watch Ad 24h / Cancel).
- **Warm start** (app đang chạy, tap widget cấu hình): `MainActivity.onNewIntent` ghi prefs → `didChangeAppLifecycleState(resumed)` → `_checkPendingWidgetTap()` → push `WidgetSetupScreen`.
- **Kèm reconciliation trên resume** (`didChangeAppLifecycleState`): widget có thể bị thêm/gỡ trên Home Screen lúc app ở nền → `reconcileWidgetConfigs()` chạy lại.
- No formal router — Navigator 1.0 imperative; mọi `showDialog`/`SnackBar` từ app-level dùng `navigatorKey` context (context trên MaterialApp không có Navigator — từng là latent crash ở share multi-collection, đã fix).
- **Phase 2B tap action:** `TapAction.next` (mặc định — cycle item), `open_collection` (mở collection detail), `open_app` (mở app home), `copy` (copy text → clipboard + toast native).

---

## 10. Hạ tầng / Release

- **Sentry:** `sentry_flutter ^9.28.0` (DSN trong code + manifest `io.sentry.dsn` cho native crash), `tracesSampleRate = 0.0`.
- **targetSdk/compileSdk 36** (yêu cầu Google Play 31/8/2026) · AGP 8.11.1 · Gradle 8.14.3 · Kotlin 2.2.20 · Java 17.
- **Cleartext HTTP:** `network_security_config.xml` (base-config cleartextTrafficPermitted=true) + manifest attribute — http hoạt động trong release APK.
- **App icon:** adaptive (gradient + `format_quote` vector) + legacy PNG đủ mipmap.
- **CI (GH Actions):** Flutter 3.47.1 → `flutter analyze --fatal-warnings` → `flutter test` → **build debug APK + release APK** (2 artifacts). Workflow `build-debug-apk.yml` có `workflow_dispatch` input `test_ads` (default true) để QA candidate production ads build (`--dart-define=TEST_ADS=${{ inputs.test_ads || 'true' }}`); push build giữ test ads.
- **Theme app:** Material 3, seed `#6750A4`, light + dark.
- **Điện thoại duy nhất:** Android-only (iOS scaffold có sẵn nhưng chưa setup ads/không trong scope).
- **Forensic fixes (Phase 3, 2026-09-05):** 2 fix code + 1 fix CI — native-index preservation, shuffle-bag seed displayIndex, dead-key cleanup onDeleted, Kotlin compile error (shuffled() read-only List → MutableList), widget provider XML comment-location parse error.

---

## 11. Test suite

- `flutter test` → **138/138 All tests passed**; `flutter analyze` → 0 errors, 0 warnings (`--fatal-warnings` chạy trên CI — plan6 C5 + Phase 3 check).
- Phủ: storage (collections/items/widget-configs/trash/purge/limit + A1 native-count gate + A2 reconciliation + C1 orphan-mapping cleanup + Phase 2A favorites/search/duplicate/templates + Phase 2B contentFilter/rotation fields/schedule/tapAction + Phase 3 re-sync-keeps-native-index test), rotation service (Phase 2B shuffle bag/daily new tests), IAP (time-bound Pro, permanent, Fix B widget-push), rewarded outcome gate (Fix A) + H2 no-ad → unavailable enum, interstitial frequency gate, backup import/export + phantom-restore (Phase 1) test, curated themes consistency, widget limit, share service (§1.7 Undo target), share-undo SnackBar UI (3 widget tests §1.7), share-target dialog UI (5 widget tests plan6 H5), restore rollback (2 integration tests plan6 H6 — snapshot trước clearAll, rollback về đúng trạng thái cũ), syncProStatus startup-push (§1.6), paywall sheet, onboarding/sample data, **Phase 1 reconcile tests (2 direction + 1 phantom-restore)**, **Phase 2A storage contentFilter JSON round-trip + WidgetService pool test**, **Phase 2B rotation_service shuffle/daily tests**, **Phase 2B widget_service schedule/tapAction keys + storage fields round-trip**, **Phase 3 forensic re-sync test**.

- Mô phỏng: Hive `init(testPath:)`, SharedPreferences `setMockInitialValues`, MethodChannel mock (`home_widget`, toast), `PathProviderPlatform` fake (H6), `RotationService` pure Dart (dễ test).

---

## 12. Non-goals / lưu ý

- **KHÔNG** thêm: photo background, custom fonts, iOS widget, cloud sync (feature freeze — plan3).
- **KHÔNG** tạo/đổi file SharedPreferences hay key Pro (rule critical).
- **Dead code:** `widget_config_screen.dart` + `widget_preview.dart` **đã xóa** (plan6 C5) — không còn nữa.
- **2026-09-04:** `in_app_purchase` đã gỡ khỏi pubspec (IAP removed) — chỉ còn rewarded-ad 24h. `proUnlockedUntil = DateTime(9999)` chỉ còn từ legacy migration (`iap_pro_purchased`). **Giữ nguyên là chủ đích** (plan6 H1 xác nhận lại).
- **2026-09-04 (plan5 Sprint 0):** §1.6 Graceful Pro-expiry + startup re-render push; §1.7 Quick Share Undo + fix latent crash share multi-collection. Sprint 1/2/3 chưa mở — gate cứng: pass device test §1.8 trước.
- **Phase 1 P0-1 (2026-09-05):** legacy `source/` tree deleted — canonical = root. README/AGENTS ghi canonical-source note.
- **Phase 1 P0-5 (2026-09-05):** release runbook ghi `--dart-define=TEST_ADS=false` vào operating_rules.md.
- **Phase 4 (2026-09-05):** openspec change `device-qa-gate`, CI dispatch input `test_ads`, QA candidate build 33972687792 (success, TEST_ADS=false, 30.6 MB), run sheet `.plan/device_qa_run_sheet.md`.

---

## 13. Deferred (ghi rõ — không claim ảo)

**⚠️ FEATURE FREEZE (2026-09-06):** từ giờ chỉ nhận bugfix + Device QA, không nhận feature mới cho tới khi có verdict CLOSED_TESTING_OK.

Dưới đây là tính năng/future plan đã **không làm trong V1** — ghi vào `features_final.md` §8 với 🚫 để không nhầm là đã ship:

- **Export collection CSV** — JSON đã SHIP (Feature Close B2); CSV deferred V1.1
- **App shortcuts** — 🚫 Deferred V1.1
- **Material You** — 🚫 Deferred V1.1
- **TXT/clipboard import entry** — 🚫 Deferred V1.1
- **Tags / Time-of-day multi-collection / Multi-source union / History-Skip-Statistics / Widget prev-fav-next buttons / Preset marketplace / Notification reminders** — 🚫 Deferred V1.1 (list đầy đủ: features_final.md §8)

---

## 14. Tổng kết sessions gần nhất (tóm tắt cho reference)

- **Phase 1 (correctness, 2026-09-05):** reconcile full 2-way scan (bỏ fast-path), backup no-phantom (export empty configs, drop configs on import), dead code removed (processShareText, ShareResult, bridge comment), release runbook in operating_rules. Tests: +3 (2 reconcile, 1 phantom-restore), -1 (dead test). Tổng: 138 test.
- **Phase 2A (2026-09-05):** Favorites, favorites-only widget (contentFilter + JSON pool + Kotlin pick-by-index → fix tap-to-cycle text bug), Search Collection Detail, Duplicate Collection, Templates/Empty-state.
- **Phase 2B (2026-09-05):** Shuffle Bag (persist + fingerprint), Daily rotation (local calendar + snap), Auto-rotate (1h/3h/6h + daily snap), Tap action (next/open_collection/open_app/copy), Responsive 4×2 (widget_wide.xml + resize), Remember last collection for share.
- **Phase 3 (forensic review, 2026-09-05):** 2 fix code (native-index preservation, shuffle-bag seed displayIndex, dead-key cleanup onDeleted) + 1 fix CI (Kotlin compile error shuffled() read-only List → MutableList; widget provider XML comment-location parse error). Re-sync-keeps-native-index test thêm vào widget_service_test.
- **Phase 4 (prep, 2026-09-05):** openspec `device-qa-gate`, CI dispatch input `test_ads`, QA candidate build 33972687792 success (TEST_ADS=false, 30.6 MB release APK), run sheet `.plan/device_qa_run_sheet.md` (chưa commit — local only). Verdict BLOCKED — chờ human tester Wave 1 (A1–A5).
- **Feature Close Batch (2026-09-06):** Block A fixes (A1 privacy.html, A2 UMP consent + Privacy Options, A3 delete→free-limit unstick, A4 sizeCategory native-truth, A5 reorder sync, A6 restore reconcile, A7 onRestored, A8 dead-code/cleartext verdict) + Block B features (B1 Author widget line, B2 collection export/import, B3 share quote as image, B4 verified setup UI, B5 About version) + Block C docs sync. Tests 138 → 155. `flutter analyze` 0 issues. **FEATURE FREEZE** — chi tiết: `.plan/progress_feature_close.md`.

---
## END
