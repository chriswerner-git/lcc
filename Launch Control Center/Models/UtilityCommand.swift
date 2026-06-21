//
//  UtilityCommand.swift
//  Launch Control Center
//
//  Defines a single Utility command.
//
//  Utility Actions are dashboard automation macros.
//  They can perform app-level functions such as:
//  - set volume
//  - enable / disable scheduled Show Actions
//  - enable / disable scheduled Utility Actions
//  - run another Action manually
//  - send a UDP command
//

import Foundation

struct UtilityCommand: Identifiable, Codable {
    var id: UUID = UUID()

    var name: String = "Utility Step"
    var kind: UtilityCommandKind = .setVolume

    // Delay before this Utility Step runs.
    var delaySeconds: Double = 0

    // Used by .setVolume.
    // Stored as 0.0 ... 1.0.
    var volumeLevel: Double = 0.75

    // Used by .setShowScheduleEnabled.
    var showScheduleEnabled: Bool = true

    // Used by .setUtilityScheduleEnabled.
    var utilityScheduleEnabled: Bool = true

    // Used by .runAction.
    var actionDefinitionID: UUID?

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
