# Quote Widget – Your Words
### Bản đặc tả kỹ thuật v2 (Final, sẵn sàng giao Agent code)
*Tổng hợp từ `plan1_final.md` + 6 vòng review (review1–review6). Đây là bản duy nhất agent cần đọc — không tham chiếu ngược lại các file review.*

---

## 0. North Star — Core Loop

Mọi feature phải phục vụ vòng lặp này. Feature nào không phục vụ trực tiếp → không phải P0.

```
Tạo nội dung → Chọn Collection → Tuỳ chỉnh → Thêm Widget
     ↑                                              ↓
Tạo thêm nội dung ← Chạm để chuyển ← Nhìn mỗi ngày
```

**USP thật sự** (dùng cho ASO/marketing):
> "Create your own content → put it on your Home Screen → tap to cycle through it."

Backup, Collections là **lý do để ở lại (retention)**, không phải **lý do để tải app (acquisition)**. Đừng nhầm hai vai trò này khi viết App Store description.

---

## 1. Positioning & Naming

- **Title**: `Quote Widget – Your Words`
  (giữ từ khoá "Quote Widget" cho ASO, tránh tên ôm đồm 3 sản phẩm như "Personal Notes & Reminders")
- **Subtitle/Description**: mở rộng capability — "Personal content, reminders, notes & quotes on your Home Screen"
- **Store tagline gợi ý**: "Cách nhanh nhất để biến những câu chữ quan trọng với bạn thành widget đẹp, luôn hiện trên Home Screen."
- **Tín hiệu tin cậy để nhấn mạnh trong listing**: app không yêu cầu permission `INTERNET`, không cloud, không tài khoản → 100% offline & private by design.

---

## 2. Data Model (MVP — đã đơn giản hoá, KHÔNG cho agent tự suy diễn thêm)

```
Collection
  ├── id (UUID)
  ├── name
  ├── createdAt
  └── (KHÔNG có itemIds[] — quan hệ đi từ Item → Collection)

Item
  ├── id (UUID)
  ├── collectionId        # 1 item CHỈ thuộc 1 collection. KHÔNG support shared item.
  ├── text
  ├── order
  ├── createdAt
  └── (KHÔNG có field `pinned` ở MVP — chưa có behavior rõ, bỏ hẳn)

WidgetConfig
  ├── id
  ├── collectionId
  ├── currentIndex         # BẮT BUỘC nằm ở đây, KHÔNG global — nếu không, tap widget A sẽ làm widget B nhảy nội dung
  ├── rotationMode          # "sequential" | "random"  (KHÔNG có "daily" ở MVP)
  ├── appearance { theme, fontSize, textColor, background, alignment }
  └── sizeCategory          # "small" | "medium"
```

### Hành vi cascade bắt buộc (điểm dễ bị bỏ sót)
- **Xoá Collection** → dialog xác nhận nêu rõ số item sẽ bị xoá → cascade-delete toàn bộ Item thuộc collection đó → tự động tạo safety snapshot cục bộ trước khi xoá (tái dùng cơ chế snapshot của Restore, xem mục 4).
- **WidgetConfig trỏ tới Collection đã bị xoá** → không dùng chung "empty state" với collection rỗng. Đây là state riêng: **"Collection removed"**, hiển thị CTA "Chọn collection khác cho widget này" → deep-link mở app ở màn chọn collection.
- **Collection rỗng (chưa có item)** → state khác: **"Add some content to this collection."**
- **Item đang được widget hiển thị bị xoá** → widget tự chuyển sang item hợp lệ kế tiếp (không crash, không hiển thị text rỗng).

---

## 3. Rotation Logic (đặc tả chính xác, không mơ hồ)

**Sequential**
- Lưu `currentIndex` theo từng `WidgetConfig`.
- Tap → `currentIndex = (currentIndex + 1) % collection.items.length`.
- Restart app / reboot máy → giữ nguyên `currentIndex` (đọc lại từ storage, không reset).

