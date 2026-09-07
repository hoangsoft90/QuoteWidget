# Next — Quote Widget

> Ngày cập nhật: **2026-09-07**
> ⚠️ **FEATURE FREEZE 2026-09-06** — vẫn hiệu lực. Chỉ nhận **bugfix + Device QA**, không feature mới cho tới khi `CLOSED_TESTING_OK`.
> **Final Hardening Batch xong** (`fix(final-hardening)` + review-fix `4dc6def` — commit local): P0-1..P2-3 đủ 6 bug, **172/172 tests**, analyze 0 issues. Chi tiết: `result10.txt`. Push gộp (hardening + release-engineering) chờ credential mới từ bạn.

## ✅ Đã hoàn thành (gần đây nhất)

- **Feature Close Batch** (2026-09-06): Block A fixes (A1–A9) + Block B features (B1–B5) + Block C docs — commit `c3b6f73` pushed, 159/159 tests, analyze 0 issues.
- **Cleanup prefs-hygiene** (2026-09-07): `f54623f` + `1fff5bc` (xóa ghi dư key rác `flutter.flutter.*`) — đã push (Bước 0 release-engineering), review 0 blocker.
- **QA candidate TEST_ADS=false** (2026-09-07): run **34074951700** ✅ — artifact `release-apk` (chưa chạy Wave 1 trên máy thật).
- **Release Engineering Batch** (2026-09-07, `.plan/prompt_release_engineering.md`):
  - Bước 0: pull + push 3 commit cleanup + xác định workflow thật (`build-debug-apk.yml`).
  - Task 1: `key.properties.example` + gradle signing fallback (không throw khi thiếu keystore).
  - Task 2: CI `Build release AAB` + `Upload AAB artifact` (tái dùng input `test_ads`, giữ APK steps).
  - Task 3: PAT rời khỏi remote URL (token-scan sạch; revoke là việc user).
  - Task 4: decode-keystore step từ secrets + checklist.md.
  - Review sau khi làm xong → fix `e1a0060` (gate `if: secrets.*` không đáng tin → gate trong script qua env).
  - Gate: analyze 0 issue, 159/159 tests; build thật = CI (local không build theo chỉ định; `/home` 95% full + symlink `~/.gradle` hỏng).
- **Final Hardening Batch** (2026-09-07, `.plan/prompt_final_hardening_batch.md`):
  - P0-1: snapshot content-only (không lưu/không restore WidgetConfig → hết phantom config).
  - P1-1: reorder bị disable + guard khi search/favorites filter active (không corrupt `order` collection).
  - P1-2: daily pin lưu `daily_item_id` — giữ ổn định trong ngày khi delete/reorder; xóa item bị pin → chọn lại giữ nguyên `daily_date`; Kotlin advance ngày mới clear id stale; onDeleted/onRestored dọn key mới.
  - P1-3: widget setup rollback (`unbindWidgetConfig`) khi bước sau `createWidgetConfig` fail + snackbar lỗi.
  - P2-1: `duplicateCollection` copy `author`.
  - P2-2: dead `widget_config_screen.dart` + `widget_preview.dart` — đã xóa từ trước (verify 0 ref, không import gãy).
  - P2-3: AddWidgetGuideScreen probe support thay vì auto-request pin khi mở màn.
  - Gate: **170/170** (159 + 11 mới), analyze 0 issue — commit local `fix(final-hardening)`.

## 🔴 Gấp nhất (chặn CLOSED_TESTING / Production)

1. **Cấu hình credential mới để push** (SSH key hoặc fine-grained PAT) → **push gộp**: `fix(final-hardening)` + `70deddb` + `e1a0060` → dispatch CI. Lần dispatch đầu này là **phép kiểm chứng cuối** của signing/AAB config (chưa từng chạy qua build thật) + lần đầu build code hardening (Kotlin daily_item_id).
2. **Revoke PAT cũ** trên GitHub Settings → Developer settings (đã rời remote URL nhưng vẫn còn hiệu lực).
3. **Tải QA candidate + Device QA Wave 1 (A1–A6) trên Device A** — tôi không có thiết bị thật:
   - `gh run download 34074951700 -n release-apk` (hoặc tải từ trang Actions) → cài lên Device A.
   - Ghi model + Android version vào `.plan/device_qa_run_sheet.md`; chạy A1–A6 theo run sheet.
   - Gate cứng: **Wave 1 PASS** → mở Wave 2–6. Báo từng case → tôi triage FAIL, fix blocker, re-run.

