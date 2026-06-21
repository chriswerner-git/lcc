//
//  ScheduleEngine.swift
//  Launch Control Center
//
//  Lightweight repeating timer used by AppState to check scheduled Events.
//
//  The engine does not decide what should run.
//  It simply provides a reliable heartbeat.
//
//  Schedule logic lives in AppState so it can access:
//  - saved schedule entries
//  - saved action definitions
//  - Show / Utility enable toggles
//  - dashboard status state
//
//
//
//  Legacy schedule model.
//  This is being replaced by ScheduleEntry, where Events reference Actions.
//  Keep this file temporarily until all existing views have been migrated.
//

import Foundation

struct ScheduledEvent: Identifiable, Codable {
    // Stable ID for this legacy scheduled item.
    var id: UUID = UUID()

    // User-facing event name.
    var title: String

    // Legacy type value.
    // Eventually this should come from the referenced ActionDefinition.
    var type: ActionType

    // Date and time when this legacy event should run.
    var startDate: Date

    // Whether this individual legacy event is enabled.
    var enabled: Bool = true

    // Basic daily repeat support.
    var repeatsDaily: Bool = false
    var repeatUntil: Date?

    // Legacy single UDP message.
    // Eventually this should be replaced by ActionDefinition.commands.
    var commandMessage: String
}