**Random**
- MVP: random nhưng loại trừ index hiện tại (không lặp lại đúng item vừa hiện).
- P1: nâng cấp thành shuffled-array — đảm bảo mọi item xuất hiện ít nhất 1 lần trước khi vòng lặp lại, tránh một item ra quá dày.

**Daily** → **không làm ở MVP.** Ở P1 làm dưới dạng "Daily Reset" (xem mục 8), khác hẳn với rotation mode "Daily" mơ hồ trong bản gốc.

---

## 4. Backup / Restore — chỉ 2 chế độ ở MVP

Bản gốc ghi "merge hoặc ghi đè" — quá mơ hồ để agent code đúng. Chốt lại:

1. **Append (Nối thêm)** — giữ nguyên dữ liệu hiện tại, thêm item/collection mới từ file backup. Nếu trùng `id` (UUID) → **skip**, không ghi đè, không tạo bản sao.
2. **Overwrite (Ghi đè toàn bộ)** — xoá sạch dữ liệu hiện tại, thay thế hoàn toàn bằng dữ liệu trong file backup.
   - **Bắt buộc**: tự động tạo safety snapshot cục bộ của dữ liệu hiện tại **trước khi** overwrite. Nếu restore lỗi giữa chừng → rollback về snapshot.

**"Merge by Collection" → KHÔNG làm ở v1.** Không cho agent tự chọn giữa merge/overwrite khi thiếu định nghĩa rõ.

### JSON Backup Schema
```json
{
  "backupFormat": "quote-widget-backup",
  "schemaVersion": 1,
  "appVersion": "1.0.0",
  "createdAt": "ISO-8601",
  "platform": "android",
  "collections": [ { "id": "...", "name": "...", "createdAt": "..." } ],
  "items": [ { "id": "...", "collectionId": "...", "text": "...", "order": 0, "createdAt": "..." } ],
  "widgetConfigs": [ { "id": "...", "collectionId": "...", "currentIndex": 0, "rotationMode": "sequential", "appearance": {}, "sizeCategory": "small" } ]
}
```

### Error states bắt buộc cho Import (không được happy-path only)
- JSON không hợp lệ → thông báo lỗi rõ, không crash.
- Sai schema / thiếu field bắt buộc → từ chối import, báo lỗi cụ thể.
- File rỗng → báo lỗi, không tạo state rỗng ngầm.
- File quá lớn (định giới hạn, ví dụ >20MB) → từ chối kèm thông báo.
- `id` trùng lặp trong chính file backup → dedupe khi import.
- Reference đến `collectionId` không tồn tại trong chính file backup → bỏ qua item đó, không crash.

---

## 5. Android Widget — Technical Spec

### 5.1 Công nghệ
- **RemoteViews (XML) — bắt buộc cho MVP**, không dùng Jetpack Glance. Lý do: ổn định 10+ năm, không phụ thuộc version Compose/Kotlin runtime, tránh lỗi build khi kết hợp plugin `home_widget` (Flutter ↔ native bridge).
- Nâng cấp lên Glance chỉ xem xét sau khi có user base lớn và thời gian dư dả — không phải MVP.

### 5.2 Add Widget flow (P0 bắt buộc — đây là choke-point nguy hiểm nhất của activation)
Không có API nào cho phép app tự tạo widget hoàn toàn tự động, **nhưng** từ Android 8.0 (API 26) có API hỗ trợ một phần:

1. **Ưu tiên**: gọi `AppWidgetManager.isRequestPinAppWidgetSupported()` — nếu `true`, gọi `requestPinAppWidget()` để hệ thống tự hiện dialog "Add to Home Screen?", user xác nhận 1 chạm. (Pixel/stock Android hỗ trợ tốt; một số OEM tuỳ biến nặng như MIUI có thể không hỗ trợ.)
2. **Fallback bắt buộc**: nếu API trên trả `false` hoặc launcher không hỗ trợ → hiển thị **hướng dẫn thêm widget bằng hình ảnh, theo từng hãng máy**, detect launcher hiện tại (package name qua `device_info_plus` hoặc `PackageManager`):
   - Pixel/Stock Android: "Nhấn giữ màn hình chính → Widgets → Tìm app → Kéo ra"
   - Samsung One UI: tương tự nhưng UI khác, cần ảnh minh hoạ riêng
   - Xiaomi MIUI: "Nhấn giữ màn hình chính → Thêm tiện ích → Tìm app"
