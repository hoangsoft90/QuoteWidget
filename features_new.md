# Features đề xuất mới — Quote Widget

> Danh sách **gợi ý tính năng tương lai**, đã lọc theo:
> 1. **Đúng trục sản phẩm** — app là *home screen widget* cho nội dung cá nhân (quote, từ vựng, lời nhắc), offline-first, Android-only, solo dev.
> 2. **Kiếm tiền được** — mọi tính năng nên gắn được vào mô hình hiện tại (rewarded-ad 24h + banner/interstitial; Pro = bỏ giới hạn widget).
> 3. **Ít rủi ro kỹ thuật** — Hive + Kotlin RemoteViews + không thêm dependency nặng.
> 4. **Ponytail** — ưu tiên 1 dòng thay cho 50 dòng; thẳng thừng loại bỏ ý tưởng over-engineered.
>
> Ước lượng effort: **S** ≤ 1 ngày · **M** 2–3 ngày · **L** ≥ 1 tuần (solo dev).

---

## P0 — Cốt lõi (làm trước, giá trị cao nhất)

### 1. Favorites / Đánh dấu sao ⭐
- **Mô tả:** Mỗi item có flag `favorite` (tap icon sao trong Collection Detail). Widget có tùy chọn `favoritesOnly` — chỉ cycle qua các item yêu thích.
- **Vì sao:** Người dùng widget thường chỉ muốn xem vài câu "tâm đắc" — đây là nhu cầu #1 của app quote.
- **Triển khai:** `Item.favorite` (Hive, có default → **không cần migration schema** vì Hive tự fill default khi đọc box cũ — kiểm tra lại với type adapter), thêm key `widget_<id>_favorites_only` trong Kotlin.
- **Effort: M** · Dependency: không thêm
- **Monetization:** miễn phí (giữ chân người dùng).

### 2. Auto-rotate theo lịch (nội dung tự đổi khi không tap) ⏰
- **Mô tả:** Widget tự chuyển sang item kế tiếp theo schedule (vd: mỗi ngày 1 quote mới, hoặc mỗi X giờ) — không cần user chạm. Hiện tại chỉ đổi khi tap.
- **Vì sao:** Điểm khác biệt lớn nhất so với widget "tĩnh" của hầu hết app khác; tăng thời gian widget được nhìn.
- **Triển khai:** `WorkManager` periodic (min 15 phút) → `QuoteWidgetProvider.onReceive` tự handleTap + `updateAppWidget`. Kotlin-only, không cần Dart. Lưu `last_auto_rotate_at` trong prefs để không đổi quá thường xuyên.
- **Effort: M** · Dependency: `androidx.work` (thêm vào Gradle — nhẹ, không phải pub package)
- **Monetization:** miễn phí; tùy chọn "auto-rotate" có thể là tính năng Pro trong tương lai.

### 3. Thêm kích thước widget (2×3 / 4×2 / tall) 📐
- **Mô tả:** Hiện có small (2×1) + medium. Thêm layout **tall (2×3)**: hiển thị 3–5 item cuộn được hoặc danh sách; và **4×2** cho text to hơn.
- **Vì sao:** Nhiều launcher OEM hỗ trợ kích thước lớn — hiện tại resizeMode="none" bỏ phí không gian.
- **Triển khai:** 2 layout XML + nhánh render theo `appWidgetOptions` size (`onAppWidgetOptionsChanged` đã có). Không đổi file prefs.
- **Effort: M** · Dependency: không
- **Monetization:** kích thước lớn = tính năng Pro 24h? → **khuyên KHÔNG**: limit theo size dễ gây UX bực bội khi user kéo widget. Giữ free.

### 4. Search trong app 🔍
- **Mô tả:** Thanh tìm kiếm ở Home + Collection Detail: tìm theo text (tên collection, nội dung item).
- **Vì sao:** Số lượng item tăng → không tìm được là lý do bỏ app. (Không cần FTS/SQLite — Hive scan 1 box đủ nhanh với quy mô cá nhân, vài trăm item.)
- **Triển khai:** `StorageService.searchItems(query)` — filter trong memory. UI: `SearchBar` Material 3.
- **Effort: S–M** · Dependency: không
- **Monetization:** miễn phí.

