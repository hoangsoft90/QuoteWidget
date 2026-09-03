# Kết quả thực thi prompt_sprint_next.md (P0 → P0.5 → P1)

Quy tắc kiểm chứng: mỗi task chỉ coi là xong khi có (a) dòng code trỏ tới được
và (b) kết quả test/analyze thật chạy trên máy. Không báo cáo suông.

- Flutter local: 3.47.1 / Dart 3.13.1 (CI workflow dùng 3.32.4 — đều thoả `sdk: ^3.8.0`)
- **`flutter analyze`: 0 error, 0 warning**
- **`flutter test`: 65/65 PASS** (baseline 44 + 21 test mới)
- Commit đã push lên `main`, CI build đang chạy: run 33708833890

---

## Task 1 (P0) — Pivot monetization → rewarded-ad unlock 24h ✅

### 1.1 pubspec.yaml
```
google_mobile_ads: ^5.3.1
```

### 1.2 IapService time-bound (lib/services/iap_service.dart)
- Dòng 31: `DateTime? proUnlockedUntil;`
- Dòng 34-35: `bool get isPro => proUnlockedUntil != null && DateTime.now().isBefore(proUnlockedUntil!);`
- Dòng 113-115: `Future<void> unlockProFor24h() async { proUnlockedUntil = DateTime.now().add(const Duration(hours: 24)); await _persist(); }`
- Dòng 64: mua vĩnh viễn → `proUnlockedUntil = DateTime(9999);`
- `_persist()` ghi `iap_pro_purchased` (bool) + `iap_pro_expires_at` (int millis) vào
  SharedPreferences VÀ `HomeWidget.saveWidgetData('is_pro'/'is_pro_expires_at', ...)`
  → Kotlin tự khoá khi hết 24h kể cả app đang tắt.
- Legacy migration (dòng 60-64): nếu có `iap_pro_purchased=true` cũ → `DateTime(9999)`.

### 1.3 RewardedAdService (lib/services/rewarded_ad_service.dart — tạo mới)
- `loadRewardedAd()`: load 1 ad lúc app mở (main.dart gọi sau `initMobileAds()`).
- `showRewardedAd()`: trả `true` nếu `onUserEarnedReward` chạy → gọi
  `iapService.unlockProFor24h()` (dòng ~130). Test ad unit id dùng để dev.

### 1.4 StorageService widget-limit theo isPro mới (lib/services/storage_service.dart)
- Dòng 16/29-30/41: `_isProProvider`, `setProStatusProvider(() => ...)` được đánh giá
  LIVE mỗi lần check — hết 24h là tự khoá lại, không cần restart.
- Dòng 323: `if (!_isProActive && _widgetConfigsBox.isNotEmpty) throw WidgetLimitReachedException();`
- main.dart: `storageService.setProStatusProvider(() => iapService.isPro);`

### 1.5 Kotlin self-lock (QuoteWidgetProvider.kt)
- Dòng 17: `KEY_IS_PRO_EXPIRES_AT = "is_pro_expires_at"`
- Dòng 317-326: `isProActive()` = `is_pro==true && (expiry<=0 || now<expiry)` → gọi trong `onUpdate`.
- Dòng 421-430: helper `getLong()` đọc từ cả HomeWidgetPreferences lẫn FlutterSharedPreferences.

### 1.6 UI nút xem ads ở đúng điểm chặn (lib/screens/widget_setup_screen.dart)
- `_save()`/`_saveAndNavigateToDetail()` bắt `WidgetLimitReachedException`
  → `_showUnlockDialog()`: nút **"Watch Ad — Unlock 24h"** + **"Remove Ads Forever"** (mua IAP).
- Sau reward thành công → retry `_save()` tạo widget thứ 2 ngay.
- AndroidManifest: thêm INTERNET + ACCESS_NETWORK_STATE + AdMob App ID (test id) —
  bắt buộc với google_mobile_ads, nếu thiếu SDK crash ngay lúc init.

### 1.7 Bằng chứng test (test/iap_service_test.dart — 6 test; test/storage_service_test.dart — 2 test mới)
```
IapService time-bound tests:  6/6 PASS
  - new IapService is NOT Pro by default
  - unlockProFor24h sets proUnlockedUntil ≈ now+24h and isPro true
  - isPro false after window expires (auto re-lock) + hoursRemaining
  - persists expiry to SharedPreferences (iap_pro_expires_at)
  - relocks on init after expiry has passed
  - permanent DateTime(9999) → always Pro

StorageService widget limit (live provider):
  - Free 2nd widget blocked, unblocked while 24h Pro active  PASS
  - widget limit auto-relocks when the 24h window expires    PASS
```