## 🟡 Sau khi Wave 1 PASS

4. **Wave 2–6** theo run sheet:
   - Wave 2: B1 reboot / B2 force-stop / B3 update (cần build mới — signing debug-key CI có thể chặn cài đè; đó là lỗi hạ tầng signing, đã có config thật sau khi bạn làm keystore).
   - Wave 3: C1 rewarded-unlock-24h (real ad units), C2 no-fill, C3/C4 expiry, H1/H2 banner.
   - Wave 4: D1–D2 share, E1–E4 backup (gồm case mới **uninstall → reinstall → restore** theo plan9_final.md mục 2).
   - Wave 5: F1–F5 rotation + G1–G2 OEM (Device B Samsung/Xiaomi).
   - Wave 6: SHOULD I1–I5 (không block — ghi risk).
5. **Release prep:** tạo keystore + điền `android/key.properties` local + 4 GitHub secrets → AAB ký thật; version bump; verify Privacy URL live.

## 🟢 Đã xong gần đây (không còn pending)

- ~~Commit batch~~ — ✅ `c3b6f73` pushed
- ~~Build QA candidate TEST_ADS=false~~ — ✅ run 34074951700
- ~~Review batch sau commit~~ — ✅ 0 blocker (result8.txt)
- ~~Xóa ghi registry dư (key rác flutter.flutter.)~~ — ✅ `f54623f` + `1fff5bc`, đã push
- ~~AAB build step trong CI~~ — ✅ `70deddb` (Task 2)
- ~~Release signing config~~ — ✅ `70deddb` (Task 1, fallback không break build)
- ~~Dọn PAT khỏi remote URL~~ — ✅ Task 3 + push 3 commit cleanup trước đó
- ~~Final Hardening Batch (P0-1..P2-3)~~ — ✅ commit local `fix(final-hardening)` (result10.txt); chưa push (gộp với release-engineering)

## ❓ Cần hỏi lại bạn (answer trước khi làm tiếp)

1. **Credential mới để push gộp 4 commit** (`fix(final-hardening)` + docs + `70deddb` + `e1a0060`): bạn muốn tạo SSH key hay fine-grained PAT? Tôi hướng dẫn từng bước.
2. **Version bump**: trước closed testing / production, version là bao nhiêu (vd 1.0.0 → 1.0.1 hoặc 1.1.0)?
3. **Keystore**: bạn tự tạo theo hướng dẫn trong checklist.md, hay cần tôi viết hướng dẫn chi tiết hơn (keytool + base64 encode + điền secrets)?
4. **Privacy URL live**: tôi verify `https://hoangsoft90.github.io/QuoteWidget/privacy.html` giúp, hay bạn đã check?

## 🧹 Việc tôi làm được ngay khi bạn ready

- Hướng dẫn tạo SSH key/fine-grained PAT + push gộp hardening + release-engineering + theo dõi CI (kiểm chứng AAB + build code hardening lần đầu).
- Hướng dẫn keytool + 4 secrets từng bước.
- Verify privacy URL live → ghi vào features.md.
- Hướng dẫn từng bước Wave 1 trên điện thoại của bạn (case A1→A6 lần lượt, tôi triage kết quả).
- Sau QA PASS: cập nhật run sheet verdict + features_final.md badge + chuẩn bị release notes.

Trước tiên: **cấu hình credential → push gộp (hardening + release-engineering) → dispatch CI**, đồng thời **tải APK run 34074951700 → cài Device A → chạy Wave 1**. Không tự ý làm thay các bước cần user (credential, keystore, device).
