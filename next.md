# Next — Quote Widget

> Ngày cập nhật: **2026-09-07**
> ⚠️ **FEATURE FREEZE 2026-09-06** — vẫn hiệu lực. Chỉ nhận **bugfix + Device QA**, không feature mới cho tới khi `CLOSED_TESTING_OK`.
> Batch đã commit `c3b6f73` + push; QA candidate mới đã build (run 34074951700, TEST_ADS=false). Review + 2 commit cleanup prefs-hygiene xong (`f54623f`, `1fff5bc`) — local ahead 2, chưa push. Chi tiết: `result8.txt`.

## ✅ Đã hoàn thành (gần đây nhất)

- **Feature Close Batch** (2026-09-06): Block A fixes (A1–A9) + Block B features (B1–B5) + Block C docs — 155/155 tests, analyze 0 issues.
- **2026-09-07:**
  - Commit `c3b6f73` (35 files, +2285/−467) + push main; secret-scan sạch.
  - CI push run 34074858578 ✅; **QA candidate mới** dispatch run **34074951700** (`test_ads=false`) ✅ — artifact `release-apk` sẵn sàng.
  - Code review toàn batch (fallback thủ công — OCR không có; ponytail-review chạy): **0 blocker**; verified-safe author-stale B1 (test bọc sẵn) + cơ chế registry A3 khớp 2 phía Dart↔Kotlin.
  - Cleanup `1fff5bc` (mirror `f54623f`): `widget_data_bridge.dart` bỏ write dư `flutter.is_pro_expires_at` (key rác `flutter.flutter.*`) + term đọc chết trong `getProExpiry`; test mới 4 case → **159/159**, analyze sạch (**chưa push**).

## 🔴 Gấp nhất (chặn CLOSED_TESTING / Production)

1. **Tải QA candidate** — `gh run download 34074951700 -n release-apk` (hoặc tải từ trang Actions) → cài lên Device A.
2. **Device QA Wave 1 (A1–A6) trên Device A** — tôi không có thiết bị thật:
   - Ghi model + Android version vào `.plan/device_qa_run_sheet.md`.
   - Chạy A1–A6 theo run sheet (mỗi case có Pre/Steps/Expected + Triage if FAIL).
   - Gate cứng: **Wave 1 PASS** → mở Wave 2–6. Báo từng case → tôi triage FAIL, fix blocker, re-run.
3. **Push 2 commit cleanup** (`f54623f` + `1fff5bc`) kèm lần commit tới (hoặc push ngay — sẽ trigger CI; không cần build lại QA candidate vì cả 2 là no-op trên thiết bị).

## 🟡 Sau khi Wave 1 PASS

4. **Wave 2–6** theo run sheet:
   - Wave 2: B1 reboot / B2 force-stop / B3 update simulation.
   - Wave 3: C1 rewarded-unlock-24h (candidate này TEST_ADS=false → real ad units), C2 no-fill, C3/C4 expiry, H1/H2 banner.
   - Wave 4: D1–D2 share, E1–E4 backup (E3 restore không phantom + A6 reconcile).
   - Wave 5: F1–F5 rotation (F4 shuffle bag, F5 daily) + G1–G2 OEM (Device B Samsung/Xiaomi).
   - Wave 6: SHOULD I1–I5 (không block — ghi risk).
5. **Release prep:** AAB build step, version bump, release signing, verify Privacy URL live.

## 🟢 Đã xong gần đây (không còn pending)

- ~~Commit batch~~ — ✅ `c3b6f73` pushed
- ~~Build QA candidate TEST_ADS=false~~ — ✅ run 34074951700
- ~~Review batch sau commit~~ — ✅ 0 blocker (result8.txt)
- ~~Xóa ghi registry dư (key rác flutter.flutter.)~~ — ✅ `f54623f` + `1fff5bc` (pro-expiry bridge, +4 test) (local, chưa push)

## ❓ Cần hỏi lại bạn (answer trước khi làm tiếp)

1. **Push 2 commit cleanup ngay hay để kèm commit sau?** (local ahead 2)
2. **AAB có cần không** (chỉ APK test, hay còn AAB để đăng Play Store)?
3. **Version bump**: trước closed testing / production, version là bao nhiêu (vd 1.0.0 → 1.0.1 hoặc 1.1.0)?
4. **Signing key**: `android/key.properties` + signingConfig, hay play-app-signing / thủ công?
5. **Privacy URL live**: tôi verify `https://hoangsoft90.github.io/QuoteWidget/privacy.html` giúp, hay bạn đã check?
6. **Rotate PAT trong git remote?** Token đang nhúng trong remote URL (`git remote -v` thấy được) — nên rotate + chuyển sang credential helper; tôi có thể hướng dẫn.

## 🧹 Việc tôi làm được ngay khi bạn ready

- Push `f54623f` + theo dõi CI.
- Verify privacy URL live → ghi vào features.md.
- Hướng dẫn từng bước Wave 1 trên điện thoại của bạn (case A1→A6 lần lượt, tôi triage kết quả).
- Sau QA PASS: cập nhật run sheet verdict + features_final.md badge + chuẩn bị release notes.
- Chuẩn bị release notes ngắn gọn.

Trước tiên: **tải APK từ run 34074951700 → cài Device A → chạy Wave 1**, đồng thời cho biết câu trả lời cho mục ❓ (ít nhất câu 1).
