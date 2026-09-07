# Next — Quote Widget

> Ngày cập nhật: **2026-09-06**
> ⚠️ **FEATURE FREEZE 2026-09-06** — Feature Close Batch đã xong (155/155 tests, analyze 0 issues). Từ giờ chỉ nhận **bugfix + Device QA**, không feature mới cho tới khi `CLOSED_TESTING_OK`.
> Chi tiết batch: `.plan/progress_feature_close.md` (PASS/FAIL + evidence từng mục) · `result7.txt`.

## ✅ Đã hoàn thành (Feature Close Batch 2026-09-06)

- **Block A fixes:** A1 privacy root file · A2 UMP consent (viết lại đúng API thật + gate 3 ad paths + Privacy Options) · A3 delete-collection ↔ free-limit (unbind + Kotlin unregister) · A4 sizeCategory native-truth · A5 reorder sync + bulk-add defensive · A6 restore reconcile ngay · A7 onRestored · A8 dead code + cleartext verdict (giữ) · A9 +7 tests
- **Block B features:** B1 Author (item + widget line) · B2 Export/Import 1 collection JSON · B3 Share quote as image (PNG card) · B4 Widget Setup UI verified đủ engine · B5 About version động (PackageInfo)
- **Gates:** Gate A 145/145 · Gate B 155/155 · `flutter analyze` 0 issue
- **Docs:** features_final.md · checklist.md · features.md · progress_feature_close.md (mới)
- ⚠️ Toàn bộ thay đổi **CHƯA COMMIT** — đang ở working tree

## 🔴 Gấp nhất (chặn CLOSED_TESTING / Production)

1. **Commit Feature Close Batch** (chưa có commit nào của batch này).
2. **Build QA candidate MỚI** — QA candidate cũ (run 33972687792) **CHƯA chứa** batch này (không có Author/B2/B3/UMP). Dispatch CI với input `test_ads=false` → tải `release-apk` artifact mới.
3. **Device QA Wave 1 (A1–A5) trên Device A** — tôi chưa có thiết bị thật:
   - Cài APK mới, ghi model + Android version vào run sheet `.plan/device_qa_run_sheet.md`.
   - Chạy A1–A5 theo run sheet (mỗi case có Pre/Steps/Expected + Triage if FAIL).
   - Gate cứng: **Wave 1 PASS** → mở Wave 2–6. Báo kết quả từng case → tôi triage FAIL, fix blocker, re-run.

## 🟡 Sau khi Wave 1 PASS

4. **Wave 2–6** theo run sheet:
   - Wave 2: B1 reboot / B2 force-stop / B3 update simulation.
   - Wave 3: C1 rewarded-unlock-24h (QA build TEST_ADS=false), C2 no-fill, C3/C4 expiry.
   - Wave 4: D1–D2 share, E1–E4 backup (E3: restore không phantom widget — có thêm A6 reconcile-after-restore để verify).
   - Wave 5: F1–F5 (F4 shuffle bag, F5 daily), G1–G2 trên Device B (Samsung/Xiaomi).
   - Wave 6: H1 ad unit thật, H2 banner không che FAB/3-button nav.
   - SHOULD I1–I5 (không block — chỉ ghi risk).
5. **Release prep:** AAB build step (nếu đăng Play Store), version bump, release signing, verify Privacy URL live.

## 🟢 Đã xong gần đây (không còn pending)

- ~~Settings About: version động~~ — ✅ B5 (PackageInfo)
- ~~Export collection JSON~~ — ✅ B2 (CSV vẫn deferred V1.1)
- ~~UMP consent / Privacy Options~~ — ✅ A2

## ❓ Cần hỏi lại bạn (answer trước khi làm tiếp)

1. **Commit batch này không?** (code + docs + handoff + result7 — tôi chờ xác nhận trước khi `git commit`)
2. **QA candidate mới**: dispatch CI `test_ads=false` ngay sau commit, hay bạn muốn review diff trước?
3. **AAB có cần không** (chỉ APK test, hay còn AAB để đăng Play Store)?
4. **Version bump**: trước closed testing / production, version là bao nhiêu (vd 1.0.0 → 1.0.1 hoặc 1.1.0)?
5. **Signing key**: `android/key.properties` + signingConfig trong build.gradle, hay play-app-signing / tự làm thủ công?
6. **Privacy URL live**: tôi verify `https://hoangsoft90.github.io/QuoteWidget/privacy.html` giúp, hay bạn đã check?

## 🧹 Công việc tôi có thể làm sẵn khi bạn ready

- Commit batch (sau khi bạn xác nhận).
- Dispatch CI build QA candidate `test_ads=false`.
- Verify privacy URL live → ghi vào features.md/changelog.
- Sau device QA PASS → cập nhật run sheet verdict, features_final.md (device test badge), checklist.md (Device QA section).
- Chuẩn bị release notes ngắn gọn.

Trước tiên: **bạn xác nhận commit + build QA candidate mới** → tôi làm tiếp.