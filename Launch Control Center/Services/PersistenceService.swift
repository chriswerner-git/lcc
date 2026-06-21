//
//  PersistenceService.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//

import Foundation

class PersistenceService {
    static let shared = PersistenceService()

    private init() {}

    private let scheduledEventsKey = "scheduledEvents"
    
    private let eventDefinitionsKey = "eventDefinitions"
    private let scheduleEntriesKey = "scheduleEntries"

    func saveScheduledEvents(_ events: [ScheduledEvent]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: scheduledEventsKey)
        } catch {
            print("Failed to save scheduled events: \(error)")
        }
    }

    func loadScheduledEvents() -> [ScheduledEvent] {
        guard let data = UserDefaults.standard.data(forKey: scheduledEventsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ScheduledEvent].self, from: data)
        } catch {
            print("Failed to load scheduled events: \(error)")
            return []
        }
    }
    
    func saveEventDefinitions(_ definitions: [EventDefinition]) {
        do {
            let data = try JSONEncoder().encode(definitions)
            UserDefaults.standard.set(data, forKey: eventDefinitionsKey)
        } catch {
            print("Failed to save event definitions: \(error)")
        }
    }

    func loadEventDefinitions() -> [EventDefinition] {
        guard let data = UserDefaults.standard.data(forKey: eventDefinitionsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([EventDefinition].self, from: data)
        } catch {
            print("Failed to load event definitions: \(error)")
            return []
        }
    }

    func saveScheduleEntries(_ entries: [ScheduleEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: scheduleEntriesKey)
        } catch {
            print("Failed to save schedule entries: \(error)")
        }
    }

    func loadScheduleEntries() -> [ScheduleEntry] {
        guard let data = UserDefaults.standard.data(forKey: scheduleEntriesKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ScheduleEntry].self, from: data)
        } catch {
            print("Failed to load schedule entries: \(error)")
            return []
        }
    }
}
