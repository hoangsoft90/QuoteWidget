# Design: Widget Customization

## Screen Layout
```
┌─────────────────────────────┐
│ AppBar: "Customize Widget"  │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │   Live Preview Widget   │ │
│ │   (simulated widget)    │ │
│ └─────────────────────────┘ │
├─────────────────────────────┤
│ Collection: [dropdown]      │
├─────────────────────────────┤
│ Theme: [Light] [Dark] [Custom]│
├─────────────────────────────┤
│ Font Size: [====|====] 18   │
├─────────────────────────────┤
│ Text Color: [●] Background: [●]│
├─────────────────────────────┤
│ Alignment: [L] [C] [R]     │
├─────────────────────────────┤
│ Size: [Small] [Medium]      │
└─────────────────────────────┘
```

## State Management
- WidgetConfig state managed by StatefulWidget
- Changes update both preview and WidgetConfig model
- Auto-save on every change (no explicit save button)

## Color Picker
- Use simple color picker dialog with preset colors + custom option
- No external dependency needed (Flutter has basic color picker)

## Preview Widget
- Custom widget that simulates RemoteViews appearance
- Uses same fonts, colors, and sizing as actual widget
- Positioned at top of screen for easy reference

## Theme Preset Logic
- Light: white bg (#FFFFFF), dark text (#000000), default sizes
- Dark: dark bg (#1A1A1A), light text (#FFFFFF), default sizes
- Custom: preserves current user selections
- Switching to preset overrides all custom settings
