//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: ProjectSettings.swift
//  Purpose: Legacy project settings container retained for compatibility.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

struct ProjectSettings: Codable {
    // MARK: - Legacy Notice

    // Most active settings now live directly in AppState and are persisted
    // individually through UserDefaults or project configuration export.
    //
    // Keep this model only while older saved data or future migration paths
    // may still reference it.

    // MARK: - Project

    var projectName: String = "Untitled Project"

    // MARK: - Display

    var use24HourTime: Bool = true

    // MARK: - UDP Defaults

    var incomingUDPPort: Int = 8000
    var defaultDestinationHost: String = "127.0.0.1"
    var defaultDestinationPort: Int = 8001

    // MARK: - Schedule State Messages

    var scheduleEnabledOnMessage: String = "SCHEDULE_ENABLED"
    var scheduleEnabledOffMessage: String = "SCHEDULE_DISABLED"

    // MARK: - Volume

    var volumeLevel: Double = 0.75
}
