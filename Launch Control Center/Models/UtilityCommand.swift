//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: UtilityCommand.swift
//  Purpose: Defines app-level Utility Action steps.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

struct UtilityCommand: Identifiable, Codable {
    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Basic Info

    var name: String = "Utility Step"
    var kind: UtilityCommandKind = .setVolume

    // MARK: - Timing

    // Delay before this Utility Step runs, measured from the previous step.
    var delaySeconds: Double = 0

    // MARK: - Volume

    // Used by .setVolume. Stored as 0.0 ... 1.0.
    var volumeLevel: Double = 0.75

    // MARK: - Schedule Toggles

    // Used by .setShowScheduleEnabled.
    var showScheduleEnabled: Bool = true

    // Used by .setUtilityScheduleEnabled.
    var utilityScheduleEnabled: Bool = true

    // MARK: - Action Triggering

    // Used by .runAction.
    var actionDefinitionID: UUID?

    // MARK: - UDP Output

    // Used by .sendUDP.
    var udpHost: String = "127.0.0.1"
    var udpPort: Int = 8001
    var udpMessage: String = ""
}

enum UtilityCommandKind: String, Codable, CaseIterable, Identifiable {
    case setVolume = "Set Volume"
    case setShowScheduleEnabled = "Set Show Schedule"
    case setUtilityScheduleEnabled = "Set Utility Schedule"
    case runAction = "Run Action"
    case sendUDP = "Send UDP"

    var id: String {
        rawValue
    }
}