### 5. Duplicate collection (clone) 🧬
- **Mô tả:** Nút "Duplicate" trên collection → copy toàn bộ item sang collection mới (có thể chọn đổi tên).
- **Vì sao:** Người dùng tạo nhiều bộ từ vựng giống nhau (vd: tiếng Anh theo chủ đề) — clone tiết kiệm thao tác.
- **Triển khai:** 1 hàm trong StorageService + 1 menu item. **Rất dễ.**
- **Effort: S** · Dependency: không
- **Monetization:** miễn phí.

### 6. Sort / shuffle per widget 🔀
- **Mô tả:** Widget config thêm: `sequential` (đã có) / `random` (đã có) / **shuffle-on-tap** (trộn lại mỗi lần tap) / **favorites-first**.
- **Effort: S** · Dependency: không — logic đã nằm trong `RotationService` + Kotlin `handleTap`, chỉ thêm mode.

---

## P1 — Giữ chân & tương tác (làm sau P0)

### 7. Nhắc nhở local (notification) 🔔
- **Mô tả:** User đặt giờ → nhận notification daily với 1 quote ngẫu nhiên từ collection; tap → mở app.
- **Vì sao:** Widget đã phủ màn hình Home; notification giữ chân user không mở Home screen. 100% local (không cần INTERNET).
- **Triển khai:** `flutter_local_notifications` (zonedSchedule, repeat daily). Khi collection bị xóa → hủy nhắc. Cần `POST_NOTIFICATIONS` runtime permission (API 33+).
- **Effort: M–L** · Dependency: `flutter_local_notifications` (một dep, được bảo trì tốt)
- **Monetization:** số lượng nhắc nhở > 1 = Pro 24h? → **khuyên để miễn phí 1 nhắc**, Pro thêm nhiều — gắn với vòng lặp rewarded-ad.

### 8. App shortcuts (tap-giữ icon app) ⚡
- **Mô tả:** Long-press icon → "Add item", "New collection", "Open <collection gần nhất>".
- **Vì sao:** Giảm friction — user thêm quote mới trong 2 tap thay vì 5.
- **Triển khai:** `ShortcutManager` static shortcuts (manifest, XML) — không cần code phức tạp; hoặc dynamic qua Flutter.
- **Effort: S–M** · Dependency: không (native)
- **Monetization:** miễn phí.

### 9. Tùy chỉnh hành động khi tap widget 👆
- **Mô tả:** Widget config: tap → (a) cycle item [mặc định] / (b) mở collection / (c) mở app Home / (d) copy item vào clipboard + toast.
- **Vì sao:** Một số user chỉ muốn mở app từ widget; hiện tap = cycle bắt buộc.
- **Triển khai:** thêm key `widget_<id>_tap_action`; Kotlin `handleTap` switch theo giá trị. **Tương đối dễ.**
- **Effort: M** · Dependency: không
- **Monetization:** miễn phí.

### 10. Export đơn collection / CSV cho từ vựng 📤
- **Mô tả:** Export 1 collection riêng (JSON); riêng cho use-case từ vựng: export CSV (term,definition) để import vào Anki.
- **Vì sao:** Đúng đối tượng học từ vựng — "học qua widget" là killer use case của app.
- **Triển khai:** tái dùng `BackupService` (chỉ lọc theo collectionId) + 1 hàm CSV.
- **Effort: S** · Dependency: không
- **Monetization:** miễn phí.

### 11. Material You (dynamic color) trên widget 🎨
- **Mô tả:** API 31+: khi theme = "system", lấy màu từ wallpaper (`@android:color/system_accent1_*`) thay vì gradient cố định.
- **Vì sao:** Widget hòa vào giao diện người dùng — trông "tự nhiên" hơn hẳn, chi phí thấp.
- **Triển khai:** Kotlin-only: check `Build.VERSION >= 31` → set background color từ system palette; fallback gradient cũ. **KHÔNG đổi hợp đồng theme hiện tại** (giữ gradient làm mặc định).
- **Effort: S–M** · Dependency: không
- **Monetization:** miễn phí.

---

## P2 — Mài nhẵn (chờ thời điểm, không gấp)

