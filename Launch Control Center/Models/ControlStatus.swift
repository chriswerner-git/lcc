//
//  ControlStatus.swift
//  Launch Control Center
//
//  Represents the high-level runtime status shown in the dashboard.
//  This is not the same as whether the schedule is enabled.
//  It describes what the app/control layer is currently doing.
//

import Foundation

enum ControlStatus: String, Codable, CaseIterable, Identifiable {
    case idle = "Idle"
    case listening = "Listening"
    case sending = "Sending"
    case error = "Error"

    var id: String {
        rawValue
    }
}
