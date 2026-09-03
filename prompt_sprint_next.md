# PROMPT CHO AGENT — Sprint tiếp theo (QuoteWidget)

> Dựa trên forensic đọc trực tiếp source tại `/Users/hoang/htdocs_apps/QuoteWidget/source` (không phải suy đoán). Mọi path dưới đây đã verify tồn tại. Làm đúng thứ tự P0 → P0.5 → P1, không nhảy cóc.

---

## ⚠️ ASSUMPTION cần đọc trước khi code (không tự ý đổi nếu sai)

`checklist.md` ở root project ghi: *"muốn sử dụng tính năng pro phải xem ads, và chỉ sử dụng được trong ngày. Ngày hôm sau phải muốn sử dụng pro tiếp phải xem ads."* — đây là mô hình **rewarded-ad unlock 24h**, khác hẳn kiến trúc `IapService` hiện tại (one-time purchase vĩnh viễn).

**Quyết định cho sprint này**: Triển khai mô hình rewarded-ad unlock 24h làm cơ chế chính. **Giữ lại** flow IAP one-time hiện có (`in_app_purchase`) như một lựa chọn phụ **"Remove Ads – Unlock Pro Forever"** (một lần mua, không cần xem ads nữa) — không xóa code IAP đã hoạt động, chỉ thêm lớp ads-unlock lên trên. Nếu đây không phải ý bạn (ví dụ bạn muốn xoá hẳn IAP, chỉ dùng ads), dừng lại và xác nhận trước khi Task 1 chạy.

---

## TASK 1 (P0 tuyệt đối) — Pivot monetization sang rewarded-ad unlock 24h

**File cần sửa/tạo:**

1. `pubspec.yaml` — thêm dependency `google_mobile_ads`.
2. `lib/services/iap_service.dart` — đổi `isPro` từ boolean vĩnh viễn sang **time-bound**:
   ```dart
   DateTime? proUnlockedUntil; // null hoặc đã qua = hết hạn
   bool get isPro => proUnlockedUntil != null && DateTime.now().isBefore(proUnlockedUntil!);
   ```
   - Giữ nguyên toàn bộ logic `restorePurchases()`/`_onPurchaseUpdate()` cho nhánh mua vĩnh viễn — khi mua thành công, set `proUnlockedUntil = DateTime(9999)` (coi như vĩnh viễn) thay vì set `true` đơn thuần.
3. **Tạo mới** `lib/services/rewarded_ad_service.dart`:
   - Load 1 rewarded ad khi app mở.
   - Hàm `Future<bool> showRewardedAd()` — trả `true` nếu user xem hết ad và nhận reward.
   - Khi reward nhận được → gọi `iapService.unlockProFor24h()` (method mới trong `iap_service.dart`, set `proUnlockedUntil = DateTime.now().add(Duration(hours: 24))`, lưu SharedPreferences, sync `HomeWidget.saveWidgetData('is_pro', ...)` và `is_pro_expires_at` — widget Kotlin cần biết thời điểm hết hạn để tự khoá lại, không chỉ đọc bool tĩnh).
4. `lib/services/storage_service.dart` (dòng ~208, chỗ enforce widget limit `if (!_isPro && _widgetConfigsBox.isNotEmpty)`) — đảm bảo logic đọc `isPro` getter mới (đã tự động time-bound nếu làm đúng bước 2), verify widget limit tự khoá lại đúng lúc hết 24h khi user mở app.
5. `lib/services/widget_data_bridge.dart` + `lib/services/widget_service.dart` — đồng bộ thêm key `is_pro_expires_at` (timestamp) xuống SharedPreferences để Kotlin (`QuoteWidgetProvider.kt`) có thể tự kiểm tra hết hạn ngay cả khi app không mở (ví dụ dùng `System.currentTimeMillis()` so sánh mỗi lần widget update).
6. UI: nút "Xem quảng cáo để mở khoá Pro (24h)" đặt ở đúng điểm chặn hiện tại (nơi user đang bị giới hạn 1 widget) — không phải Settings, mà ngay tại màn hình bị chặn (ví dụ khi bấm "Add Widget" lần 2).

**Acceptance criteria:**
- Free user bấm "Add widget" lần 2 → thấy nút xem ads, không phải dead-end.
- Xem ads xong → tạo được widget thứ 2 ngay, `proUnlockedUntil` đúng +24h.
- Sau 24h (test bằng cách set giờ máy hoặc mock `DateTime.now`) → tự động khoá lại, widget thứ 2 vẫn tồn tại nhưng không tạo thêm được widget mới cho tới khi xem ads lại.
- User đã mua "Remove Ads Forever" → không bao giờ thấy nút xem ads nữa.

---

## TASK 2 (P0) — Fix Share Sheet đang mở app thay vì chạy ngầm

**Vấn đề xác nhận trong code:** `ShareReceiverActivity.kt` hiện gọi `startActivity(mainIntent)` → mở toàn bộ `MainActivity`/Flutter UI, gây nhấp nháy màn hình. Đây không phải giả thuyết, đã đọc trực tiếp file.

**File cần sửa:**

`android/app/src/main/kotlin/com/quotewidget/quotewidget/ShareReceiverActivity.kt`

