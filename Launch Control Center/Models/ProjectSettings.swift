//
//  ProjectSettings.swift
//  Launch Control Center
//
//  Stores user-configurable project defaults.
//  These settings should eventually be editable only through the Setup UI,
//  not through Xcode or source-code changes.
//

import Foundation

struct ProjectSettings: Codable {
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
