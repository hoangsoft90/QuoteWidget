# Design: Onboarding

## Screen Architecture
- **OnboardingScreen**: main welcome page with two options
- **AddWidgetGuideScreen**: widget addition guide (from android-widget change)
- **HomeScreen**: destination after onboarding completes

## State Management
- SharedPreferences for onboarding completion flag
- StorageService for creating sample content
- Navigator for flow control

## Flow Diagram
```
App Launch
  ↓
Check onboarding_complete flag
  ↓
[Not complete] → OnboardingScreen
  ↓
[Complete] → HomeScreen

OnboardingScreen
  ├→ "Start with Sample"
  │    ↓
  │  Create sample collections
  │    ↓
  │  Create WidgetConfig
  │    ↓
  │  Show Add Widget Guide
  │    ↓
  │  Widget added → HomeScreen
  │
  ├→ "Add Your Own"
  │    ↓
  │  Navigate to Create Collection
  │    ↓
  │  User creates collection + items
  │    ↓
  │  Show Add Widget Guide
  │    ↓
  │  Widget added → HomeScreen
  │
  └→ "Skip"
       ↓
     Set onboarding_complete flag
       ↓
     HomeScreen
```

## Sample Content Creation
- Use StorageService to create collections and items
- Create 3 collections with 6-8 items each
- Create one WidgetConfig for first collection
- All done synchronously (fast, no loading needed)

## Progress Tracking
- Simple step indicator at top of screen
- Steps: "1. Content → 2. Widget → 3. Done!"
- Highlight current step with color/animation
- Update as user progresses through flow

## Key Design Decisions
1. **Two clear options**: "Start with Sample" is primary (larger, colored), "Add Your Own" is secondary (smaller, outlined)
2. **Sample content is pre-written**: no user input needed for fastest activation
3. **Skip option available**: don't force onboarding, let users explore
4. **Widget guide integrated**: same AddWidgetGuideScreen from android-widget change
5. **Single flag for completion**: simple SharedPreferences boolean
