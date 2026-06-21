//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ControlStatus.swift
//  Purpose: Represents the high-level runtime status shown by the app.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
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
