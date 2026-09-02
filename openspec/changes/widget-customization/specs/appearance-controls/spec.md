# Spec: Appearance Controls

## Theme Presets
- **Light**: white background, dark text, default font sizes
- **Dark**: dark background, light text, default font sizes
- **Custom**: user-defined colors and sizes

## Font Size Control
- Slider with range: 12.0 to 32.0
- Default: 18.0
- Step: 1.0
- Show current value label

## Text Color Control
- Color picker button showing current color
- Tap to open color picker dialog
- Preset colors: black, white, gray, red, blue, green, orange, purple
- Custom color option via color wheel

## Background Color Control
- Color picker button showing current color
- Tap to open color picker dialog
- Preset colors: white, light gray, dark gray, black, beige, light blue, light green
- Custom color option via color wheel

## Text Alignment
- Three buttons: Left, Center, Right
- Center is default
- Visual indicator for selected alignment

## Widget Size
- Two buttons: Small, Medium
- Small shows text only
- Medium shows text + optional author line
- Visual indicator for selected size

## Save Behavior
- Changes save automatically (no save button needed)
- Configuration persists in WidgetConfig model
- Widget updates immediately when configuration changes