- **Mục tiêu UX**: first widget added trong < 60 giây kể từ khi mở app lần đầu — coi đây là KPI onboarding.

### 5.3 Responsive layout (widget resize) — phải ghi acceptance criteria cụ thể, không chỉ liệt kê "small + medium"
- Khai báo `minWidth` / `minHeight` / `resizeMode` trong widget provider info XML.
- MVP: chỉ hỗ trợ 2 size cố định (small, medium), **không cho resize tự do** — giảm edge case.
- Nếu target API < 31: tự implement `onAppWidgetOptionsChanged()` để đổi layout khi resize (ẩn author/đổi số dòng text khi widget nhỏ).
- Nếu target API ≥ 31: có thể dùng responsive RemoteViews (map layout theo kích thước), nhưng để an toàn MVP vẫn giữ 2 size cố định.

### 5.4 SDK
- `minSdk = 24` (Android 7.0 — phủ >95% thiết bị, tương thích RemoteViews không vấn đề)
- `targetSdk` = phiên bản mới nhất theo yêu cầu hiện hành của Google Play tại thời điểm submit
- **Không cần permission `INTERNET`** ở MVP (app hoàn toàn offline) — giữ permission tối thiểu, đây cũng là điểm marketing tin cậy.

### 5.5 Acceptance Criteria cho Native Spike (bắt buộc, PASS/FAIL rõ ràng — nếu <7/8 → dừng, không code tiếp phần Flutter UI)
1. Widget render đúng text.
2. Tap đổi text, **không mở app** (Android).
3. Widget sống sót sau khi force-stop app.
4. Widget sống sót sau khi reboot thiết bị.
5. Nhiều instance widget hoạt động độc lập (mỗi widget giữ `currentIndex` riêng — tap widget A không ảnh hưởng widget B).
6. Collection rỗng → hiển thị empty state rõ ràng, không crash.
7. Item đang hiển thị bị xoá → widget tự chuyển sang item hợp lệ, không crash.
8. Update data từ app (thêm/sửa item) → widget cập nhật ngay không cần reboot.

### 5.6 Testing trên nhiều OEM khi không có máy thật
- Dùng **Firebase Test Lab** (free tier đủ vài lượt/tháng) để chạy trên virtual + physical device thật của Samsung/Xiaomi/Pixel từ xa, thay vì giả định phải mua máy.
- Đưa việc setup Test Lab vào ngay bước Native Spike (mục 0.2), là công cụ cụ thể chứ không ghi chung chung "test trên OEM".
- Test đặc biệt: reboot, force stop, battery saver, app bị kill, widget bị gỡ rồi thêm lại.

---

## 6. Feature Priority (Revised — bản cuối cùng)

### P0 — Core (bắt buộc, không cắt thêm)
- Collections + Item CRUD + Bulk Add + reorder (1 item = 1 collection)
- Android native widget (RemoteViews XML), size small + medium
- Tap-to-cycle: Sequential + Random cơ bản
- `currentIndex` per `WidgetConfig`
- 3 theme cơ bản, font size, text color, background, alignment
- JSON Backup/Restore: Append + Overwrite, kèm schema version + safety snapshot trước Overwrite/xoá Collection
- Widget preview live trong app
- Add Widget flow: `requestPinAppWidget()` ưu tiên + fallback hướng dẫn theo OEM (Pixel/Samsung/Xiaomi)
- Onboarding: chọn "Start with sample" hoặc "Add your own", mục tiêu first-widget < 60s
- Sample collections **tự viết nội dung** (không dùng quote gắn celebrity — tránh rủi ro bản quyền/attribution)
- Empty/error states đầy đủ (collection rỗng, collection removed, item deleted, import lỗi — xem mục 4 và mục 2)
- Hive làm local storage