- **Xoá đoạn** `startActivity(mainIntent)`.
- Giữ nguyên phần lưu vào `SharedPreferences` (`pending_share_text`).
- Chỉ `finish()` ngay sau khi lưu — **không mở MainActivity**.
- Đổi theme của Activity này trong `AndroidManifest.xml` (`android/app/src/main/AndroidManifest.xml`, activity `ShareReceiverActivity`) từ `@style/LaunchTheme` sang theme translucent/no-display (ví dụ `@android:style/Theme.Translucent.NoTitleBar`) để không có flash màn hình trắng.
- Xử lý logic "lưu vào collection nào" theo đúng flow đã có sẵn trong `lib/main.dart` (`_handlePendingShare()`), **nhưng chỉ chạy khi user tự mở app sau đó** — không tự mở app ngay lúc share.
- Nếu chỉ có 1 collection → lưu thẳng, show notification hệ thống nhỏ "Đã lưu vào [Collection]" (dùng `flutter_local_notifications` hoặc native `Toast`/`Notification`) thay vì SnackBar (SnackBar chỉ hiện được khi app đang mở).
- Nếu nhiều collection và chưa rõ lưu vào đâu → vẫn phải mở app để hỏi (chấp nhận được, đây là exception hợp lý theo đúng khuyến nghị review trước).

**Acceptance criteria:**
- Share text từ Chrome/X → chọn app → **không thấy màn hình app hiện lên** (nếu có sẵn ≥1 collection, đặc biệt khi chỉ có 1 collection).
- Có thông báo xác nhận đã lưu (notification hệ thống, không phải SnackBar).
- Mở app sau đó → item đã có trong đúng collection, widget cập nhật nếu đang hiển thị collection đó.

---

## TASK 3 (P0) — Privacy Policy URL thật

`lib/screens/settings_screen.dart`, hàm `_openPrivacyPolicy()` đang trỏ tới URL comment `TODO: Replace...` chưa tồn tại (`github.io/quotewidget/privacy` — không có thật). Đây là blocker cứng khi nộp Google Play/App Store.

- Tạo 1 trang tĩnh (GitHub Pages hoặc bất kỳ static host nào) với nội dung Privacy Policy thực (app offline-first, không thu thập dữ liệu, có dùng `google_mobile_ads` sau Task 1 nên cần nêu rõ ads SDK có thể thu thập advertising ID).
- Update URL trong `_openPrivacyPolicy()`.
- Xoá comment TODO.

---

## TASK 4 (P0) — Sửa Settings UI Pro-confusion

`lib/screens/settings_screen.dart`, `ListTile` hiện "Free (1 Widget)" / "Pro (Unlimited Widgets)" không có `onTap`.

- Đổi sang hiện trạng thái theo mô hình mới (Task 1): "Pro unlocked — Xh còn lại" nếu đang trong 24h, hoặc "Free — Xem ads để mở khoá Pro" với `onTap` gọi thẳng `RewardedAdService.showRewardedAd()`.
- Thêm dòng nhỏ "Hoặc mua Remove Ads Forever" dẫn tới flow IAP hiện có.

---

## TASK 5 (P0.5) — Onboarding use-case-driven

`lib/screens/onboarding_screen.dart` + `lib/services/sample_data_service.dart`

- Thêm màn hỏi use-case trước bước "Start with Sample": Vocabulary / Motivation-Affirmation / Work-Focus / Gym / Personal Quotes (icon + tên, dùng `ask_user_input` style layout đơn giản, không cần phức tạp).
- `sample_data_service.dart`: đổi `createSampleCollections()` để nhận tham số `useCase`, chỉ tạo 1 collection tương ứng (không tạo cả 3 như hiện tại) + nội dung tự viết cho từng use-case (không dùng quote celebrity — giữ nguyên nguyên tắc đã áp dụng đúng ở bản hiện tại).
- Sau khi tạo → show live widget preview đẹp ngay trong onboarding trước khi dẫn tới `AddWidgetGuideScreen`.

---

## TASK 6 (P0.5/P1) — Curated Themes (native-first, không chỉ Flutter)

`lib/screens/widget_config_screen.dart` (hiện chỉ Light/Dark/Custom) + native layer:

- Thêm 5-6 theme cố định trong Flutter (data class `WidgetTheme` với `id/name/backgroundColor/textColor/accentColor`).
- **Bắt buộc**: mỗi theme phải test hiển thị đúng trên cả hai file layout native đã tồn tại — `android/app/src/main/res/layout/widget_small.xml` và `widget_medium.xml` — vì đây là RemoteViews, không tự động render đẹp như Flutter Preview. Dùng `drawable/widget_background.xml` hiện có làm điểm bắt đầu, tạo thêm các biến thể `GradientDrawable` trong `QuoteWidgetProvider.kt` nếu cần thay vì tạo layout XML riêng cho từng theme (đỡ tốn công hơn, RemoteViews vẫn set màu/gradient động được qua `setInt`).
- Không làm: color wheel, HEX input tự do, custom font upload.

---

## TASK 7 (P1) — Trash / Recently Deleted

Xác nhận: không có field `isDeleted`/`deletedAt` nào trong `lib/models` hiện tại — cần thêm mới.

- `lib/models/item_model.dart` và `collection_model.dart`: thêm `bool isDeleted = false`, `DateTime? deletedAt`.
- Xoá → chỉ set flag, không xoá khỏi Hive thật.
- Màn "Recently Deleted" trong Settings, tự xoá vĩnh viễn sau 30 ngày.

---

## KHÔNG LÀM ở sprint này

- Photo background, custom font import, iOS widget, cloud sync, streak, AI — giữ nguyên P2 như các plan trước.
- Đừng đổi kiến trúc `Collection.itemIds[]` hiện tại nếu đang chạy ổn — chỉ sửa khi có bug cụ thể.

## Thứ tự bắt buộc

Task 1 → Task 2 → Task 3 → Task 4 (tất cả P0, làm trước khi build release thử nghiệm) → Task 5 → Task 6 → Task 7. Sau Task 4, có thể tạo 1 build test nội bộ để verify Share flow + Ads flow chạy đúng trên máy thật trước khi làm tiếp Task 5-7.
