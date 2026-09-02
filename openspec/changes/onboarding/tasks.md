# Tasks: Onboarding

## Task 1: Create Onboarding Screen
- Create `lib/screens/onboarding_screen.dart`
- Implement welcome message with app branding
- Implement "Start with Sample" button (primary style)
- Implement "Add Your Own" button (secondary style)
- Implement "Skip" link at bottom
- Implement progress indicator

## Task 2: Implement Sample Content Creation
- Create `lib/services/sample_data_service.dart`
- Implement `createSampleCollections()` method
- Create 3 sample collections with items
- Create WidgetConfig for first collection
- Return created collections for navigation

## Task 3: Implement "Start with Sample" Flow
- On button tap: create sample content
- Show success message
- Navigate to Add Widget Guide
- After widget added: navigate to Home Screen
- Set onboarding_complete flag

## Task 4: Implement "Add Your Own" Flow
- On button tap: navigate to create collection screen
- Guide user through creating first collection
- Guide user through adding first item
- Navigate to Add Widget Guide
- After widget added: navigate to Home Screen
- Set onboarding_complete flag

## Task 5: Implement "Skip" Flow
- On skip tap: set onboarding_complete flag
- Navigate to Home Screen
- User can add content and widgets later from home screen

## Task 6: First Launch Detection
- Check SharedPreferences for onboarding_complete flag in main.dart
- If not set: show OnboardingScreen
- If set: show HomeScreen
- Handle flag properly across app lifecycle

## Task 7: Integrate with Navigation
- Add routes for onboarding flow
- Handle back navigation during onboarding (stay on screen)
- Ensure smooth transition to home screen after completion
- Test complete flow from launch to first widget
