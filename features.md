# Features — Quote Widget ("Your Words")

> Tài liệu đầy đủ tính năng + UI của app, đối chiếu trực tiếp với source code.
> Cập nhật lần cuối: 2026-09-04 (HEAD `e1a39a7`, CI green debug + release).

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
| 12 | **Widget Setup** | `lib/screens/widget_setup_screen.dart` | Màn hình cấu hình widget: chọn collection → "Set Up Widget". Là **điểm chặn widget limit**: Free user thêm widget thứ 2 → dialog "Widget Limit Reached" (Cancel / Remove Ads Forever / Watch Ad — Unlock 24h) |
| 13 | **Collection Picker** (dialog) | `lib/screens/collection_picker_dialog.dart` | Khi share text và có >1 collection: chọn đích lưu, kèm tùy chọn "Create New Collection" |
| — | ~~Widget Config~~ | `lib/screens/widget_config_screen.dart` | **DEAD CODE** — không được import ở đâu (rule project: không thêm feature vào đây). `WidgetPreview` cũng chỉ dùng trong screen này |

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
| **Free + widget thứ 2** | Placeholder **"Upgrade to Pro / to add more widgets"** (nền xám) | Mở app (mua/khóa Pro) |

**Rotation khi tap:** `rotationMode` = `sequential` (next +1, wrap) hoặc `random` (không trùng item hiện tại) — logic trong Kotlin (`handleTap`) và `RotationService` (Dart).

**Progress indicator:** `showProgress` bật → text `x/y` (x = currentIndex+1) ở góc (small) hoặc dưới text (medium). Tắt khi không có nội dung / bị remove / chưa cấu hình.

**6 Curated Themes (Task 6):** ocean · sunset · forest · midnight · rose · sand — gradient drawable `widget_bg_<id>.xml` (có bo góc) gán qua `setBackgroundResource` lên `widget_root` + màu accent cho progress. Hợp đồng: `lib/models/widget_theme.dart` id ↔ drawable ↔ `themeDrawableFor()`/`themeAccentFor()` trong Kotlin. Light/Dark/Custom fallback về màu nền solid.

**Dữ liệu widget (CRITICAL — 2 file SharedPreferences):**
- **`HomeWidgetPreferences`** — widget data qua `HomeWidget.saveWidgetData()` (keys `widget_<id>_*`: text, theme, fontSize, currentIndex…). Kotlin đọc file này trước.
- **`FlutterSharedPreferences`** — supplementary: `is_pro`, `is_pro_expires_at`, `configured_widget_ids` (Kotlin ghi cả key thường + `flutter.` prefix). Không dùng default prefs (từng gây bug critical).

**Native lifecycle:** `onUpdate` (render + enforce limit), `onAppWidgetOptionsChanged` (re-render khi resize), `onDeleted` (dọn prefs 2 file + cập nhật `configured_widget_ids`), `onReceive` (xử lý tap). `WidgetReceiver` (BroadcastReceiver) chuyển tiếp tap.

---

## 4. Onboarding & Sample data

- **2 luồng bắt đầu:** "Start with Sample" (chọn use case → tạo sẵn) hoặc "Add Your Own" (Create Collection → Add Item → Add Widget Guide) hoặc "Skip".
- **5 use cases** (`SampleDataService`): Vocabulary · Motivation & Affirmation · Work & Focus · Gym & Workout · Personal Quotes. Mỗi bộ 7–8 item **tự viết** (không quote người nổi tiếng), tạo 1 collection.
- **Live preview:** sau khi tạo sample → màn hình preview hiển thị `QuoteCard` (kích thước medium) đúng appearance, tap để cycle + đếm `x/y`.

---

## 5. Settings (chi tiết)

1. **Pro status row** (động): `Free (1 Widget)` / `Pro unlocked — Xh left` (24h) / `Pro (Remove Ads Forever)` (vĩnh viễn). Tap khi free → xem rewarded ad unlock 24h.
2. **Remove Ads Forever** — IAP one-time `com.quotewidget.pro`, Pro vĩnh viễn.
3. **Recently Deleted** → màn hình trash.
4. **Backup & Restore** → export/import/snapshots.
5. **Restore Purchases** (yêu cầu store review) — restore qua `purchaseStream`.
6. **Privacy Policy** — mở `https://hoangsoft90.github.io/QuoteWidget/privacy.html` (url_launcher, external).
7. **About** — "Quote Widget – Your Words v1.0.0".

---

## 6. Monetization (Ads + IAP)

