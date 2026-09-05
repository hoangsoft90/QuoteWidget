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
- [x] `tasks.md` written (this file)

## 4. CI: QA candidate build path (agent)
- [x] Add `workflow_dispatch` input `test_ads` (default `true`) to `.github/workflows/build-debug-apk.yml`
- [x] Release APK step: `flutter build apk --release --no-pub --dart-define=TEST_ADS=${{ inputs.test_ads || 'true' }}`
- [x] Commit `dbd4481` + push; dispatch with `test_ads=false` → run 33972687792
- [x] Verify run green; `release-apk` artifact present (30.6 MB)
- [x] PASS evidence: run 33972687792 success + workflow diff

## 5. Run sheet (agent)
- [x] `.plan/device_qa_run_sheet.md` created: metadata + all MUST cases + SHOULD cases + tick boxes + triage hints + sign-off
- [x] Verdict line written — unchecked until human runs waves

## 6. Human tester handoff
- [x] Output summary: build path/artifact, commit hash, TEST_ADS flag, verdict status, Wave 1 instructions for Device A (delivered in chat)
