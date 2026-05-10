# Focus Timer

Focus Timer is a compact macOS countdown timer inspired by the Time Timer visual
style. It shows the remaining time as a circular disk, supports timers up to one
hour, keeps pinned and recent timers, can show a floating read-only timer window,
and includes menu bar controls, appearance settings, custom colors, completion
sounds, and optional completion notifications.

## Requirements

- macOS 13.0 or later
- Xcode with the macOS SDK installed

The app is a native SwiftUI/AppKit macOS app.

## Main Features

- Circular visual countdown up to one hour
- Editable time text
- Pinned and recent timers
- Floating read-only timer window
- Optional click-through floating timer mode
- Menu bar item with configurable icon style
- System, dark, and white appearance modes
- Built-in and custom completion sounds
- Stop ringing control when a timer completes
- Optional completion notification

## Build and Run with Xcode

1. Open `focus-timer.xcodeproj`.
2. Select the `focus-timer` scheme.
3. Select `My Mac` as the run destination.
4. Press `Run`.

The app product name is `Focus Timer`.

## Build from Terminal

For a local Debug build:

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

For a local Release build:

```sh
xcodebuild \
  -project focus-timer.xcodeproj \
  -scheme focus-timer \
  -configuration Release \
  -sdk macosx \
  -derivedDataPath .derivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The built app is created at:

```text
.derivedData/Build/Products/Release/Focus Timer.app
```

## Opening a Downloaded Build on macOS

If you download a release artifact from GitHub:

1. Unzip the downloaded file.
2. Move `Focus Timer.app` to `/Applications`.
3. Control-click or right-click the app and choose `Open`.
4. Click "Open Anyway" at the bottom section of `System Settings -> Privacy & Security`

## App Data

Focus Timer stores user preferences with `UserDefaults`, including recent timers,
pinned timers, appearance mode, selected sound, menu bar settings, and floating
timer settings.

Custom completion sounds are copied into:

```text
~/Library/Application Support/Focus Timer/Sounds/
```

Notification permission is requested by macOS the first time the app needs to
show a completion notification.
