# Launch Control Center

A macOS menu bar application for scheduling and executing UDP commands in live show and event production environments. Built by [Lunar Telephone Company](https://lunartelephone.com).

---

## Overview

Launch Control Center (LCC) is a long-running background scheduler that fires pre-configured UDP messages to show control systems — lighting consoles, audio servers, video routers, and other network-enabled devices — on a precise timed schedule. It lives in the menu bar and is designed to remain running throughout a production day without requiring operator attention once configured.

LCC is purpose-built for live events where schedule precision, clear operational logging, and simple failure visibility matter more than feature breadth.

---

## Features

### Actions
- **Show Actions** — Ordered sequences of UDP message steps, each with an optional pre-send delay. Steps can send standard UDP payloads or RFC-3164 syslog-formatted messages.
- **Utility Actions** — App-level sequences that set volume, toggle schedule enable states, trigger other Actions, or send standalone UDP messages.
- Recursive action loops are detected and blocked automatically.
- A per-action runtime cap (2 minutes) prevents runaway sequences.

### Scheduler
- **One-time Events** — Fire an Action at a specific date and time.
- **Recurring Events** — Repeat on selected weekdays (daily, weekdays, weekends, or any combination), with optional end dates.
- **Interval Series** — Repeat within a day at a fixed interval (e.g., every 30 minutes from 09:00 to 17:00).
- Individual occurrences can be removed from a recurring series without affecting the rest.
- Show Actions and Utility Actions can be independently enabled or disabled without deleting the schedule.
- A 10 Hz schedule engine fires Events within a 1-second tolerance window.
- Execution history is retained for 60 days and displayed in the schedule calendar view.

### Volume Control
- Volume slider with configurable output range (dB or arbitrary numeric scale).
- Low / Normal / High presets with configurable levels.
- Mute toggle with last-known-good level memory.
- Volume is broadcast over UDP using a configurable message prefix (e.g., `/cue/selected/level/0/`).

### UDP
- Send to any IPv4 host and port with optional source address binding.
- Broadcast support (`SO_BROADCAST`) per step.
- Built-in diagnostic listener (auto-stops after 10 minutes) for verifying inbound traffic.
- All outbound messages are serialized through a dedicated send queue to preserve step ordering during overlapping Actions.

### Operational Logging
- Writes daily log files to `~/Library/Application Support/Launch Control Center/Logs/`.
- Log files rotate at 5 MB; files older than a configurable retention period (default: 90 days) are pruned at launch.
- INFO / WARNING / ERROR levels.
- Sleep and wake events, Action start/finish, and schedule execution results are all logged.

### System Integration
- Sleep and wake monitoring with operator-visible warnings when scheduled Events may have been missed.
- Prevent Mac idle sleep via a macOS `IOPMAssertion` (configurable).
- Launch at login via `SMAppService`.
- Dock icon visibility: always, never, or only when the Dashboard window is open.

### Configuration
- Export the complete project configuration — Actions, Events, preferences — to a single JSON file.
- Import with three modes: merge with current, replace selected items, or start from a blank show.
- Import preview shows an audit summary (Action count, Event count, integrity issues) before committing.
- Selective import: choose which categories to import independently.

---

## Requirements

- **macOS 14.6 or later**
- Xcode 15 or later (to build from source)
- Network access on the local interface(s) used for UDP output

---

## Building

Clone the repository and open the Xcode project:

```bash
git clone https://github.com/lunartelephone/launch-control-center.git
cd "launch-control-center/Launch Control Center"
open "Launch Control Center.xcodeproj"
```

Select the **Launch Control Center** scheme and build (`⌘B`). No external dependencies or package manager setup is required.

> **Note:** The app uses the App Sandbox with network client and server entitlements. Ensure your signing configuration references the project's `.entitlements` file before archiving for distribution.

---

## Getting Started

1. **Launch** the app. It appears in the menu bar; the Dashboard window opens on first launch.
2. **Define Actions** (`⌘3` or Launch Control → Define Actions). Create one or more Show or Utility Actions and add message steps with destinations and payloads.
3. **Add Events** (`⌘4` or Launch Control → Add Events). Assign each Event to an Action and set its date/time and repeat rules.
4. **View the Schedule** (`⌘2`) to confirm occurrence generation and review execution history.
5. **Enable the schedule** using the Show Actions and Utility Actions toggles on the Dashboard.

The menu bar icon changes from inactive to active when either schedule toggle is on.

---

## Project Structure

```
Launch Control Center/
├── App/
│   └── Launch_Control_CenterApp.swift   # Entry point, windows, menu commands
├── Models/
│   ├── ActionDefinition.swift           # Show and Utility Action definitions
│   ├── ActionType.swift
│   ├── AppState.swift                   # Central state, scheduling, execution
│   ├── ControlStatus.swift
│   ├── ProjectSettings.swift
│   ├── ScheduleEntry.swift              # Scheduled Event rules and repeat logic
│   ├── ScheduledEvent.swift             # Legacy model (retained for migration)
│   ├── UDPCommand.swift                 # Show Action message step
│   └── UtilityCommand.swift             # Utility Action step
├── Services/
│   ├── LoginStartupService.swift        # SMAppService launch-at-login wrapper
│   ├── NetworkInventoryService.swift    # Local IPv4 interface inventory
│   ├── OperationalLogService.swift      # Daily rotating log files
│   ├── PersistenceService.swift         # UserDefaults-backed data storage
│   ├── ScheduleEngine.swift             # 10 Hz timer heartbeat
│   ├── ScheduleEntryFormatter.swift     # Occurrence generation and formatting
│   ├── SleepPreventionService.swift     # IOPMAssertion wrapper
│   ├── SyslogMessageFormatter.swift     # RFC-3164 syslog payload formatter
│   ├── SystemLifecycleService.swift     # Sleep/wake/terminate notifications
│   ├── UDPService.swift                 # Send and diagnostic listen
│   └── UptimeService.swift              # App and computer uptime formatting
└── Views/
    ├── AboutLCCView.swift
    ├── ActionEditorView.swift
    ├── ActionsView.swift
    ├── ContentView.swift                # Dashboard
    ├── EventEditorView.swift
    ├── HelpLCCView.swift
    ├── LCCDesignSystem.swift            # Centralized style constants
    ├── LCCLayout.swift                  # Window size constants
    ├── MenuBarView.swift
    ├── ScheduleCalendarView.swift
    ├── SetupView.swift                  # Preferences
    ├── StartupStatusPanel.swift
    ├── StatusPanelView.swift
    ├── TestingView.swift                # UDP send/listen diagnostics
    ├── TodayScheduleView.swift
    └── VolumeControlView.swift
```

---

## Configuration File Format

Exported configurations are standard JSON files (`.lcc` by convention). They include all Actions, Events, schedule entries, and optionally app and volume preferences. The format is versioned (`"version": 1`) and forward-compatible — unknown keys are ignored on import, and missing keys fall back to defaults.

Configuration files can be transferred between machines and imported selectively. They are human-readable and suitable for version control alongside production show files.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘1` | Dashboard |
| `⌘2` | Schedule |
| `⌘3` | Define Actions |
| `⌘4` | Add Events |
| `⌘5` | UDP Testing |
| `⌘,` | Preferences |
| `⌘/` | Help |

---

## Operational Notes

**Sleep and wake:** LCC monitors system sleep and wake events. If the Mac sleeps during a scheduled window, a warning banner appears on the Dashboard when it wakes. Review the schedule and clear the warning before resuming live operation. The "Prevent computer sleep" preference mitigates this for shows where the Mac must remain active overnight.

**Schedule toggles:** The Show Actions and Utility Actions toggles gate scheduled execution only. Manual Action buttons on the Dashboard always execute regardless of toggle state.

**Logs:** Open the logs folder from Launch Control → Open Logs Folder or from Preferences. Logs are plain text, one file per day, retained for the configured period.

---

## License

Copyright © 2026 Lunar Telephone Company. All rights reserved.