### P0.5 — làm ngay sau khi P0 pass acceptance criteria
- **Share Sheet Quick Add**: value/code ratio cao nhất — user share text từ Reddit/Twitter/news → app nhận, lưu thành item.
  - MVP chỉ xử lý: có plain text → lấy text trực tiếp. Có URL nhưng không có text → mở app, để user tự nhập/xác nhận. **Không xây scraper.**
- Progress indicator (n/total trong collection)
- Multiple-widget data model (đã có sẵn từ P0 vì `WidgetConfig` độc lập theo id)
- **Restore Purchases** button — bắt buộc đi cùng IAP non-consumable, cả Google Play lẫn App Store (App Store Review Guideline 3.1.1) đều yêu cầu, thiếu dễ bị từ chối duyệt. Đưa vào ngay đợt này, đừng để tới P1 mới nhớ.

### P1
- Multiple widgets (Pro)
- Photo background (chỉ: chọn ảnh → crop → overlay quote; không cần filter/animation)
- iOS WidgetKit + fallback rõ ràng
- Encrypted backup bằng passcode (Pro)
- Hide on lock screen — **cân nhắc lại từ đầu, xem mục 7**
- Daily Reset (xem mục 8)
- Export as Image (kèm watermark nhỏ tên app ở bản Free — tạo organic acquisition loop)
- CSV/TXT import
- Custom bundled fonts (5–8 font có sẵn, KHÔNG cho user upload `.ttf`)
- Recently viewed / history (undo/previous trong app, widget vẫn chỉ có tap = next)

### P2
- Cloud sync (chỉ khi có nhu cầu thật — KHÔNG thêm Firebase/Supabase/Auth vào MVP, offline-first là lợi thế lớn: không login, không backend, chi phí vận hành ~0)
- Community collection packs
- Smart/scheduled rotation nâng cao
- Streak
- AI (không cần ở giai đoạn chưa có user — tốn cost, tăng privacy concern, không giải quyết pain point cốt lõi)

### Loại bỏ khỏi v1 (không đưa vào bất kỳ priority nào, kể cả P2 chưa chắc)
- Tip Jar (chưa có loyalty, thêm sau khi có user trung thành)
- Notification auto-rotate
- Shared items giữa nhiều collections
- `pinned` field
- Merge by Collection (restore mode thứ 3)

---

## 7. Về `Hide on lock screen` — quyết định cuối

Cả 5 review đều đẩy từ P0 xuống P1, review3/4/5 đề xuất loại hẳn khỏi v1. Quyết định cuối: **loại khỏi P0, để ở P1 nhưng với điều kiện** — chỉ implement nếu có tín hiệu nhu cầu thật từ user sau launch (ví dụ feedback về nội dung nhạy cảm: trading rules, ghi chú cá nhân). Lý do giữ ở P1 thay vì xoá hẳn: positioning đã mở rộng sang "personal reminders/private notes" nên nhu cầu privacy có thể phát sinh thật — nhưng **không đoán trước, không code khi chưa có bằng chứng**. Nếu làm, dùng cách đơn giản nhất: cho phép user chọn collection không hiển thị trên widget, thay vì can thiệp `FLAG_SECURE`/lock-screen rendering phức tạp theo từng OEM.

---

## 8. Daily Reset (P1 — retention rẻ tiền, đáng làm)

