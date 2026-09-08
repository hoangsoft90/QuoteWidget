# Google Play Console — Store Listing & Launch Checklist

> **App:** Your Words — Quote & Reminder Widget
> **Package:** `com.quotewidget.quotewidget` · **Version:** 1.0.0+1
> **Developer:** Haiba Software · **Contact:** haibasoftware@gmail.com
> **Privacy Policy URL (hosted):** https://hoangsoft90.github.io/QuoteWidget/
> **Suggested Play listing:** https://play.google.com/store/apps/details?id=com.quotewidget.quotewidget

---

## 1. Main Store Listing

### App Name (≤ 30 chars)

```
Your Words: Quote Widget
```
*(24 characters — keyword front-loaded, brand kept)*

### Short Description (≤ 80 chars)

```
Quote & reminder widgets on your home screen. Your words, always in view.
```
*(74 characters)*

### Full Description (≤ 4000 chars, ASO)

```
💬 YOUR WORDS — QUOTES, VOCABULARY & REMINDERS ON YOUR HOME SCREEN

Turn your home screen into a daily source of motivation. Your Words puts a
beautiful, always-up-to-date widget on your Android home screen that shows
your own quotes, vocabulary, affirmations, or reminders — one tap, next word.

⭐ WHY YOU'LL LOVE IT

✅ Home Screen Widget — your quotes live on your home screen, no app opening
✅ One-Tap Next — tap the widget to move to the next quote instantly
✅ Daily Mode — one fresh quote picked for you every day
✅ Offline First — all your content stays on your phone, no account needed
✅ Multiple Widgets — different collections on different widgets (Pro)
✅ Collections & Favorites — organize quotes, vocab, notes into collections
✅ Search & Filter — find any quote in seconds
✅ Share as Image — turn any quote into a beautiful card to share
✅ Backup & Restore — keep your words safe, move to a new phone
✅ Private by Design — no account, no tracking, your data stays local

🎯 MADE FOR

• Learners building vocabulary one word at a time
• Anyone who loves quotes, affirmations & daily motivation
• Writers and thinkers capturing sparks of ideas
• Busy people who want reminders where their eyes already are

🚀 HOW IT WORKS

1. Create a collection and add your words
2. Add the Quote Widget to your home screen
3. Tap the widget — your next word appears
4. Come back every day for your daily pick

💎 UNLOCK PRO

Watch a short rewarded video to unlock Pro free for 24 hours:
• Unlimited home screen widgets
• One widget per collection
• Daily Mode rotation

📱 SIMPLE, FAST & PRIVATE

Your Words is offline-first: your quotes, notes and settings live only on
your device. No sign-up, no account, no unnecessary permissions.

Download Your Words now and put your words where you'll see them —
every single day.
```
*(≈ 1,900 characters — well under the 4,000 limit; expandable later)*

---

## 2. Store Settings

| Setting | Value |
|---|---|
| **Category** | `Personalization` |
| **Contains ads** | Yes |
| **In-app purchases** | No (Pro unlock is ad-rewarded, no payments) |

**5 Tags (pick in order):**

1. `Quotes` — primary use case
2. `Widgets` — the core mechanic
3. `Motivation` — emotional benefit
4. `Productivity` — reminders/notes use case
5. `Vocabulary` — language-learning use case

---

## 3. Graphics & Assets

| Asset | Size | File |
|---|---|---|
| App Icon | 512 × 512 PNG (32-bit) | `store_assets/icon.png` ✅ |
| Feature Graphic | 1024 × 500 PNG/JPG | `store_assets/feature_graphic.png` ✅ |
| Phone Screenshots | 16:9 or 9:16, min 320 px, max 3840 px | capture on device (below) |

### Screenshot ideas (4 shots, phone 1080×1920)

1. **Hero — widget in action**
   Real home screen, widget showing a short quote, wallpaper visible.
   Caption overlay: `Your words, on your home screen`
2. **Tap → next quote**
   Same screen, second frame with the next quote + a tap hint circle on the widget.
   Caption: `One tap — next quote`
3. **Collections screen**
   The app's collection list with a colorful example collection (Quotes, Vocabulary, Affirmations).
   Caption: `Organize your words into collections`
4. **Share as image / Daily mode**
   The share-card screen or a Daily Mode widget.
   Caption: `Share beautiful quote cards` / `A fresh daily pick`

### Feature Graphic (1024 × 500) — design brief

- **Background:** deep gradient `#6750A4 → #4C3A80` (brand purple), subtle diagonal light sweep
- **Center-left:** big title **"Your Words"** (white, bold), subtitle below:
  `Quotes · Vocabulary · Reminders — on your Home Screen`
- **Right side:** a small mockup of the widget card (rounded white card, quote text + progress dots) tilted 6°
- **Bottom-right corner:** small badge `One tap → next quote`
- **Rule:** keep all text inside a 40 px safe margin; no small text (must read at thumbnail size)

> ✅ Generated per this brief: `store_assets/feature_graphic.png`

### Icon (512 × 512) — design brief

- Rounded-square tile, brand purple gradient `#6750A4 → #4C3A80`
- Center: large white quotation mark `❝` (the app's visual identity)
- No text (unreadable at small sizes), full-bleed, no rounded-corner mask (Play applies its own)

> ✅ Generated per this brief: `store_assets/icon.png` (scaled from the app's launcher icon)

---

## 4. App Content Checklist (Play Console)

- [ ] **Privacy Policy** — paste URL: `https://hoangsoft90.github.io/QuoteWidget/`
      *(page is live on GitHub Pages; contact email haibasoftware@gmail.com is on the page)*
- [ ] **App Access** — "All functionality is available without special access" (no login, no gated areas)
- [ ] **Ads** — declare: **Yes, contains ads** (AdMob banner + interstitial + rewarded)
- [ ] **Data Safety form**
  - Data collected: **none by the developer** (all user content is local-only)
  - Third-party SDKs declared: AdMob (advertising, device identifiers — per Google's policy), Sentry (crash diagnostics)
  - Data shared: as processed by AdMob/Sentry under their policies
  - All data **encrypted in transit**: yes (HTTPS)
  - Users can request data deletion: yes — uninstall removes everything locally; email contact for other requests
- [ ] **Content Rating** — complete IARC questionnaire (expected: **Everyone / 3+**; no violence, no user-generated sharing between users, no gambling)
- [ ] **Target Audience** — not child-directed; age: 13+ recommended
- [ ] **News app** — No
- [ ] **COVID-19 apps** — No
- [ ] **Government apps** — No
- [ ] **Financial features** — None
- [ ] **Health apps** — None
- [ ] **Store listing experiment** — optional, skip for first submission
- [ ] **Main listing text/graphics** — copy from this file + upload `icon.png`, `feature_graphic.png`, 4 screenshots
- [ ] **App category** — Personalization + 5 tags above
- [ ] **Contact details** — email `haibasoftware@gmail.com`, website optional (privacy page URL may be used)
- [ ] **Release to testing** — upload AAB (CI artifact `release-aab`, must be signed with release keystore) → Closed Testing track
- [ ] **Countries** — start worldwide, adjust after Closed Testing feedback

### Pre-upload gates (from repo state)

- [ ] Push the 4 unpushed local commits (needs your GitHub credential on this machine)
- [ ] Configure release keystore secrets in GitHub (`RELEASE_KEYSTORE_BASE64`, `RELEASE_STORE_PASSWORD`, `RELEASE_KEY_ALIAS`, `RELEASE_KEY_PASSWORD`) → CI produces a **signed AAB** Play accepts
- [ ] Dispatch CI with `test_ads=false` for the final QA candidate and run Device QA Waves
