# Device QA Gate (Phase 4)

## Why

Phase 0–3 correctness + features are implemented and unit-tested (138 tests, analyze 0 issues). Before Closed Testing / Production the app must pass the device QA acceptance gate (`.plan/device_qa_acceptance.md`). The agent has no physical device, so this change prepares everything a human tester needs and removes the one blocker that prevents QA from running with **production ad units** (CI only builds `TEST_ADS=true` release APKs, but acceptance cases C1/H1 require `TEST_ADS=false`).

## What Changes

1. **CI (build-debug-apk.yml):** add a `workflow_dispatch` input `test_ads` (default `true`) wired into the release-APK step via `--dart-define=TEST_ADS=<input>`. Push-triggered builds keep the current behavior (test ads); a manual dispatch with `test_ads=false` produces the production-ads QA candidate — without ever building locally.
2. **Run sheet:** create `.plan/device_qa_run_sheet.md` — build metadata, every MUST acceptance case (A1–A6, B1–B3, C1–C4, D1–D2, E1–E4, F1–F5, G1–G2, H1–H2) and SHOULD (I1–I5) with Preconditions/Steps/Expected + ☐ PASS/FAIL/N/A tick boxes, per-case triage hints (suspected file), sign-off table.
3. **Docs sync:** `.plan/features_final.md` statuses updated to match shipped reality (verified against code) so the F4/F5 = MUST decision is traceable.

## Out of Scope

- No feature work, no architecture change, no refactor.
- No fake PASS on a device — agent only prepares; a human tester runs the waves.
- No local builds (project rule: GH Actions only).
