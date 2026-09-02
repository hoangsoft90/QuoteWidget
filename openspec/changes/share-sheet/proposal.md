# Proposal: Share Sheet Quick Add

## What
Implement the ability to receive shared text from other apps (Reddit, Twitter, news apps) and save it directly as items in a collection. This is a P0.5 feature with high value/code ratio.

## Why
Share Sheet Quick Add is the highest value/code ratio feature. It enables the core loop: users find content in other apps → share to Your Words → content appears on home screen widget. This drives retention and daily usage.

## Scope
- Receive shared plain text via Android share intent
- Save shared text as new item in selected collection
- Handle URL-only shares (open app for user to confirm/add manually)
- Show collection picker when receiving shared text
- No scraper/web parsing (MVP only handles plain text)

## Non-goals
- URL scraping/preview (P1 feature)
- Image sharing (P1 feature)
- Batch share processing (P1 feature)
- iOS share extension (separate widget change)

## Success Criteria
- Can share text from Reddit/Twitter/news app to Your Words
- Shared text appears as new item in selected collection
- URL-only shares open app for manual input
- Collection picker appears when multiple collections exist
- Single collection: shared text goes directly to it
- No crash on invalid share data
