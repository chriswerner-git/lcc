//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: UDPCommand.swift
//  Purpose: Defines one UDP command step inside a Show Action.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

struct UDPCommand: Identifiable, Codable {
    // Stable identifier for editing, sorting, and persistence.
    var id: UUID = UUID()

    // Operator-facing step name.
    var name: String = "UDP Command"

    // Destination endpoint.
    var host: String = "127.0.0.1"
    var port: Int = 8001

    // UDP payload sent to the destination endpoint.
    var message: String = ""

    // Delay before this command runs, measured from the previous step.
    var delaySeconds: Double = 0
}
