# Tasks: Widget Customization

## Task 1: Create Widget Config Screen
- Create `lib/screens/widget_config_screen.dart`
- Implement AppBar with title "Customize Widget"
- Implement collection selector dropdown
- Implement theme preset buttons (Light/Dark/Custom)
- Implement font size slider
- Implement text color picker
- Implement background color picker
- Implement alignment selector
- Implement size selector (Small/Medium)

## Task 2: Implement Live Preview
- Create `lib/widgets/widget_preview.dart`
- Implement simulated widget container with correct dimensions
- Apply appearance settings to preview in real-time
- Show current item text from selected collection
- Handle empty states (no collection, empty collection)

## Task 3: Implement Color Picker
- Create simple color picker dialog
- Include preset colors for text and background
- Implement custom color selection via color wheel
- Show current color selection

## Task 4: Implement Theme Presets
- Define Light theme (white bg, dark text)
- Define Dark theme (dark bg, light text)
- Implement Custom theme (preserves user selections)
- Switching themes overrides current settings

## Task 5: Save Configuration
- Auto-save changes to WidgetConfig model
- Sync changes to Android widget via WidgetService
- Update widget immediately when configuration changes
- Handle save errors gracefully

## Task 6: Integrate with Navigation
- Add route to widget config screen
- Pass WidgetConfig id as argument
- Handle back navigation with unsaved changes (if any)
- Add entry point from collection detail screen or home screen