- **12. Transparency option trên widget** — nền trong suốt để hòa wallpaper (Android 12+ mới thực sự đẹp). Effort: S. Free.
- **13. Hiện tên collection / ngày tháng trên widget** — toggle nhỏ, effort S. Free.
- **14. Import từ clipboard / file .txt** — mỗi dòng 1 item (đã có Bulk Add trong app; thêm entry từ màn hình Home). Effort: S.
- **15. Empty-state tốt hơn** — onboarding nếu không chọn use case: gợi ý template ngay trong empty state. Effort: S.
- **16. Version động trong About** — đọc từ `package_info_plus` (dependency đã có trong tree — `package_info_plus` đã là transitive dep của share_plus) thay vì hardcode v1.0.0. Effort: S. **Nên làm sớm** (trước khi lên store).
- **17. Multi-language UI (vi/en)** — `flutter_localizations` + `intl` (intl đã có). Effort: M. Làm khi chuẩn bị release quốc tế.

---

## Gắn với monetization (cách 3 tính năng trên kiếm tiền)

| Tính năng | Mô hình đề xuất |
|---|---|
| Auto-rotate theo lịch (P0-2) | Free ở mức mặc định (mỗi ngày); "rotate mỗi X giờ" là Pro 24h |
| Nhắc nhở local (P1-7) | 1 nhắc nhở free; nhiều nhắc nhở = Pro 24h |
| Themes premium (P0 tương lai) | Thêm 3–5 theme gradient mới bán qua rewarded-ad: "Xem ad để mở theme X trong 24h" — **đúng mô hình hiện tại, không cần IAP** |
| Widget lớn / nhiều widget | Đã có sẵn qua Pro 24h (bỏ giới hạn widget) — không đổi |

> Nguyên tắc: **không bao giờ đưa IAP trở lại**. Mọi unlock qua rewarded-ad 24h hoặc banner/interstitial. Giữ nguyên kiến trúc `proUnlockedUntil` hiện tại.

---

## ❌ Non-goals — cố ý KHÔNG đề xuất (lý do)

| Ý tưởng | Lý do loại |
|---|---|
| **Cloud sync / tài khoản** | Phá vỡ offline-first, cần backend + bảo mật dữ liệu cá nhân — chi phí khổng lồ cho solo dev |
| **iOS widget** | Android-only theo scope; iOS cần Swift WidgetKit — codebase khác hẳn |
| **Photo/ảnh nền widget** | RemoteViews không hỗ trợ ảnh động/đẹp; file ảnh nặng, phức tạp cache |
| **Text editor rich text (bold/italic/color) trong item** | RemoteViews chỉ render text phẳng — đầu tư UI không tới được widget, lãng phí |
| **Push notification từ server (quotes of the day online)** | Cần server + INTERNET permission + chi phí vận hành — trái offline-first |
| **Widget interactive (button trong widget)** | RemoteViews giới hạn cứng — chỉ có tap-to-broadcast, không có button thật |
| **Theo dõi analytics chi tiết user** | Xung đột privacy positioning (đang dùng npa=1, không có tài khoản) |
| **Mã QR / AR / AI tạo quote** | Over-engineering thuần túy cho app cá nhân nhỏ |

---

## Thứ tự đề xuất triển khai (roadmap ngắn)

1. **Sprint 1:** P0-5 (Duplicate) · P0-6 (Sort modes) · P0-4 (Search) · P0-1 (Favorites) — toàn bộ S–M, không thêm dependency, test dễ
2. **Sprint 2:** P0-3 (Widget tall 2×3) · P0-2 (Auto-rotate) — phần có giá trị widget lớn nhất
3. **Sprint 3:** P1-8 (App shortcuts) · P1-9 (Tap action) · P1-10 (CSV export) — mài trải nghiệm
4. **Sprint 4:** P1-7 (Notifications) · P1-11 (Material You) — tính năng "wow"
5. **Bất kỳ lúc nào:** P2-16 (version động) trước release

> Mỗi sprint nên kết thúc bằng: `flutter analyze` exit 0 + full test suite pass + CI debug/release xanh + (nếu được) device test — theo đúng quy trình đã lập trong checklist.md.