---

## Task 2 (P0) — Share không còn mở app ✅ (+ fix 1 bug file-mismatch)

Vấn đề được xác nhận bằng đọc code: `ShareReceiverActivity` cũ gọi
`startActivity(mainIntent)` → mở cả Flutter UI. Ngoài ra còn 1 bug chưa từng được
bắt: Kotlin ghi vào file `share_prefs` key trần, còn Flutter đọc file
`FlutterSharedPreferences` key có prefix `flutter.` → text share KHÔNG BAO GIỜ tới
được Flutter.

### Sửa (android/.../ShareReceiverActivity.kt)
- Dòng 26-27: xoá hẳn `startActivity` — chỉ `finish()` sau khi lưu.
- Dòng 41-44: ghi vào **đúng** file Flutter đọc: `FlutterSharedPreferences` +
  key `flutter.pending_share_text` / `flutter.share_timestamp` (dùng `.commit()` đồng bộ).
- Manifest (AndroidManifest.xml dòng 37-42): theme
  `@android:style/Theme.Translucent.NoTitleBar` + `noHistory` + `excludeFromRecents`
  → không flash trắng.
- Toast xác nhận hệ thống: MainActivity.kt đăng ký MethodChannel `quotewidget/toast`;
  Flutter `ToastService.show(...)` (lib/services/toast_service.dart) thay SnackBar.
- main.dart `_handlePendingShare()`: 1 collection → lưu thẳng + Toast "Saved to …" +
  `updateWidgetsForCollection`; nhiều collection → vẫn hỏi picker (exception hợp lý).

Acceptance: share → không thấy màn hình app (activity translucent, finish ngay);
thông báo xác nhận bằng native Toast; mở app sau đó item đã nằm đúng collection.

---

## Task 3 (P0) — Privacy Policy URL thật ✅

- `privacy.html` (root, đã push lên repo) — viết lại nội dung thật: offline-first,
  dữ liệu chỉ lưu local (Hive), **có** mục Google Mobile Ads + advertising ID,
  opt-out bằng "Remove Ads Forever".
- lib/screens/settings_screen.dart:91-94 — URL mới
  `https://hoangsoft90.github.io/QuoteWidget/privacy.html`, TODO comment đã xoá.
- Lưu ý: cần bật GitHub Pages (Settings → Pages → branch main, /root) trên repo
  `hoangsoft90/QuoteWidget` để URL hoạt động; file đã sẵn ở root repo.

---

## Task 4 (P0) — Settings hiển thị đúng model Pro mới ✅

lib/screens/settings_screen.dart:
- Dòng 103-134: row Pro trạng thái động — "Pro (Remove Ads Forever)" nếu
  `year>=9999`, "Pro unlocked — Xh left" nếu đang trong 24h, "Free (1 Widget)" còn lại.
- `onTap` bản Free → `_watchAdToUnlock()` → `RewardedAdService.showRewardedAd()`.
- Dòng 137-144: ListTile "Remove Ads Forever" → `IapService.buyPro()` (IAP hiện có, giữ nguyên).
- `restorePurchases()` giữ nguyên (bắt buộc Store review).

---

## Task 5 (P0.5) — Onboarding use-case-driven ✅

- lib/services/sample_data_service.dart: enum `SampleUseCase` (vocabulary /
  motivation / workFocus / gym / personalQuotes) + `createSampleCollections(useCase)`
  CHỈ tạo 1 collection tương ứng (không tạo 3 như cũ). Toàn bộ text tự viết mới,
  không quote celebrity.
- lib/screens/use_case_selection_screen.dart (mới): chọn use case → tạo sample →
  hiện **live widget preview** (QuoteCard, tap để cycle, hiện n/total) →
  Continue → AddWidgetGuideScreen.
- onboarding_screen.dart: nút "Start with Sample" → UseCaseSelectionScreen.

---

## Task 6 (P0.5/P1) — Curated Themes ✅

