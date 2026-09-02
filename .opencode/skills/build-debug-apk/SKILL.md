---
name: build-debug-apk
description: >
  Build debug APK for quotewidget project using GitHub Actions (Gradle direct, no EAS).
  Use when the user asks to "build apk", "build debug", "deploy to device", "get APK",
  "push and build", or wants to test the app on a real Android device.
---

# Build Debug APK — GitHub Actions

## Project Info

- **Repo:** https://github.com/hoangsoft90/QuoteWidget
- **Branch:** `main`
- **Workflow:** `.github/workflows/build-debug-apk.yml`
- **Token:** Ask user for `gh_token` or use env var `$GH_TOKEN`

## Quick Build (Copy-Paste)

When the user asks to build APK, run these steps:

### 1. Stage, commit, and push code

```bash
cd <project-root>
git add -A
git commit -m "chore: build debug APK

🤖 Generated with Codebuff
Co-Authored-By: Codebuff <noreply@codebuff.com>" || echo "Nothing to commit"
git push origin main
```

### 2. Trigger workflow (if not auto-triggered by push)

```bash
curl -s -X POST \
  -H "Authorization: token $GH_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/hoangsoft90/QuoteWidget/actions/workflows/build-debug-apk.yml/dispatches" \
  -d '{"ref":"main"}'
```

### 3. Check build status

```bash
curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/QuoteWidget/actions/runs?per_page=1" | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
r = d['workflow_runs'][0]
print(f'Status: {r[\"status\"]} | Conclusion: {r[\"conclusion\"]}')
print(f'URL: {r[\"html_url\"]}')
"
```

### 4. Download APK artifact (after build completes)

```bash
# Get latest run ID
RUN_ID=$(curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/QuoteWidget/actions/runs?per_page=1" | \
  python3 -c "import sys,json; print(json.load(sys.stdin)['workflow_runs'][0]['id'])")

# List artifacts
curl -s -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/hoangsoft90/QuoteWidget/actions/runs/${RUN_ID}/artifacts" | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
for a in d.get('artifacts', []):
    print(f'{a[\"name\"]}: {a[\"archive_download_url\"]}')
"

# Download (replace ARTIFACT_URL)
# curl -L -H "Authorization: token $GH_TOKEN" \
#   -o debug-apk.zip "ARTIFACT_URL"
# unzip debug-apk.zip
```

## Workflow Details

- **Flutter version:** 3.29.3 stable
- **Java:** Temurin JDK 17
- **Build command:** `./gradlew assembleDebug --no-daemon` (Gradle 9.3.1, AGP 9.1.0)
- **Output:** `app/build/outputs/flutter-apk/app-debug.apk`
- **Artifacts:** Retained for 7 days

## Important Notes

1. **NO LOCAL BUILDS** — This project does NOT build locally. All builds happen on GitHub Actions.
2. **Never run `flutter build apk` locally** — no Android SDK/Flutter SDK installed locally.
3. **Push to `main` branch** to trigger auto-build via the workflow.
4. **Token must be provided by user** — never hardcode tokens in committed files.
5. **Debug APK uses debug signing** — for testing only, not for Play Store submission.

## Troubleshooting

### Build fails with Gradle version mismatch
- Check `android/gradle/wrapper/gradle-wrapper.properties` for `distributionUrl`
- Check `android/settings.gradle.kts` for AGP version
- Ensure Flutter version in workflow matches project requirements

### Build fails with Kotlin compilation error
- Check Kotlin version in `android/settings.gradle.kts`
- Ensure all Kotlin files compile (run `flutter analyze` first if possible)

### APK not found in artifacts
- Check workflow logs at the Actions tab
- Look for `find app/build/outputs -name "*.apk"` in the workflow output
