//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ActionDefinition.swift
//  Purpose: Defines reusable Show and Utility Actions.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

struct ActionDefinition: Identifiable, Codable {
    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Basic Info

    // Operator-facing Action name, such as "Show 1" or "Server Reset".
    var name: String

    // Optional notes documenting intent, context, warnings, or handoff details.
    var notes: String

    // Primary Action category.
    var type: ActionType

    // MARK: - Show Action Steps

    // UDP commands executed in sequence when this is a Show Action.
    var commands: [UDPCommand] = []

    // MARK: - Utility Action Steps

    // App-level operations executed in sequence when this is a Utility Action.
    var utilityCommands: [UtilityCommand] = []

    // MARK: - Init

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        type: ActionType,
        commands: [UDPCommand] = [],
        utilityCommands: [UtilityCommand] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.type = type
        self.commands = commands
        self.utilityCommands = utilityCommands
    }

    // MARK: - Codable Compatibility

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case notes
        case type
        case commands
        case utilityCommands
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        type = try container.decode(ActionType.self, forKey: .type)
        commands = try container.decodeIfPresent([UDPCommand].self, forKey: .commands) ?? []
        utilityCommands = try container.decodeIfPresent([UtilityCommand].self, forKey: .utilityCommands) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(notes, forKey: .notes)
        try container.encode(type, forKey: .type)
        try container.encode(commands, forKey: .commands)
        try container.encode(utilityCommands, forKey: .utilityCommands)
    }
}
