//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: PersistenceService.swift
//  Purpose: Saves and loads persisted app data from UserDefaults.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

final class PersistenceService {
    // MARK: - Singleton

    static let shared = PersistenceService()

    private init() {}

    // MARK: - Storage Keys

    private let actionsKey = "actions"
    private let scheduleEntriesKey = "scheduleEntries"

    // Legacy model key. Retained while older saved data may still exist.
    private let scheduledEventsKey = "scheduledEvents"

    // MARK: - Actions

    func saveActionDefinitions(_ actions: [ActionDefinition]) {
        do {
            let data = try JSONEncoder().encode(actions)
            UserDefaults.standard.set(data, forKey: actionsKey)
        } catch {
            print("Failed to save Actions: \(error)")
        }
    }

    func loadActionDefinitions() -> [ActionDefinition] {
        guard let data = UserDefaults.standard.data(forKey: actionsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ActionDefinition].self, from: data)
        } catch {
            print("Failed to load Actions: \(error)")
            return []
        }
    }

    // MARK: - Schedule Entries

    func saveScheduleEntries(_ entries: [ScheduleEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: scheduleEntriesKey)
        } catch {
            print("Failed to save Events: \(error)")
        }
    }

    func loadScheduleEntries() -> [ScheduleEntry] {
        guard let data = UserDefaults.standard.data(forKey: scheduleEntriesKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ScheduleEntry].self, from: data)
        } catch {
            print("Failed to load Events: \(error)")
            return []
        }
    }

    // MARK: - Legacy Scheduled Events

    func saveScheduledEvents(_ events: [ScheduledEvent]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: scheduledEventsKey)
        } catch {
            print("Failed to save legacy Scheduled Events: \(error)")
        }
    }

    func loadScheduledEvents() -> [ScheduledEvent] {
        guard let data = UserDefaults.standard.data(forKey: scheduledEventsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ScheduledEvent].self, from: data)
        } catch {
            print("Failed to load legacy Scheduled Events: \(error)")
            return []
        }
    }
}