- Vấn đề: Sequential dễ "xem hết rồi chán"; Random dễ trùng lặp cảm nhận.
- Giải pháp: tuỳ chọn "Reset mỗi ngày" — mỗi 0:00 giờ địa phương, widget tự reset `currentIndex` về 0 (hoặc random mới).
- Kỹ thuật: dùng `WorkManager` (không dùng `AlarmManager` exact alarm để tránh vướng giới hạn Doze mode/battery optimization trên OEM khắt khe) để lên lịch reset gần giờ 0:00, chấp nhận sai lệch vài phút.
- Tạo lý do chạm vào widget mỗi sáng mà không cần notification gây phiền.

---

## 9. Monetization

- **Free**: unlimited items + 1 widget (giữ nguyên — content không nên bị giới hạn nhân tạo, thứ nên bán là customization/power, không phải data)
- **Pro** (one-time, không subscription): $3.99–$4.99, mở khoá multiple widgets, photo background, encrypted backup, custom fonts nâng cao
  - Cân nhắc test giá $2.99/$3.99/$4.99 sau launch để đo conversion, chưa chốt cứng.
  - **Introductory Sale** tuần đầu ra mắt: giảm còn ~$2.49 (giảm ~40–50%), banner "Pro upgrade – 50% OFF first week" để tạo FOMO và tăng conversion sớm.
- **Không có Ads** ở MVP — widget minimalist, ads phá aesthetic, không đáng so với lifetime fee nhỏ.
- **Không có Tip Jar** ở MVP.

---

## 10. Kiến trúc code

```
Flutter (UI + business logic)
   ↓
Domain / Data model (platform-neutral — Collection, Item, WidgetConfig)
   ↓
Widget abstraction layer
   ↓
Android implementation (RemoteViews, home_widget plugin, requestPinAppWidget, WorkManager)
   ↓
iOS implementation (sau, khi Android ổn định — WidgetKit)
```

- Data/content model phải platform-neutral ngay từ đầu, chỉ phần widget rendering mới platform-specific.
- Không tách `privacy_service.dart` thành abstraction riêng ngay từ MVP — privacy/encryption chưa phải domain chính, tránh over-engineering "Clean Architecture" khi chưa cần. Nếu sau này cần (P1, encrypted backup) mới tạo `services/privacy/`.
- Storage: Hive cho local data.

### 10.1 Project structure (đã cập nhật theo data model v2 — bỏ itemIds/pinned/hideOnLockScreen khỏi model)

```
lib/
├── main.dart                        # Entry point, init Hive & HomeWidget
├── models/
│   ├── collection_model.dart        # {id, name, createdAt}  — KHÔNG có itemIds[]
│   ├── item_model.dart              # {id, collectionId, text, order, createdAt}  — KHÔNG có pinned, author bỏ hoặc để optional
│   └── widget_config_model.dart     # {id, collectionId, currentIndex, rotationMode, appearance, sizeCategory}
├── screens/
│   ├── home_screen.dart             # Danh sách Collections
│   ├── collection_detail_screen.dart # CRUD Item, Bulk Add, xử lý cascade-delete khi xoá collection
│   ├── widget_config_screen.dart    # Tuỳ chỉnh theme/màu/font/size cho widget + live preview
│   ├── backup_screen.dart           # Export/Import JSON, chọn Append/Overwrite, hiển thị safety snapshot
│   ├── onboarding_screen.dart       # Start with sample / Add your own → Add Widget, mục tiêu <60s
│   └── add_widget_guide_screen.dart # Fallback hướng dẫn theo OEM khi requestPinAppWidget không được hỗ trợ
├── widgets/
│   ├── quote_card.dart
│   └── widget_preview.dart          # Preview widget ngay trong app
└── services/
    ├── storage_service.dart         # Hive DB, xử lý cascade-delete
    ├── widget_service.dart          # home_widget bridge, gọi requestPinAppWidget
    ├── backup_service.dart          # Export/Import JSON, schema version, snapshot/rollback
    └── rotation_service.dart        # Logic Sequential/Random, tách riêng để dễ test acceptance criteria (mục 11)
```

### 10.2 Dependencies chính (Flutter packages)

