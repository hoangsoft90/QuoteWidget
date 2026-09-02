# Proposal: Widget Customization

## What
Implement the widget configuration screen where users can customize the appearance of their widgets: themes, font size, text color, background color, text alignment, and widget size. Include a live preview that updates as changes are made.

## Why
Customization is a key differentiator and part of the core loop. Users need to make widgets match their home screen aesthetic. The live preview ensures they know exactly what they'll get.

## Scope
- Widget configuration screen with appearance controls
- Theme presets (3 basic themes: light, dark, custom)
- Font size slider
- Text color picker
- Background color picker
- Text alignment selector (left, center, right)
- Widget size selector (small, medium)
- Live preview widget that updates in real-time
- Save configuration to WidgetConfig model

## Non-goals
- Photo background (P1 feature)
- Custom font upload (P1 feature)
- Multiple widget Pro feature gating (P0.5)

## Success Criteria
- Can select a theme preset and see preview update
- Can adjust font size and see preview update
- Can change text color and background color
- Can change text alignment
- Can switch between small and medium widget sizes
- Configuration saves correctly to WidgetConfig
- Preview accurately represents actual widget appearance
