# Device QA Gate — Tasks

## 1. Preflight (agent, done)
- [x] `flutter analyze` → 0 issues
- [x] `flutter test` → 138/138 pass
- [x] Dead code: `source/` gone; `widget_config_screen.dart` + `widget_preview.dart` deleted, 0 references

## 2. Docs sync (agent)
- [x] `.plan/features_final.md` — statuses match code (Phase 1–2B shipped → F4/F5 MUST)
- [ ] Evidence: `git diff .plan/features_final.md` shows only status edits, no feature claims

## 3. OpenSpec change scaffold
- [x] `proposal.md` written
- [ ] `tasks.md` written (this file)

## 4. CI: QA candidate build path (agent)
- [ ] Add `workflow_dispatch` input `test_ads` (default `true`) to `.github/workflows/build-debug-apk.yml`
- [ ] Release APK step: `flutter build apk --release --no-pub --dart-define=TEST_ADS=${{ inputs.test_ads }}`
- [ ] Commit + push; trigger `workflow_dispatch` with `test_ads=false`
- [ ] Verify run green; `release-apk` artifact present
- [ ] PASS evidence: CI run URL + workflow diff

## 5. Run sheet (agent)
- [ ] `.plan/device_qa_run_sheet.md` created: metadata + all MUST cases + SHOULD cases + tick boxes + triage hints + sign-off
- [ ] Verdict line written (CLOSED_TESTING_OK only after human runs waves — provisional: PRE_QA)

## 6. Human tester handoff
- [ ] Output summary: build path/artifact, commit hash, TEST_ADS flag, verdict status, Wave 1 instructions for Device A
