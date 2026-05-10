# Architecture

Focus Timer is a native macOS app built with SwiftUI and small AppKit bridges for
window behavior, menu bar integration, sounds, and notifications.

## Project Layout

- `focus-timer/focus_timerApp.swift`
  - App entry point.
  - Creates shared timer state, saved timer storage, appearance handling, and app
    settings.
  - Defines the main window scene and the floating timer window scene.

- `focus-timer/ContentView.swift`
  - Main screen.
  - Owns the main timer layout, header buttons, disk, editable time text,
    controls, saved timers overlay, settings overlay, completion handling, and
    stop-ringing UI.

- `focus-timer/FocusTimerClock.swift`
  - Core countdown state.
  - Handles duration, remaining time, start, pause, reset, ticking, completion,
    and the one-hour maximum.

- `focus-timer/TimerDiskView.swift`
  - Circular disk visualization.
  - Handles drawing the remaining-time disk and drag gestures for changing the
    timer value.

- `focus-timer/TimerStore.swift`
  - Persists saved timers in `UserDefaults`.
  - Maintains pinned and recent timers.
  - Sorts pinned timers by duration and recent timers by last-used time.

- `focus-timer/SavedTimersOverlayView.swift`
  - Saved timers overlay.
  - Displays pinned and recent timers in a two-column grid.
  - Handles selecting, pinning, removing, and clearing recent timers.

- `focus-timer/SettingsOverlayView.swift`
  - Settings screen.
  - Contains disk color, custom color, appearance mode, completion sound,
    notifications, menu bar, and floating timer settings.

- `focus-timer/FloatingTimerView.swift`
  - Floating timer window UI and AppKit window configuration.
  - Shows a read-only disk and time text.
  - Configures always-on-top behavior, opacity, transparent title bar,
    click-through mode, and draggable top area.

- `focus-timer/FocusTimerMenuBarController.swift`
  - AppKit `NSStatusItem` controller.
  - Builds the menu bar menu and supports normal icon or remaining-time icon
    modes.
  - Opens the main window, floating timer, settings, and instant-start timers.

- `focus-timer/FocusTimerWindowCommands.swift`
  - Window and app coordination helpers.
  - Handles app delegate behavior, notification delegate behavior, window lookup,
    reopen behavior, and command routing.

- `focus-timer/FocusTimerModels.swift`
  - Shared model types and helpers.
  - Includes theme colors, appearance mode, sound model, sound playback,
    notification support, timer formatting, and compatibility migration.

- `focus-timer/FocusTimerControls.swift`
  - Shared small controls such as circular icon buttons and overlay headers.

## Where to Change Features

Change the timer limit or default duration in:

- `focus-timer/FocusTimerClock.swift`
- `focus-timer/FocusTimerModels.swift` for related formatting or parsing behavior

Change the disk drawing or drag interaction in:

- `focus-timer/TimerDiskView.swift`

Change the main screen layout, header, editable time text, or timer controls in:

- `focus-timer/ContentView.swift`
- `focus-timer/FocusTimerControls.swift` for shared button/header components

Change pinned or recent timer behavior in:

- `focus-timer/TimerStore.swift`
- `focus-timer/SavedTimersOverlayView.swift`

Change settings UI in:

- `focus-timer/SettingsOverlayView.swift`

Add a new persisted setting by updating:

- `focus-timer/focus_timerApp.swift` if the setting is needed at app or window level
- `focus-timer/ContentView.swift` if the main screen needs the setting
- `focus-timer/SettingsOverlayView.swift` to expose the setting
- `focus-timer/FocusTimerModels.swift` if the setting needs a model enum or helper

Change appearance mode behavior in:

- `focus-timer/focus_timerApp.swift`
- `focus-timer/FocusTimerModels.swift`
- `focus-timer/SettingsOverlayView.swift`

Change disk color presets or custom color behavior in:

- `focus-timer/FocusTimerModels.swift`
- `focus-timer/SettingsOverlayView.swift`
- `focus-timer/TimerDiskView.swift` if the rendered disk behavior changes

Change completion sounds in:

- `focus-timer/FocusTimerModels.swift`
- `focus-timer/SettingsOverlayView.swift`

Change completion notifications in:

- `focus-timer/FocusTimerModels.swift`
- `focus-timer/FocusTimerWindowCommands.swift`
- `focus-timer/ContentView.swift`

Change floating timer behavior in:

- `focus-timer/FloatingTimerView.swift`
- `focus-timer/focus_timerApp.swift`
- `focus-timer/FocusTimerWindowCommands.swift`

Change menu bar behavior in:

- `focus-timer/FocusTimerMenuBarController.swift`
- `focus-timer/focus_timerApp.swift`

Change instant-start timer selection in the menu bar in:

- `focus-timer/FocusTimerMenuBarController.swift`
- `focus-timer/TimerStore.swift` for pinned and recent timer ordering

Change app icons or bundled assets in:

- `focus-timer/AppIcon.icon`
- `focus-timer/Assets.xcassets`
- `focus-timer.xcodeproj/project.pbxproj` if build settings or asset references
  need to change

## Persistence

Most settings are stored with `@AppStorage` or direct `UserDefaults` access.
Important keys include:

- `focusTimer.storedTimers`
- `focusTimer.accentColorID`
- `focusTimer.customAccentColorHex`
- `focusTimer.appearanceModeID`
- `focusTimer.soundEnabled`
- `focusTimer.completionSoundID`
- `focusTimer.customCompletionSoundName`
- `focusTimer.customCompletionSoundFileName`
- `focusTimer.completionNotificationEnabled`
- `focusTimer.menuBarIconEnabled`
- `focusTimer.menuBarIconStyleID`
- `focusTimer.floatingTimerOpacity`
- `focusTimer.floatingTimerClickThrough`

Custom sound files are copied into the user's Application Support directory:

```text
~/Library/Application Support/Focus Timer/Sounds/
```

## Window Model

The app has two primary windows:

- Main window: full timer controls, saved timers, and settings.
- Floating timer window: always-on-top read-only timer display.

The floating timer can remain open when the main window is closed. Menu bar
actions and Dock reactivation are coordinated through the window command helpers
so users can restore the main window or open settings.

## Build and Verification

Use this command for a local build check:

```sh
xcodebuild \
  -project focus-timer.xcodeproj \
  -scheme focus-timer \
  -configuration Debug \
  -sdk macosx \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

After UI or behavior changes, manually verify:

- Timer editing, dragging, start, pause, reset, and completion
- Stop ringing behavior after completion
- Built-in sound selection and custom sound import/removal
- Completion notification permission and notification action
- Pinned and recent timer sorting/removal
- Floating timer opening, closing, opacity, and click-through behavior
- Menu bar icon enablement and icon style
- System, dark, and white appearance modes

## Platform Notes

The app targets macOS 13.0 or later. SwiftUI handles most UI, while AppKit is
used where macOS-specific control is needed, including window customization,
status items, native sounds, and notification delegation.
