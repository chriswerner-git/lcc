//
//  UDPCommand.swift
//  Launch Control Center
//
//  Defines a single UDP command.
//
//  An Action may contain one or more UDP commands.
//  Commands execute in sequence when the Action runs.
//
//  Example:
//
//  Action: Show 1
//      Command A → Lighting Controller
//      Command B → Audio Server
//      Command C → Show Control
//

import Foundation

struct UDPCommand: Identifiable, Codable {
    // Stable identifier for editing, sorting, and persistence.
    var id: UUID = UUID()

    // User-friendly command name.
    //
    // Examples:
    // "Lighting Start"
    // "Audio Playback"
    // "Enable Schedule"
    var name: String = "UDP Command"

    // Destination host.
    var host: String = "127.0.0.1"

    // Destination UDP port.
    var port: Int = 8001

    // UDP payload.
    //
    // Future enhancement:
    // Support templates and variable substitution.
    var message: String = ""

    // Delay after the previous command.
    //
    // Example:
    // Command A = 0.0 sec
    // Command B = 0.5 sec
    // Command C = 2.0 sec
    //
    // Future enhancement:
    // Support absolute timeline offsets.
    var delaySeconds: Double = 0
}
