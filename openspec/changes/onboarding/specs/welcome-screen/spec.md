# Spec: Welcome Screen

## Layout
- Full-screen welcome page
- App logo/icon at top
- App name "Your Words" with tagline
- Two prominent buttons:
  1. "Start with Sample" (primary, highlighted)
  2. "Add Your Own" (secondary)
- Small "Skip" link at bottom

## "Start with Sample" Flow
1. Create 3 sample collections with pre-written content
2. Create a WidgetConfig for the first collection
3. Show success message: "Sample content added!"
4. Guide to add widget (requestPinAppWidget or fallback guide)
5. Navigate to home screen after widget added

## "Add Your Own" Flow
1. Navigate to create collection screen
2. User creates first collection
3. User adds first item
4. Guide to add widget
5. Navigate to home screen after widget added

## "Skip" Flow
1. Mark onboarding as complete (SharedPreferences)
2. Navigate to home screen
3. User can add content and widgets later

## Progress Indicator
- Show steps: "1. Add Content → 2. Customize → 3. Add Widget"
- Highlight current step
- Update as user progresses

## First Launch Detection
- Check SharedPreferences for `onboarding_complete` flag
- If not set: show onboarding screen
- If set: go directly to home screen
- Flag set when onboarding completes or user skips