- lib/models/widget_theme.dart (mới): `WidgetTheme(id/name/icon/backgroundColor/
  gradientEnd/textColor/accentColor)` + `kCuratedThemes` 6 theme: ocean, sunset,
  forest, midnight, rose, sand.
- Native (bắt buộc của task): render trên CẢ widget_small.xml và widget_medium.xml
  bằng cách map theme id → gradient drawable động trong QuoteWidgetProvider.kt
  (`themeDrawableFor`, dòng 332-341), set trên `R.id.widget_root` — KHÔNG tạo layout
  riêng từng theme:
  - widget_small.xml / widget_medium.xml: thêm `android:id="@+id/widget_root"`.
  - res/drawable/widget_bg_{ocean,sunset,forest,midnight,rose,sand}.xml (6 file mới).
  - Progress indicator dùng `themeAccentFor(theme)` (dòng 219, 343-352).
- widget_config_screen.dart: preset hiển thị Light/Dark/Custom + 6 theme chip màu;
  chọn theme lưu id + màu vào AppearanceConfig.
- widget_preview.dart: preview trong app render gradient khớp native.

### Bằng chứng test (test/curated_themes_test.dart — 4 test PASS)
- every curated theme has a matching native gradient drawable
- no orphan theme drawables
- colors are valid opaque ARGB
- theme ids unique & >=5 themes
→ đảm bảo Flutter set và native resource luôn khớp, không render lệch màu.

---

## Task 7 (P1) — Trash / Recently Deleted ✅

- lib/models/collection_model.dart + item_model.dart: thêm `bool isDeleted`,
  `DateTime? deletedAt` + getter `isTrashed`. Adapter Hive **backward-compatible**:
  đọc cũ `fields[3] as bool? ?? false` (collection) / `fields[5] as bool? ?? false`
  (item) → dữ liệu Hive cũ không vỡ.
- lib/services/storage_service.dart:
  - `deleteCollection(id)`: snapshot an toàn TRƯỚC → set flag collection + toàn bộ
    item con (cascade vào trash) → xoá widget config trỏ tới collection.
  - `deleteItem(id)`: chỉ set flag, KHÔNG xoá khỏi Hive.
  - `restoreCollection(id)` / `restoreItem(id)`: gỡ flag + khôi phục item con.
  - `permanentlyDeleteCollection(id)` / `permanentlyDeleteItem(id)`: xoá thật.
  - `getTrashedCollections()` / `getTrashedItems()`.
  - `purgeTrash(retention: 30 ngày)` — gọi lúc app mở (main.dart).
  - Active views (`getAllCollections/getItemsForCollection/getItem/getItemCount`)
    lọc `!isDeleted` → UI và widget không hiển thị nội dung đã xoá.
- lib/screens/recently_deleted_screen.dart (mới): danh sách collection/item trong
  trash, nút Restore / Delete Forever, gọi `purgeTrash()` khi mở màn.
- SettingsScreen: thêm mục "Recently Deleted" dẫn tới màn trên.

### Bằng chứng test (test/trash_test.dart — 9 test PASS)
- deleteItem flags + hides from active views + stays in Hive
- restoreItem brings item back
- permanentlyDeleteItem removes entirely
- deleteCollection flags collection AND its items (cascade)
- restoreCollection restores collection + all items
- permanentlyDeleteCollection removes everything
- purgeTrash removes trashed beyond retention / keeps inside window
- getAllCollections & getItemsForCollection only return active (regression)

---

## Tổng hợp test

| Suite | Số test | Kết quả |
|---|---|---|
| Baseline cũ (storage/rotation/widget limit/widget) | 44 | PASS |
| iap_service_test (Task 1) | 6 | PASS |
| storage_service_test +2 (Task 1) | 2 | PASS |
| curated_themes_test (Task 6) | 4 | PASS |
| trash_test (Task 7) | 9 | PASS |
| **Tổng** | **65** | **65/65 PASS** |

`flutter analyze`: 0 error / 0 warning.

## Chưa verify bằng máy thật (cần CI/device, đúng theo yêu cầu prompt)
- Hiển thị gradient theme trên widget thật (cần cài APK) — đã đảm bảo bằng parity
  test + Kotlin mapping, bước render thật là CI build + test device.
- Luồng rewarded ad thật (cần AdMob account + test device).
- Kích hoạt GitHub Pages cho privacy.html.
