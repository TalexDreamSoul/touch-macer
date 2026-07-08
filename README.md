<p align="center">
  <img src="https://ld.xh.do/ld-badge.svg" alt="认可 linux.do" width="480">
</p>

# TouchMacer

TouchMacer is a native macOS status bar clock app built with AppKit, SwiftUI, EventKit, and Foundation.

## Features

- Live status bar clock that can show multiple time zones.
- Overview popover with world clocks, current system time zone, and upcoming events.
- Sidebar settings window for system/custom time zones, Calendar filters, appearance preferences, app info, and GitHub update checks.
- EventKit Calendar integration for iCloud/local calendars configured in macOS Calendar.
- Calendar picker for all calendars or selected calendars.
- Appearance modes: system, light, dark, or automatic by a selected time zone, with an optional switch to apply the result to macOS system Light/Dark appearance.
- Local settings persistence through `UserDefaults`.

## Build

```bash
swift build
```

## Build App Bundle

Calendar permission prompts require usage descriptions in an app bundle. Use:

```bash
chmod +x scripts/build-app.sh
scripts/build-app.sh
open .build/app/TouchMacer.app
```

## Notes

- iCloud access is provided through macOS Calendar/EventKit; the app does not store iCloud credentials.
- Automatic appearance uses light mode from 07:00 to 19:00 in the selected reference time zone, and dark mode otherwise.
- System-level appearance switching requires macOS Automation permission and is disabled until you enable it in Settings. When enabled, TouchMacer periodically corrects macOS if another automatic schedule changes Light/Dark mode away from the selected setting.
