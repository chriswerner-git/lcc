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
    var udpSourceIPAddress: String = ""
    var udpAllowsBroadcast: Bool = false
    var udpMessage: String = ""

    // MARK: - Codable Compatibility

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case delaySeconds
        case volumeLevel
        case showScheduleEnabled
        case utilityScheduleEnabled
        case actionDefinitionID
        case udpHost
        case udpPort
        case udpSourceIPAddress
        case udpAllowsBroadcast
        case udpMessage
    }

    init(
        id: UUID = UUID(),
        name: String = "Utility Step",
        kind: UtilityCommandKind = .setVolume,
        delaySeconds: Double = 0,
        volumeLevel: Double = 0.75,
        showScheduleEnabled: Bool = true,
        utilityScheduleEnabled: Bool = true,
        actionDefinitionID: UUID? = nil,
        udpHost: String = "127.0.0.1",
        udpPort: Int = 8001,
        udpSourceIPAddress: String = "",
        udpAllowsBroadcast: Bool = false,
        udpMessage: String = ""
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.delaySeconds = delaySeconds
        self.volumeLevel = volumeLevel
        self.showScheduleEnabled = showScheduleEnabled
        self.utilityScheduleEnabled = utilityScheduleEnabled
        self.actionDefinitionID = actionDefinitionID
        self.udpHost = udpHost
        self.udpPort = udpPort
        self.udpSourceIPAddress = udpSourceIPAddress
        self.udpAllowsBroadcast = udpAllowsBroadcast
        self.udpMessage = udpMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Utility Step"
        kind = try container.decodeIfPresent(UtilityCommandKind.self, forKey: .kind) ?? .setVolume
        delaySeconds = try container.decodeIfPresent(Double.self, forKey: .delaySeconds) ?? 0
        volumeLevel = try container.decodeIfPresent(Double.self, forKey: .volumeLevel) ?? 0.75
        showScheduleEnabled = try container.decodeIfPresent(Bool.self, forKey: .showScheduleEnabled) ?? true
        utilityScheduleEnabled = try container.decodeIfPresent(Bool.self, forKey: .utilityScheduleEnabled) ?? true
        actionDefinitionID = try container.decodeIfPresent(UUID.self, forKey: .actionDefinitionID)
        udpHost = try container.decodeIfPresent(String.self, forKey: .udpHost) ?? "127.0.0.1"
        udpPort = try container.decodeIfPresent(Int.self, forKey: .udpPort) ?? 8001
        udpSourceIPAddress = try container.decodeIfPresent(String.self, forKey: .udpSourceIPAddress) ?? ""
        udpAllowsBroadcast = try container.decodeIfPresent(Bool.self, forKey: .udpAllowsBroadcast) ?? false
        udpMessage = try container.decodeIfPresent(String.self, forKey: .udpMessage) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(delaySeconds, forKey: .delaySeconds)
        try container.encode(volumeLevel, forKey: .volumeLevel)
        try container.encode(showScheduleEnabled, forKey: .showScheduleEnabled)
        try container.encode(utilityScheduleEnabled, forKey: .utilityScheduleEnabled)
        try container.encodeIfPresent(actionDefinitionID, forKey: .actionDefinitionID)
        try container.encode(udpHost, forKey: .udpHost)
        try container.encode(udpPort, forKey: .udpPort)
        try container.encode(udpSourceIPAddress, forKey: .udpSourceIPAddress)
        try container.encode(udpAllowsBroadcast, forKey: .udpAllowsBroadcast)
        try container.encode(udpMessage, forKey: .udpMessage)
    }
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
