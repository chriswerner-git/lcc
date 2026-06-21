//
//  ActionDefinition.swift
//  Launch Control Center
//
//  Defines a reusable Action.
//
//  Show Actions execute UDP commands.
//  Utility Actions execute dashboard-level Utility commands.
//

import Foundation

struct ActionDefinition: Identifiable, Codable {
    var id: UUID = UUID()

    // User-facing action name, such as "Show 1" or "Server Reset".
    var name: String

    // Optional user notes for documenting intent, context, warnings, etc.
    var notes: String

    // Action category.
    var type: ActionType

    // Show Action steps.
    // These are UDP commands executed in sequence.
    var commands: [UDPCommand] = []

    // Utility Action steps.
    // These perform dashboard-level operations.
    var utilityCommands: [UtilityCommand] = []

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
