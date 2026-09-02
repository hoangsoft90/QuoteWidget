# Spec: Live Preview

## Purpose
Show users exactly how their widget will look on the home screen before they add it.

## Layout
- Container sized to match actual widget dimensions (small or medium)
- Displays current item text from the selected collection
- Applies all appearance settings in real-time
- Updates immediately when any setting changes

## Content
- Shows first item from the selected collection (or current item if already configured)
- For medium size: shows text + "[Author]" below (if author exists)
- For small size: shows text only

## States
- **No collection selected**: "Select a collection to preview"
- **Empty collection**: "Add some content to this collection."
- **Normal**: displays item with current appearance settings

## Implementation
- Use Flutter Container with decorations matching widget appearance
- Simulate widget dimensions (small: ~110dp x 110dp, medium: ~250dp x 110dp)
- Update preview on every settings change (no debounce needed for simple previews)
- Position preview prominently at top of configuration screen

## Accuracy
- Preview must match actual widget appearance as closely as possible
- Font size, colors, alignment must be identical
- Text truncation behavior should match widget (ellipsis for overflow)