| Nguồn | Vị trí | Chi tiết |
|---|---|---|
| **Rewarded ad** (chính) | Settings Pro row · dialog widget-limit | Xem hết ad → **Pro 24h** (time-bound, tự khóa lại sau hết hạn, cả khi app đóng — Kotlin check `is_pro_expires_at`). Grant chỉ báo thành công **sau khi persist xong** (Fix A) |
| **IAP "Remove Ads Forever"** | Settings · dialog widget-limit | One-time purchase → `proUnlockedUntil = DateTime(9999)` |
| **Banner** | Home đáy (free tier) | Anchored adaptive banner, có bottom inset tránh 3-button nav; Pro → ẩn |
| **Interstitial** | Sau destructive actions | delete-forever (collection/item), overwrite import, restore snapshot — tần suất: **1 lần mỗi 5 action** + cooldown 5 phút, preload nền, fail im lặng |

**Config (`AdConfig`):**
- `ENABLE_ADS=true` (default) — tắt ads bằng `--dart-define=ENABLE_ADS=false`.
- `TEST_ADS=true` (default) — mọi unit ID resolve về sample ID của Google (không bị AdMob giới hạn khi test). Bật ads thật: `--dart-define=TEST_ADS=false`.
- App ID thật trong manifest (`ca-app-pub-6917313063209470~9587990603`), unit IDs real banner/interstitial trong code (rewarded real ID còn TODO — phải đăng ký trước khi tắt TEST_ADS).
- `nonPersonalizedExtras = {'npa': '1'}` — quảng cáo không cá nhân hóa.

**Widget limit (free = 1 widget):** enforce 2 tầng — `StorageService.createWidgetConfig` ném `WidgetLimitReachedException` (Flutter) + placeholder native "Upgrade to Pro" khi kéo widget thứ 2 (Kotlin `onUpdate`). Pro provider live (`setProStatusProvider`) → hết 24h là tự khóa lại ngay.

---

## 7. Share từ app khác (Task 2)

- `ShareReceiverActivity` nhận `ACTION_SEND text/plain` → ghi `flutter.pending_share_text` + `flutter.share_timestamp` vào **đúng file `FlutterSharedPreferences`** (key prefix `flutter.`) bằng `.commit()` đồng bộ → `finish()` **không mở app UI** (translucent theme, noHistory, excludeFromRecents → không flash).
- `main.dart` `_handlePendingShare()` khi mở app: 0 collection → toast nhắc tạo; **1 collection → auto-save + toast "Saved to <name>" + refresh widget**; nhiều collection → dialog picker (kèm tạo mới).
- Toast native (channel `quotewidget/toast` trong `MainActivity`) — hiển thị cả khi app UI không trên màn hình.

---

## 8. Backup & Safety (Task 3)

- **Export:** JSON `quotewidget-backup-<ts>.json` (format `quote-widget-backup`, schema v1) → share sheet.
- **Import:** picker `.json` (giới hạn 20MB), validate format/schema/fields/dupes/refs; 2 chế độ:
  - **Append** — thêm mới, bỏ qua ID trùng.
  - **Overwrite** — **tạo safety snapshot trước**, restore thay thế, rollback tự động nếu thất bại, trigger interstitial.
- **Safety Snapshots:** tạo trước destructive ops (delete collection, overwrite import) + restore từng snapshot, giữ tối đa 3, tự xóa cũ.

---

## 9. Deep link / cold start

- **Tap widget chưa cấu hình** (cold start): Kotlin ghi `tapped_widget_id`/`tapped_collection_id` → `main.dart` mở thẳng `WidgetSetupScreen` làm root. **Edge case đã fix:** nếu screen này là root route, `_save()` không pop (black screen) mà `pushReplacement` Home.
- **Warm start** (app đang chạy, tap widget): `MainActivity.onNewIntent` ghi prefs → `didChangeAppLifecycleState(resumed)` → `_checkPendingWidgetTap()` → push `WidgetSetupScreen`.
- No formal router — Navigator 1.0 imperative, không có điểm chết nav (đã rà soát: BackupScreen có entry từ Settings, mọi screen có đường về).

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

## 11. Test suite (75 tests)

- `flutter test` → **75/75 pass**; `flutter analyze` → 0 errors, 0 warnings.
- Phủ: storage (collections/items/widget-configs/trash/purge/limit), rotation service, IAP (time-bound Pro, permanent, Fix B widget-push), rewarded outcome gate (Fix A), interstitial frequency gate, backup import/export, curated themes consistency (id ↔ drawable ↔ native), widget limit, share, onboarding/sample data.
- Mô phỏng: Hive `init(testPath:)`, SharedPreferences `setMockInitialValues`, MethodChannel mock (`home_widget`, toast).

---

## 12. Non-goals / lưu ý

- **KHÔNG** thêm: photo background, custom fonts, iOS widget, cloud sync (feature freeze — plan3).
- **KHÔNG** tạo/đổi file SharedPreferences hay key Pro (rule critical).
- **Dead code:** `widget_config_screen.dart` (unreachable) — không thêm feature.
- TODO còn mở: đăng ký **rewarded ad unit ID thật** trong AdMob console trước khi tắt `TEST_ADS`; configure IAP product trong Play Console; device test thật (rewarded flow, background share, theme render).