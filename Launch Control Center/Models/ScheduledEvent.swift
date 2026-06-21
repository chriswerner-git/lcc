//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduledEvent.swift
//  Purpose: Legacy scheduled Event model retained for compatibility.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

struct ScheduledEvent: Identifiable, Codable {
    // MARK: - Legacy Notice

    // This model has been superseded by ScheduleEntry, where Events reference
    // ActionDefinition records instead of storing command data directly.
    //
    // Keep this model while older saved data may still exist.

    // MARK: - Identity

    var id: UUID = UUID()

    // MARK: - Basic Info

    var title: String
    var type: ActionType

    // MARK: - Timing

    var startDate: Date
    var enabled: Bool = true
    var repeatsDaily: Bool = false
    var repeatUntil: Date?

    // MARK: - Legacy Command Data

    // Older Events stored a single UDP message directly on the Event.
    // Newer Events should trigger an ActionDefinition instead.
    var commandMessage: String
}