| Package | Mục đích |
|---|---|
| `hive` / `hive_flutter` | Local storage |
| `home_widget` | Bridge Flutter ↔ Android RemoteViews widget |
| `file_picker` | Chọn file JSON khi Import |
| `share_plus` | Export/share file backup, share Export-as-Image (P1) |
| `share_handler` | Nhận text từ Share Sheet của app khác (P0.5 — Quick Add) |
| `device_info_plus` | Detect launcher/OEM để chọn hướng dẫn Add Widget đúng hãng |
| `workmanager` | Lên lịch Daily Reset (P1), tránh dùng AlarmManager exact alarm |

*(agent có thể thay package tương đương nếu phiên bản trên không còn được maintain tại thời điểm code — nguyên tắc chọn: ưu tiên package chính thức/nhiều maintainer, tránh package ít cập nhật khi làm việc với widget/OS-level API.)*

---

## 11. Acceptance Tests mẫu (agent phải viết test tương ứng, không chỉ code theo mô tả prose)

```
Sequential:
  Given collection [A, B, C], initial currentIndex = 0 (A)
  Tap → B (index 1)
  Tap → C (index 2)
  Tap → A (index 0, wrap around)

Random:
  Current = A
  Tap → kết quả PHẢI khác A

Item bị xoá:
  Current = B, xoá B
  → widget hiển thị item hợp lệ còn lại, không crash

Collection rỗng:
  → widget hiển thị "Add some content to this collection."

Collection bị xoá (widget vẫn trỏ tới):
  → widget hiển thị "Collection removed" + CTA chọn collection khác

Restore (Overwrite):
  Backup → xoá hết dữ liệu hiện tại → Restore
  → collections/items/widgetConfigs khớp chính xác với file backup
  → nếu restore lỗi giữa chừng → rollback về safety snapshot

Restore (Append):
  Có sẵn item id=X → import file backup cũng chứa id=X
  → item không bị nhân đôi, giữ nguyên bản gốc trong app
```

---

## 12. Roadmap thực tế

- **Bước 0** — Competitor check + Native Spike (bắt buộc, có Firebase Test Lab): 1–1.5 ngày
- **Android MVP usable**: 9–14 ngày calendar time (không phải 7–8 như ước tính ban đầu)
  - Lý do: native edge case, OEM testing, restore safety, Add Widget guidance, real-device QA chiếm nhiều thời gian hơn phần UI Flutter thuần tuý.
- **P0.5** (Share Sheet, Progress, Restore Purchases): ngay sau khi P0 pass 7-8/8 acceptance criteria của spike.
- **P1 trở đi**: sau khi có dữ liệu user thật từ bản MVP, không code trước theo phỏng đoán (đặc biệt Hide on lock screen, xem mục 7).

---

## 13. Store Compliance Checklist (P0.5, dễ bị quên tới lúc submit mới phát hiện)

- [ ] Nút "Restore Purchases" cho IAP non-consumable (bắt buộc cả Google Play và App Store)
- [ ] Không xin permission `INTERNET` nếu không dùng — giữ permission tối thiểu
- [ ] Privacy policy: nêu rõ app offline-first, không thu thập dữ liệu, không cloud
- [ ] Sample content tự viết, không dùng quote gắn celebrity (tránh copyright/attribution dispute)

---

## Kết luận

**Verdict: BUILD.** Đây là bản duy nhất cần giao cho agent — không còn điểm mơ hồ nào yêu cầu agent tự suy diễn (rotation, restore mode, cascade delete, widget-collection-removed state, Add Widget flow đều đã có acceptance criteria cụ thể).

Bước tiếp theo **không phải** thêm một vòng review văn bản nữa — rủi ro còn lại (widget có thực sự mượt trên OEM cụ thể không) chỉ trả lời được bằng cách chạy **Native Spike thật** (mục 0, mục 5.5) và mang kết quả (video demo trên máy thật/Firebase Test Lab) quay lại làm căn cứ cho vòng feedback kế tiếp.