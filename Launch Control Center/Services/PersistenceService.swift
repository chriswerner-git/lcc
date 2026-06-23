//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: PersistenceService.swift
//  Purpose: Saves and loads persisted app data from UserDefaults.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let persistenceServiceDidReportError = Notification.Name(
        "com.lunartelephone.launchcontrolcenter.persistenceServiceDidReportError"
    )
}

final class PersistenceService {
    // MARK: - Singleton

    static let shared = PersistenceService()

    private let errorLock = NSLock()
    private var recentErrorMessages: [String] = []

    private init() {}

    // MARK: - Storage Keys

    private let actionsKey = "actions"
    private let scheduleEntriesKey = "scheduleEntries"
    private let scheduleExecutionHistoryKey = "scheduleExecutionHistory"

    // Legacy model key. Retained while older saved data may still exist.
    private let scheduledEventsKey = "scheduledEvents"

    // MARK: - Actions

    func saveActionDefinitions(_ actions: [ActionDefinition]) {
        do {
            let data = try JSONEncoder().encode(actions)
            UserDefaults.standard.set(data, forKey: actionsKey)
        } catch {
            reportFailure("Failed to save Actions", error: error)
        }
    }

    func loadActionDefinitions() -> [ActionDefinition] {
        guard let data = UserDefaults.standard.data(forKey: actionsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ActionDefinition].self, from: data)
        } catch {
            reportFailure("Failed to load Actions", error: error)
            return []
        }
    }

    func deleteActionDefinitions() {
        UserDefaults.standard.removeObject(forKey: actionsKey)
    }

    // MARK: - Schedule Entries

    func saveScheduleEntries(_ entries: [ScheduleEntry]) {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: scheduleEntriesKey)
        } catch {
            reportFailure("Failed to save Events", error: error)
        }
    }

    func loadScheduleEntries() -> [ScheduleEntry] {
        guard let data = UserDefaults.standard.data(forKey: scheduleEntriesKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ScheduleEntry].self, from: data)
        } catch {
            reportFailure("Failed to load Events", error: error)
            return []
        }
    }

    func deleteScheduleEntries() {
        UserDefaults.standard.removeObject(forKey: scheduleEntriesKey)
    }

    // MARK: - Schedule Execution History

    func saveScheduleExecutionHistory(_ records: [ScheduleExecutionRecord]) {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: scheduleExecutionHistoryKey)
        } catch {
            reportFailure("Failed to save Schedule Execution History", error: error)
        }
    }

    func loadScheduleExecutionHistory() -> [ScheduleExecutionRecord] {
        guard let data = UserDefaults.standard.data(forKey: scheduleExecutionHistoryKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ScheduleExecutionRecord].self, from: data)
        } catch {
            reportFailure("Failed to load Schedule Execution History", error: error)
            return []
        }
    }

    func deleteScheduleExecutionHistory() {
        UserDefaults.standard.removeObject(forKey: scheduleExecutionHistoryKey)
    }

    // MARK: - Legacy Scheduled Events

    func saveScheduledEvents(_ events: [ScheduledEvent]) {
        do {
            let data = try JSONEncoder().encode(events)
            UserDefaults.standard.set(data, forKey: scheduledEventsKey)
        } catch {
            reportFailure("Failed to save legacy Scheduled Events", error: error)
        }
    }

    func loadScheduledEvents() -> [ScheduledEvent] {
        guard let data = UserDefaults.standard.data(forKey: scheduledEventsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([ScheduledEvent].self, from: data)
        } catch {
            reportFailure("Failed to load legacy Scheduled Events", error: error)
            return []
        }
    }

    func deleteScheduledEvents() {
        UserDefaults.standard.removeObject(forKey: scheduledEventsKey)
    }

    // MARK: - Error Reporting

    func consumeRecentErrorMessages() -> [String] {
        errorLock.lock()
        defer { errorLock.unlock() }

        let messages = recentErrorMessages
        recentErrorMessages.removeAll()
        return messages
    }

    private func reportFailure(
        _ context: String,
        error: Error
    ) {
        let message = "Persistence error: \(context): \(error.localizedDescription)"

        OperationalLogService.shared.error(message)
        NSLog("Launch Control Center \(message)")

        errorLock.lock()
        recentErrorMessages.append(message)
        errorLock.unlock()

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .persistenceServiceDidReportError,
                object: self,
                userInfo: ["message": message]
            )
        }
    }

}
