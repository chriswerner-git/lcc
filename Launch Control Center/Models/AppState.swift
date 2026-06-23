//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: AppState.swift
//  Purpose: Central app state, persistence coordination, scheduling, and Action execution.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  Notes:
//  - App preferences are exported so configurations can be moved between machines,
//    but App Preferences default to unchecked during selective import.
//  - Schedule enable toggles affect scheduled Events only.
//  - Manual Action buttons still run regardless of schedule toggle state.
//  - Show Actions execute message steps.
//  - Utility Actions execute dashboard-level Utility steps.
//

import AppKit
import Combine
import Foundation


// MARK: - Configuration Health

enum ConfigurationHealthLevel: Int, Codable, Comparable {
    case healthy = 0
    case warning = 1
    case error = 2

    static func < (lhs: ConfigurationHealthLevel, rhs: ConfigurationHealthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .healthy:
            return "Healthy"

        case .warning:
            return "Warnings"

        case .error:
            return "Errors"
        }
    }

    var systemImage: String {
        switch self {
        case .healthy:
            return "checkmark.circle.fill"

        case .warning:
            return "exclamationmark.triangle.fill"

        case .error:
            return "xmark.octagon.fill"
        }
    }
}

struct ConfigurationHealthIssue: Identifiable, Codable {
    var id: UUID = UUID()
    var level: ConfigurationHealthLevel
    var title: String
    var detail: String
}

struct ConfigurationHealthReport: Codable {
    var level: ConfigurationHealthLevel
    var issues: [ConfigurationHealthIssue]

    var title: String {
        level.displayName
    }

    var summary: String {
        switch level {
        case .healthy:
            return "Configuration looks ready."

        case .warning:
            return "\(issues.count) warning\(issues.count == 1 ? "" : "s") found."

        case .error:
            return "\(issues.count) issue\(issues.count == 1 ? "" : "s") need attention."
        }
    }
}

// MARK: - Dock Icon Visibility Preference

enum DockIconVisibilityPreference: String, CaseIterable, Codable, Identifiable {
    case always
    case never
    case showWhenDashboardWindowIsOpen

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .always:
            return "Always"

        case .never:
            return "Never"

        case .showWhenDashboardWindowIsOpen:
            return "Dashboard Open"
        }
    }

    var preferenceDescription: String {
        switch self {
        case .always:
            return "The Dock icon is always visible while Launch Control Center is running."

        case .never:
            return "The Dock icon stays hidden. Use the menu bar icon to open windows."

        case .showWhenDashboardWindowIsOpen:
            return "The Dock icon appears while the Dashboard window is open."
        }
    }
}


// MARK: - Schedule Execution History

enum ScheduleExecutionResult: String, Codable {
    case ran
    case skipped
    case failed

    var displayName: String {
        switch self {
        case .ran:
            return "Ran"

        case .skipped:
            return "Skipped"

        case .failed:
            return "Failed"
        }
    }
}

struct ScheduleExecutionRecord: Identifiable, Codable {
    var id: UUID = UUID()
    var eventID: UUID
    var occurrenceKey: String
    var scheduledDate: Date
    var actualDate: Date?
    var result: ScheduleExecutionResult
    var message: String
    var recordedAt: Date = Date()

    init(
        id: UUID = UUID(),
        eventID: UUID,
        occurrenceKey: String,
        scheduledDate: Date,
        actualDate: Date?,
        result: ScheduleExecutionResult,
        message: String,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.eventID = eventID
        self.occurrenceKey = occurrenceKey
        self.scheduledDate = scheduledDate
        self.actualDate = actualDate
        self.result = result
        self.message = message
        self.recordedAt = recordedAt
    }
}


// MARK: - Configuration Audit

enum ConfigurationAuditSeverity {
    case warning
    case error

    var displayName: String {
        switch self {
        case .warning:
            return "Warning"

        case .error:
            return "Error"
        }
    }
}

struct ConfigurationAuditIssue: Identifiable {
    var id: UUID = UUID()
    var severity: ConfigurationAuditSeverity
    var message: String
}

struct ConfigurationAuditSummary {
    var projectName: String
    var version: Int
    var exportedAt: Date

    var actionCount: Int
    var eventCount: Int
    var standaloneEventCount: Int
    var recurringSeriesCount: Int
    var intervalSeriesCount: Int
    var disabledEventCount: Int
    var removedOccurrenceCount: Int

    var finiteGeneratedEventCount: Int
    var openEndedSeriesCount: Int

    var issues: [ConfigurationAuditIssue]

    var hasErrors: Bool {
        issues.contains { $0.severity == .error }
    }

    var hasWarnings: Bool {
        issues.contains { $0.severity == .warning }
    }

    var statusText: String {
        if hasErrors {
            return "Errors"
        }

        if hasWarnings {
            return "Warnings"
        }

        return "OK"
    }
}

struct ConfigurationImportPreview {
    var fileName: String
    var summary: ConfigurationAuditSummary
}

// MARK: - Configuration Import Options

enum ConfigurationImportMode: String, CaseIterable, Identifiable {
    case mergeWithCurrent
    case replaceSelected
    case newBlankShow

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .mergeWithCurrent:
            return "Merge with Current Show"

        case .replaceSelected:
            return "Replace Selected Items"

        case .newBlankShow:
            return "Import into New / Blank Show"
        }
    }
}

struct ConfigurationImportOptions {
    var mode: ConfigurationImportMode
    var importAppPreferences: Bool
    var importProjectPreferences: Bool
    var importVolumePreferences: Bool
    var importActions: Bool
    var importEvents: Bool
    var importScheduleEnableStates: Bool

    static var defaultSelection: ConfigurationImportOptions {
        ConfigurationImportOptions(
            mode: .replaceSelected,
            importAppPreferences: false,
            importProjectPreferences: true,
            importVolumePreferences: true,
            importActions: true,
            importEvents: true,
            importScheduleEnableStates: true
        )
    }
}

struct ConfigurationImportResult {
    var summary: ConfigurationAuditSummary
    var reportLines: [String]

    var statusLine: String {
        let reportText = reportLines.isEmpty
            ? "No merge conflicts."
            : "Report: \(reportLines.count) item\(reportLines.count == 1 ? "" : "s")."

        return "Actions: \(summary.actionCount). Events: \(summary.eventCount). Recurring Series: \(summary.recurringSeriesCount). Schedule Check: \(summary.statusText). \(reportText)"
    }
}

struct ConfigurationBackupSnapshot: Identifiable {
    let id: String
    let url: URL
    let fileName: String
    let createdAt: Date
    let summary: ConfigurationAuditSummary?
    let errorMessage: String?

    var isRestorable: Bool {
        errorMessage == nil && summary != nil
    }

    var projectName: String {
        summary?.projectName ?? "Unreadable Backup"
    }

    var detailLine: String {
        if let summary {
            return "Actions: \(summary.actionCount) • Events: \(summary.eventCount) • Schedule Check: \(summary.statusText)"
        }

        return errorMessage ?? "This backup could not be read."
    }
}

// MARK: - Configuration Import Errors

enum ConfigurationImportError: LocalizedError {
    case actionsRunning(count: Int)
    case invalidSelection(String)
    case backupFailed(String)

    var errorDescription: String? {
        switch self {
        case .actionsRunning(let count):
            let actionText = count == 1 ? "Action is" : "Actions are"
            return "Import blocked because \(count) \(actionText) currently running. Wait for all Actions to finish before importing configuration data."

        case .invalidSelection(let message):
            return message

        case .backupFailed(let message):
            return "Import blocked because an automatic backup could not be created. \(message)"
        }
    }
}


// MARK: - Reset Errors

enum AppResetError: LocalizedError {
    case actionsRunning(count: Int)
    case backupFailed(String)

    var errorDescription: String? {
        switch self {
        case .actionsRunning(let count):
            let actionText = count == 1 ? "Action is" : "Actions are"
            return "Reset blocked because \(count) \(actionText) currently running. Wait for all Actions to finish before resetting stored data."

        case .backupFailed(let message):
            return "Reset blocked because an automatic backup could not be created. \(message)"
        }
    }
}

final class AppState: ObservableObject {
    let udpService = UDPService()

    private let scheduleEngine = ScheduleEngine()

    // With 10 Hz polling, Events should fire close to their scheduled time.
    // This tolerance allows a small amount of timer/run-loop drift without
    // allowing stale Events to fire many seconds late.
    private let scheduleFireToleranceSeconds: TimeInterval = 1.0

    // Prevents the schedule processor from overlapping itself if a timer tick
    // arrives while a previous tick is still being evaluated.
    private var scheduleProcessingIsActive: Bool = false

    // Tracks fired Event occurrences so the 10 Hz timer does not trigger the
    // same scheduled occurrence more than once.
    private var processedScheduleOccurrences: Set<String> = []
    private var processedScheduleOccurrenceDay: Date = Calendar.current.startOfDay(for: Date())
    private var processedScheduleOccurrenceTotalCount: Int = 0

    private let processedScheduleOccurrenceDailyLimit: Int = 1_000
    private let processedScheduleOccurrenceTotalLimit: Int = 10_000
    private let scheduleExecutionHistoryRetentionDays: Int = 60

    // Tracks Actions currently executing so the same Action cannot overlap itself.
    private var runningActionIDs: Set<UUID> = []
    private var runningActionTasks: [UUID: Task<Void, Never>] = [:]

    @Published private(set) var runningActionCount: Int = 0

    // Allows grouped preference updates to produce one final volume output message
    // instead of a burst of intermediate UDP messages.
    private var volumePreferenceOutputIsSuspended: Bool = false

    private let maximumActionRuntimeSeconds: TimeInterval = 120
    private let appLaunchDate = Date()

    private var dailyHealthLogTimer: Timer?
    private var persistenceFailureObserver: NSObjectProtocol?

    private let loginStartupService = LoginStartupService()
    private let sleepPreventionService = SleepPreventionService()
    private let systemLifecycleService = SystemLifecycleService()
    private let logger = OperationalLogService.shared

    // MARK: - App Preferences

    @Published var launchAtStartupEnabled: Bool = false
    @Published var launchAtStartupStatusMessage: String = "Launch at startup status unknown."

    @Published var preventComputerSleepEnabled: Bool {
        didSet {
            UserDefaults.standard.set(
                preventComputerSleepEnabled,
                forKey: "preventComputerSleepEnabled"
            )
        }
    }

    @Published var preventComputerSleepStatusMessage: String = "Prevent computer sleep is disabled."

    @Published var operationalLogRetentionDays: Int {
        didSet {
            let safeValue = clampedOperationalLogRetentionDays(
                operationalLogRetentionDays
            )

            UserDefaults.standard.set(
                safeValue,
                forKey: "operationalLogRetentionDays"
            )
        }
    }

    @Published var syslogDeviceName: String {
        didSet {
            UserDefaults.standard.set(
                syslogDeviceName,
                forKey: "syslogDeviceName"
            )
        }
    }

    @Published var dockIconVisibilityPreference: DockIconVisibilityPreference {
        didSet {
            UserDefaults.standard.set(
                dockIconVisibilityPreference.rawValue,
                forKey: "dockIconVisibilityPreference"
            )

            applyDockIconVisibilityPreference()
        }
    }

    @Published private(set) var dashboardWindowIsOpen: Bool = false

    // MARK: - System Lifecycle

    @Published var systemLifecycleStatusMessage: String = "System awake. Monitoring not yet started."
    @Published var systemLifecycleWarningMessage: String?

    @Published var lastSystemSleepTime: Date?
    @Published var lastSystemWakeTime: Date?

    // MARK: - Project / Display Settings

    @Published var projectName: String {
        didSet { UserDefaults.standard.set(projectName, forKey: "projectName") }
    }

    @Published var projectNotes: String {
        didSet { UserDefaults.standard.set(projectNotes, forKey: "projectNotes") }
    }

    @Published var use24HourTime: Bool {
        didSet { UserDefaults.standard.set(use24HourTime, forKey: "use24HourTime") }
    }

    @Published var weekStartDay: Int {
        didSet { UserDefaults.standard.set(weekStartDay, forKey: "weekStartDay") }
    }

    // MARK: - UDP Test Defaults

    @Published var incomingUDPPort: Int {
        didSet { UserDefaults.standard.set(incomingUDPPort, forKey: "incomingUDPPort") }
    }

    @Published var defaultDestinationHost: String {
        didSet { UserDefaults.standard.set(defaultDestinationHost, forKey: "defaultDestinationHost") }
    }

    @Published var defaultDestinationPort: Int {
        didSet { UserDefaults.standard.set(defaultDestinationPort, forKey: "defaultDestinationPort") }
    }

    // MARK: - Volume UDP Output Settings

    @Published var volumeDestinationHost: String {
        didSet { UserDefaults.standard.set(volumeDestinationHost, forKey: "volumeDestinationHost") }
    }

    @Published var volumeDestinationPort: Int {
        didSet { UserDefaults.standard.set(volumeDestinationPort, forKey: "volumeDestinationPort") }
    }

    @Published var volumeMessagePrefix: String {
        didSet { UserDefaults.standard.set(volumeMessagePrefix, forKey: "volumeMessagePrefix") }
    }

    @Published var volumeOutputMinimum: Double {
        didSet {
            UserDefaults.standard.set(volumeOutputMinimum, forKey: "volumeOutputMinimum")
            handleVolumePreferenceChange()
        }
    }

    @Published var volumeOutputMaximum: Double {
        didSet {
            UserDefaults.standard.set(volumeOutputMaximum, forKey: "volumeOutputMaximum")
            handleVolumePreferenceChange()
        }
    }

    @Published var volumeMuteLevel: Double {
        didSet {
            UserDefaults.standard.set(volumeMuteLevel, forKey: "volumeMuteLevel")
            handleVolumePreferenceChange()
        }
    }

    // MARK: - Schedule Toggles

    @Published var showActionsEnabled: Bool {
        didSet { UserDefaults.standard.set(showActionsEnabled, forKey: "showActionsEnabled") }
    }

    @Published var utilityActionsEnabled: Bool {
        didSet { UserDefaults.standard.set(utilityActionsEnabled, forKey: "utilityActionsEnabled") }
    }

    @Published var scheduleEnabledOnMessage: String {
        didSet { UserDefaults.standard.set(scheduleEnabledOnMessage, forKey: "scheduleEnabledOnMessage") }
    }

    @Published var scheduleEnabledOffMessage: String {
        didSet { UserDefaults.standard.set(scheduleEnabledOffMessage, forKey: "scheduleEnabledOffMessage") }
    }

    // MARK: - Status

    @Published var lastMessage: String = "No messages yet"
    @Published var lastEventMessage: String = "No Event has run yet"
    @Published var controlStatus: ControlStatus = .idle

    // MARK: - Volume State

    @Published var volumeLevel: Double {
        didSet { UserDefaults.standard.set(volumeLevel, forKey: "volumeLevel") }
    }

    @Published var lastUnmutedVolumeLevel: Double {
        didSet { UserDefaults.standard.set(lastUnmutedVolumeLevel, forKey: "lastUnmutedVolumeLevel") }
    }

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "isMuted") }
    }

    @Published var lowVolumeLevel: Double {
        didSet { UserDefaults.standard.set(lowVolumeLevel, forKey: "lowVolumeLevel") }
    }

    @Published var normalVolumeLevel: Double {
        didSet { UserDefaults.standard.set(normalVolumeLevel, forKey: "normalVolumeLevel") }
    }

    @Published var highVolumeLevel: Double {
        didSet { UserDefaults.standard.set(highVolumeLevel, forKey: "highVolumeLevel") }
    }

    // MARK: - Saved Data

    @Published var actionDefinitions: [ActionDefinition] = [] {
        didSet { PersistenceService.shared.saveActionDefinitions(actionDefinitions) }
    }

    @Published var scheduledEvents: [ScheduledEvent] = [] {
        didSet { PersistenceService.shared.saveScheduledEvents(scheduledEvents) }
    }

    @Published var scheduleEntries: [ScheduleEntry] = [] {
        didSet { PersistenceService.shared.saveScheduleEntries(scheduleEntries) }
    }

    @Published private(set) var scheduleExecutionHistory: [ScheduleExecutionRecord] = [] {
        didSet { PersistenceService.shared.saveScheduleExecutionHistory(scheduleExecutionHistory) }
    }

    // MARK: - Configuration Health

    var configurationHealthReport: ConfigurationHealthReport {
        let availableSourceIPs = Set(
            NetworkInventoryService.currentIPv4Interfaces()
                .filter { $0.isUp && $0.isRunning }
                .map(\.ipv4Address)
        )

        return ConfigurationHealthService.evaluate(
            actionDefinitions: actionDefinitions,
            scheduleEntries: scheduleEntries,
            showActionsEnabled: showActionsEnabled,
            utilityActionsEnabled: utilityActionsEnabled,
            availableSourceIPs: availableSourceIPs
        )
    }

    // MARK: - Init

    init() {
        self.preventComputerSleepEnabled = UserDefaults.standard.object(forKey: "preventComputerSleepEnabled") as? Bool ?? false
        let savedLogRetentionDays = UserDefaults.standard.object(forKey: "operationalLogRetentionDays") as? Int ?? 90
        self.operationalLogRetentionDays = AppState.clampedOperationalLogRetentionDays(savedLogRetentionDays)
        self.syslogDeviceName = UserDefaults.standard.string(forKey: "syslogDeviceName") ?? AppState.defaultSyslogDeviceName()

        let savedDockIconPreference = UserDefaults.standard.string(forKey: "dockIconVisibilityPreference")
        self.dockIconVisibilityPreference = DockIconVisibilityPreference(rawValue: savedDockIconPreference ?? "") ?? .showWhenDashboardWindowIsOpen

        self.projectName = UserDefaults.standard.string(forKey: "projectName") ?? "Untitled Project"
        self.projectNotes = UserDefaults.standard.string(forKey: "projectNotes") ?? ""
        self.use24HourTime = UserDefaults.standard.object(forKey: "use24HourTime") as? Bool ?? true
        self.weekStartDay = UserDefaults.standard.object(forKey: "weekStartDay") as? Int ?? 1

        self.incomingUDPPort = UserDefaults.standard.object(forKey: "incomingUDPPort") as? Int ?? 8000
        self.defaultDestinationHost = UserDefaults.standard.string(forKey: "defaultDestinationHost") ?? "127.0.0.1"
        self.defaultDestinationPort = UserDefaults.standard.object(forKey: "defaultDestinationPort") as? Int ?? 8001

        self.volumeDestinationHost = UserDefaults.standard.string(forKey: "volumeDestinationHost") ?? "127.0.0.1"
        self.volumeDestinationPort = UserDefaults.standard.object(forKey: "volumeDestinationPort") as? Int ?? 8001
        self.volumeMessagePrefix = UserDefaults.standard.string(forKey: "volumeMessagePrefix") ?? "/cue/selected/level/0/"
        self.volumeOutputMinimum = UserDefaults.standard.object(forKey: "volumeOutputMinimum") as? Double ?? -60
        self.volumeOutputMaximum = UserDefaults.standard.object(forKey: "volumeOutputMaximum") as? Double ?? 12
        self.volumeMuteLevel = UserDefaults.standard.object(forKey: "volumeMuteLevel") as? Double ?? -60

        self.showActionsEnabled = UserDefaults.standard.object(forKey: "showActionsEnabled") as? Bool ?? true
        self.utilityActionsEnabled = UserDefaults.standard.object(forKey: "utilityActionsEnabled") as? Bool ?? true

        self.scheduleEnabledOnMessage = UserDefaults.standard.string(forKey: "scheduleEnabledOnMessage") ?? "SCHEDULE_ENABLED"
        self.scheduleEnabledOffMessage = UserDefaults.standard.string(forKey: "scheduleEnabledOffMessage") ?? "SCHEDULE_DISABLED"

        self.volumeLevel = UserDefaults.standard.object(forKey: "volumeLevel") as? Double ?? 0.75
        self.lastUnmutedVolumeLevel = UserDefaults.standard.object(forKey: "lastUnmutedVolumeLevel") as? Double ?? 0.75
        self.isMuted = UserDefaults.standard.object(forKey: "isMuted") as? Bool ?? false

        self.lowVolumeLevel = UserDefaults.standard.object(forKey: "lowVolumeLevel") as? Double ?? 0.35
        self.normalVolumeLevel = UserDefaults.standard.object(forKey: "normalVolumeLevel") as? Double ?? 0.75
        self.highVolumeLevel = UserDefaults.standard.object(forKey: "highVolumeLevel") as? Double
            ?? UserDefaults.standard.object(forKey: "openingVolumeLevel") as? Double
            ?? 0.90

        startPersistenceFailureMonitoring()

        self.actionDefinitions = PersistenceService.shared.loadActionDefinitions()
        self.scheduledEvents = PersistenceService.shared.loadScheduledEvents()
        self.scheduleEntries = PersistenceService.shared.loadScheduleEntries()
        self.scheduleExecutionHistory = PersistenceService.shared.loadScheduleExecutionHistory()
        surfaceRecentPersistenceFailures()
        pruneScheduleExecutionHistory(now: Date())

        purgeOldOperationalLogs()

        refreshLaunchAtStartupStatus()
        applyPreventComputerSleepPreference()
        applyDockIconVisibilityPreference()
        startSystemLifecycleMonitoring()
        startScheduleEngine()
        startDailyHealthLogging()

        logger.info("App launched. Project: \(projectName)")
    }

    deinit {
        logger.info("AppState deinitializing. Stopping schedule engine, lifecycle monitoring, sleep prevention, and health logging.")

        dailyHealthLogTimer?.invalidate()
        dailyHealthLogTimer = nil

        if let persistenceFailureObserver {
            NotificationCenter.default.removeObserver(persistenceFailureObserver)
        }

        scheduleEngine.stop()
        systemLifecycleService.stop()
        sleepPreventionService.disable()
    }

    // MARK: - Persistence Failure Monitoring

    private func startPersistenceFailureMonitoring() {
        persistenceFailureObserver = NotificationCenter.default.addObserver(
            forName: .persistenceServiceDidReportError,
            object: PersistenceService.shared,
            queue: .main
        ) { [weak self] notification in
            guard let self else {
                return
            }

            let message = notification.userInfo?["message"] as? String
                ?? "Persistence error. Check operational logs."

            self.controlStatus = .error
            self.lastMessage = message
        }
    }

    private func surfaceRecentPersistenceFailures() {
        let messages = PersistenceService.shared.consumeRecentErrorMessages()

        guard messages.isEmpty == false else {
            return
        }

        controlStatus = .error
        lastMessage = messages.last ?? "Persistence error. Check operational logs."
    }

    // MARK: - App Defaults

    fileprivate static func defaultSyslogDeviceName() -> String {
        let candidate = Host.current().localizedName
            ?? Host.current().name
            ?? "Launch-Control-Center"

        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)

        return trimmedCandidate.isEmpty ? "Launch-Control-Center" : trimmedCandidate
    }

    // MARK: - Dock Icon Visibility

    func setDashboardWindowIsOpen(_ isOpen: Bool) {
        dashboardWindowIsOpen = isOpen
        applyDockIconVisibilityPreference()
    }

    func applyDockIconVisibilityPreference() {
        let shouldShowDockIcon: Bool

        switch dockIconVisibilityPreference {
        case .always:
            shouldShowDockIcon = true

        case .never:
            shouldShowDockIcon = false

        case .showWhenDashboardWindowIsOpen:
            shouldShowDockIcon = dashboardWindowIsOpen
        }

        NSApplication.shared.setActivationPolicy(
            shouldShowDockIcon ? .regular : .accessory
        )
    }

    // MARK: - Launch at Startup

    func refreshLaunchAtStartupStatus() {
        let status = loginStartupService.status

        launchAtStartupEnabled = status == .enabled

        switch status {
        case .enabled:
            launchAtStartupStatusMessage = "Launch at startup is enabled."

        case .disabled:
            launchAtStartupStatusMessage = "Launch at startup is disabled."

        case .requiresApproval:
            launchAtStartupStatusMessage = "Launch at startup requires approval in System Settings."

        case .unavailable:
            launchAtStartupStatusMessage = "Launch at startup is unavailable for this build."

        case .unknown:
            launchAtStartupStatusMessage = "Launch at startup status unknown."
        }
    }

    func setLaunchAtStartupEnabled(_ enabled: Bool) {
        do {
            try loginStartupService.setEnabled(enabled)
            refreshLaunchAtStartupStatus()

            lastMessage = enabled
                ? "Launch at startup enabled"
                : "Launch at startup disabled"

            logger.info(lastMessage)
        } catch {
            refreshLaunchAtStartupStatus()
            controlStatus = .error
            lastMessage = "Launch at startup update failed: \(error.localizedDescription)"
            logger.error(lastMessage)
        }
    }

    // MARK: - Prevent Computer Sleep

    func refreshSleepPreventionStatus() {
        if preventComputerSleepEnabled {
            preventComputerSleepStatusMessage = sleepPreventionService.isActive
                ? "This Mac will not idle-sleep while Launch Control Center is running."
                : "Prevent computer sleep is enabled, but the macOS assertion is not active."
        } else {
            preventComputerSleepStatusMessage = "Prevent computer sleep is disabled."
        }
    }

    func setPreventComputerSleepEnabled(_ enabled: Bool) {
        if enabled {
            do {
                try sleepPreventionService.enable(
                    reason: "Launch Control Center is preventing idle system sleep."
                )

                preventComputerSleepEnabled = true
                preventComputerSleepStatusMessage = "This Mac will not idle-sleep while Launch Control Center is running."
                lastMessage = "Prevent computer sleep enabled"
                controlStatus = .idle
                logger.info(lastMessage)
            } catch {
                sleepPreventionService.disable()
                preventComputerSleepEnabled = false
                preventComputerSleepStatusMessage = "Prevent computer sleep failed: \(error.localizedDescription)"
                lastMessage = "Prevent computer sleep failed: \(error.localizedDescription)"
                controlStatus = .error
                logger.error(lastMessage)
            }
        } else {
            sleepPreventionService.disable()
            preventComputerSleepEnabled = false
            preventComputerSleepStatusMessage = "Prevent computer sleep is disabled."
            lastMessage = "Prevent computer sleep disabled"
            controlStatus = .idle
            logger.info(lastMessage)
        }
    }

    private func applyPreventComputerSleepPreference() {
        if preventComputerSleepEnabled {
            setPreventComputerSleepEnabled(true)
        } else {
            sleepPreventionService.disable()
            refreshSleepPreventionStatus()
        }
    }

    // MARK: - Operational Logs

    func openLogsFolder() {
        do {
            try logger.openLogsFolder()
            lastMessage = "Opened logs folder"
            controlStatus = .idle
            logger.info(lastMessage)
        } catch {
            lastMessage = "Could not open logs folder: \(error.localizedDescription)"
            controlStatus = .error
            logger.error(lastMessage)
        }
    }

    func purgeOldOperationalLogs() {
        do {
            let purgedCount = try logger.purgeLogFilesOlderThan(
                days: operationalLogRetentionDays
            )

            logger.info("Operational log startup purge complete. Retention: \(operationalLogRetentionDays) days. Deleted files: \(purgedCount).")
        } catch {
            lastMessage = "Operational log purge failed: \(error.localizedDescription)"
            logger.error(lastMessage)
        }
    }

    private static func clampedOperationalLogRetentionDays(_ value: Int) -> Int {
        min(max(value, 1), 3650)
    }

    private func clampedOperationalLogRetentionDays(_ value: Int) -> Int {
        AppState.clampedOperationalLogRetentionDays(value)
    }

    // MARK: - Daily Health Logging

    private func startDailyHealthLogging() {
        scheduleNextDailyHealthLog()
    }

    private func scheduleNextDailyHealthLog() {
        dailyHealthLogTimer?.invalidate()

        let calendar = Calendar.current

        let nextMidnight = calendar.nextDate(
            after: Date(),
            matching: DateComponents(
                hour: 0,
                minute: 0,
                second: 0
            ),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(86_400)

        let timer = Timer(
            fire: nextMidnight,
            interval: 0,
            repeats: false
        ) { [weak self] _ in
            self?.writeDailyHealthLog()
            self?.scheduleNextDailyHealthLog()
        }

        dailyHealthLogTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func writeDailyHealthLog() {
        let appUptime = Date().timeIntervalSince(appLaunchDate)
        let computerUptime = ProcessInfo.processInfo.systemUptime

        logger.info(
            """
            Daily health check. App uptime: \(formattedDuration(appUptime)). Computer uptime: \(formattedDuration(computerUptime)). Actions: \(actionDefinitions.count). Saved scheduled Events: \(scheduledEvents.count). Schedule entries: \(scheduleEntries.count). Running Actions: \(runningActionIDs.count). Processed occurrences today: \(processedScheduleOccurrences.count). Processed occurrences total: \(processedScheduleOccurrenceTotalCount). Execution history records: \(scheduleExecutionHistory.count). UDP listener: \(udpService.listenerState.rawValue). Sleep prevention active: \(sleepPreventionService.isActive).
            """
        )
    }

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(Int(interval), 0)
        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        }

        return "\(hours)h \(minutes)m"
    }

    // MARK: - System Lifecycle Monitoring

    private func startSystemLifecycleMonitoring() {
        systemLifecycleService.start { [weak self] event in
            guard let self else {
                return
            }

            switch event {
            case .willSleep(let date):
                self.handleSystemWillSleep(date)

            case .didWake(let date):
                self.handleSystemDidWake(date)

            case .didBecomeActive:
                self.handleAppDidBecomeActive()

            case .willTerminate(let date):
                self.handleAppWillTerminate(date)
            }
        }

        systemLifecycleStatusMessage = "System awake. Monitoring sleep and wake events."
    }

    private func handleSystemWillSleep(_ date: Date) {
        lastSystemSleepTime = date

        let timestamp = formattedEventTimestamp(date)

        systemLifecycleStatusMessage = "Mac will sleep at \(timestamp). Scheduled Events cannot run while the Mac is asleep."
        systemLifecycleWarningMessage = "Mac is going to sleep. Scheduled Events will not run while asleep."

        lastMessage = "Mac will sleep at \(timestamp)"
        logger.warning(lastMessage)
    }

    private func handleSystemDidWake(_ date: Date) {
        lastSystemWakeTime = date

        let timestamp = formattedEventTimestamp(date)

        systemLifecycleStatusMessage = "Mac woke at \(timestamp). Review scheduled Events before live operation."
        systemLifecycleWarningMessage = "Mac woke at \(timestamp). Scheduled Events may have been missed."

        lastMessage = "Mac woke at \(timestamp). Scheduled Events may have been missed."
        logger.warning(lastMessage)
    }

    private func handleAppDidBecomeActive() {
        if systemLifecycleWarningMessage == nil {
            systemLifecycleStatusMessage = "System active. Monitoring sleep and wake events."
        }
    }

    private func handleAppWillTerminate(_ date: Date) {
        let timestamp = formattedEventTimestamp(date)

        systemLifecycleStatusMessage = "Launch Control Center is quitting at \(timestamp)."
        lastMessage = "Launch Control Center quitting at \(timestamp)"
        logger.info(lastMessage)

        sleepPreventionService.disable()
    }

    func clearSystemLifecycleWarning() {
        systemLifecycleWarningMessage = nil

        if let lastSystemWakeTime {
            systemLifecycleStatusMessage = "Mac last woke at \(formattedEventTimestamp(lastSystemWakeTime)). Warning cleared."
        } else {
            systemLifecycleStatusMessage = "System awake. Monitoring sleep and wake events."
        }

        lastMessage = "Sleep/wake warning cleared"
        logger.info(lastMessage)
    }

    // MARK: - Import / Export

    func exportConfiguration(to url: URL) throws {
        let configuration = LaunchControlConfiguration(
            version: 1,
            exportedAt: Date(),
            projectName: projectName,
            projectNotes: projectNotes,
            use24HourTime: use24HourTime,
            weekStartDay: weekStartDay,
            syslogDeviceName: syslogDeviceName,
            operationalLogRetentionDays: operationalLogRetentionDays,
            dockIconVisibilityPreference: dockIconVisibilityPreference,
            launchAtStartupEnabled: launchAtStartupEnabled,
            preventComputerSleepEnabled: preventComputerSleepEnabled,
            incomingUDPPort: incomingUDPPort,
            defaultDestinationHost: defaultDestinationHost,
            defaultDestinationPort: defaultDestinationPort,
            volumeDestinationHost: volumeDestinationHost,
            volumeDestinationPort: volumeDestinationPort,
            volumeMessagePrefix: volumeMessagePrefix,
            volumeOutputMinimum: volumeOutputMinimum,
            volumeOutputMaximum: volumeOutputMaximum,
            volumeMuteLevel: volumeMuteLevel,
            showActionsEnabled: showActionsEnabled,
            utilityActionsEnabled: utilityActionsEnabled,
            scheduleEnabledOnMessage: scheduleEnabledOnMessage,
            scheduleEnabledOffMessage: scheduleEnabledOffMessage,
            volumeLevel: volumeLevel,
            lastUnmutedVolumeLevel: lastUnmutedVolumeLevel,
            isMuted: isMuted,
            lowVolumeLevel: lowVolumeLevel,
            normalVolumeLevel: normalVolumeLevel,
            highVolumeLevel: highVolumeLevel,
            actionDefinitions: actionDefinitions,
            scheduledEvents: scheduledEvents,
            scheduleEntries: scheduleEntries
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(configuration)
        try data.write(to: url, options: [.atomic])

        logger.info("Exported configuration to \(url.lastPathComponent)")
    }

    func importConfiguration(from url: URL) throws {
        let options = ConfigurationImportOptions(
            mode: .replaceSelected,
            importAppPreferences: true,
            importProjectPreferences: true,
            importVolumePreferences: true,
            importActions: true,
            importEvents: true,
            importScheduleEnableStates: true
        )

        _ = try importConfiguration(from: url, options: options)
    }

    func importConfiguration(
        from url: URL,
        options: ConfigurationImportOptions
    ) throws -> ConfigurationImportResult {
        let configuration = try decodeConfiguration(from: url)

        try validateConfigurationImport(options: options)
        try ensureNoActionsRunningForImport()
        do {
            try createAutomaticConfigurationBackup(reason: "pre-import")
        } catch {
            logger.error("Automatic pre-import backup failed: \(error.localizedDescription)")
            throw ConfigurationImportError.backupFailed(error.localizedDescription)
        }

        let reportLines = try applyConfiguration(
            configuration,
            options: options
        )

        var summary = auditSummary(for: currentConfigurationSnapshot())
        summary.issues.append(contentsOf: reportLines.map {
            ConfigurationAuditIssue(severity: .warning, message: $0)
        })

        return ConfigurationImportResult(
            summary: summary,
            reportLines: reportLines
        )
    }

    func previewConfigurationImport(from url: URL) throws -> ConfigurationImportPreview {
        let configuration = try decodeConfiguration(from: url)

        return ConfigurationImportPreview(
            fileName: url.lastPathComponent,
            summary: auditSummary(for: configuration)
        )
    }

    func currentConfigurationAuditSummary() -> ConfigurationAuditSummary {
        auditSummary(for: currentConfigurationSnapshot())
    }

    func availableConfigurationBackups() throws -> [ConfigurationBackupSnapshot] {
        let backupDirectory = try configurationBackupDirectory()
        let backupFiles = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "launchcontrol" }
        .sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        return backupFiles.map { backupFile in
            let modifiedDate = (try? backupFile.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast

            do {
                let configuration = try decodeConfiguration(from: backupFile)
                return ConfigurationBackupSnapshot(
                    id: backupFile.path,
                    url: backupFile,
                    fileName: backupFile.lastPathComponent,
                    createdAt: configuration.exportedAt,
                    summary: auditSummary(for: configuration),
                    errorMessage: nil
                )
            } catch {
                return ConfigurationBackupSnapshot(
                    id: backupFile.path,
                    url: backupFile,
                    fileName: backupFile.lastPathComponent,
                    createdAt: modifiedDate,
                    summary: nil,
                    errorMessage: error.localizedDescription
                )
            }
        }
    }

    func restoreConfigurationBackup(_ backup: ConfigurationBackupSnapshot) throws -> ConfigurationImportResult {
        try ensureNoActionsRunningForImport()

        let configuration = try decodeConfiguration(from: backup.url)

        do {
            try createAutomaticConfigurationBackup(reason: "pre-restore")
        } catch {
            logger.error("Automatic pre-restore backup failed: \(error.localizedDescription)")
            throw ConfigurationImportError.backupFailed(error.localizedDescription)
        }

        let options = ConfigurationImportOptions(
            mode: .replaceSelected,
            importAppPreferences: true,
            importProjectPreferences: true,
            importVolumePreferences: true,
            importActions: true,
            importEvents: true,
            importScheduleEnableStates: true
        )

        let reportLines = try applyConfiguration(
            configuration,
            options: options
        )

        var summary = auditSummary(for: currentConfigurationSnapshot())
        summary.issues.append(contentsOf: reportLines.map {
            ConfigurationAuditIssue(severity: .warning, message: $0)
        })

        lastMessage = "Restored configuration backup: \(backup.fileName)"
        logger.warning(lastMessage)

        return ConfigurationImportResult(
            summary: summary,
            reportLines: reportLines
        )
    }

    private func currentConfigurationSnapshot() -> LaunchControlConfiguration {
        LaunchControlConfiguration(
            version: 1,
            exportedAt: Date(),
            projectName: projectName,
            projectNotes: projectNotes,
            use24HourTime: use24HourTime,
            weekStartDay: weekStartDay,
            syslogDeviceName: syslogDeviceName,
            operationalLogRetentionDays: operationalLogRetentionDays,
            dockIconVisibilityPreference: dockIconVisibilityPreference,
            launchAtStartupEnabled: launchAtStartupEnabled,
            preventComputerSleepEnabled: preventComputerSleepEnabled,
            incomingUDPPort: incomingUDPPort,
            defaultDestinationHost: defaultDestinationHost,
            defaultDestinationPort: defaultDestinationPort,
            volumeDestinationHost: volumeDestinationHost,
            volumeDestinationPort: volumeDestinationPort,
            volumeMessagePrefix: volumeMessagePrefix,
            volumeOutputMinimum: volumeOutputMinimum,
            volumeOutputMaximum: volumeOutputMaximum,
            volumeMuteLevel: volumeMuteLevel,
            showActionsEnabled: showActionsEnabled,
            utilityActionsEnabled: utilityActionsEnabled,
            scheduleEnabledOnMessage: scheduleEnabledOnMessage,
            scheduleEnabledOffMessage: scheduleEnabledOffMessage,
            volumeLevel: volumeLevel,
            lastUnmutedVolumeLevel: lastUnmutedVolumeLevel,
            isMuted: isMuted,
            lowVolumeLevel: lowVolumeLevel,
            normalVolumeLevel: normalVolumeLevel,
            highVolumeLevel: highVolumeLevel,
            actionDefinitions: actionDefinitions,
            scheduledEvents: scheduledEvents,
            scheduleEntries: scheduleEntries
        )
    }

    private func createAutomaticConfigurationBackup(reason: String) throws {
        let backupDirectory = try configurationBackupDirectory()
        let timestamp = AppState.configurationBackupTimestampFormatter.string(from: Date())
        let project = sanitizedConfigurationBackupName(projectName)
        let safeReason = sanitizedConfigurationBackupName(reason)
        let fileURL = backupDirectory.appendingPathComponent(
            "\(timestamp)_\(project)_\(safeReason).launchcontrol"
        )

        let configuration = currentConfigurationSnapshot()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys,
            .withoutEscapingSlashes
        ]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(configuration)
        try data.write(to: fileURL, options: [.atomic])

        try pruneConfigurationBackups(in: backupDirectory, keepingNewest: 5)
        logger.info("Created automatic configuration backup: \(fileURL.lastPathComponent)")
    }

    private func configurationBackupDirectory() throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let backupDirectory = applicationSupportDirectory
            .appendingPathComponent("Launch Control Center", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)

        try FileManager.default.createDirectory(
            at: backupDirectory,
            withIntermediateDirectories: true
        )

        return backupDirectory
    }

    private func pruneConfigurationBackups(
        in backupDirectory: URL,
        keepingNewest limit: Int
    ) throws {
        let backupFiles = try FileManager.default.contentsOfDirectory(
            at: backupDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "launchcontrol" }
        .sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }

        guard backupFiles.count > limit else {
            return
        }

        for backupFile in backupFiles.dropFirst(limit) {
            try FileManager.default.removeItem(at: backupFile)
        }
    }

    private func sanitizedConfigurationBackupName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let collapsed = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .unicodeScalars
            .map { allowed.contains($0) ? String($0) : "_" }
            .joined()

        let name = collapsed
            .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        return name.isEmpty ? "Untitled_Project" : name
    }

    private static let configurationBackupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()

    private func decodeConfiguration(from url: URL) throws -> LaunchControlConfiguration {
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return try decoder.decode(
            LaunchControlConfiguration.self,
            from: data
        )
    }

    private func auditSummary(for configuration: LaunchControlConfiguration) -> ConfigurationAuditSummary {
        let actions = configuration.actionDefinitions
        let entries = configuration.scheduleEntries
        let actionIDs = Set(actions.map { $0.id })

        let standaloneEntries = entries.filter { $0.repeatsDaily == false }
        let recurringEntries = entries.filter { $0.repeatsDaily }
        let intervalEntries = recurringEntries.filter { $0.repeatMode == .intervalDuringDay }
        let disabledEntries = entries.filter { $0.enabled == false }

        var finiteGeneratedEventCount = 0
        var openEndedSeriesCount = 0
        var issues: [ConfigurationAuditIssue] = []

        if actions.isEmpty {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .warning,
                    message: "Configuration contains no Actions."
                )
            )
        }

        if entries.isEmpty {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .warning,
                    message: "Configuration contains no scheduled Events."
                )
            )
        }

        let missingActionCount = entries.filter { actionIDs.contains($0.actionDefinitionID) == false }.count
        if missingActionCount > 0 {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .error,
                    message: "\(missingActionCount) scheduled Event\(missingActionCount == 1 ? "" : "s") reference missing Actions."
                )
            )
        }

        for entry in entries {
            let entryName = configurationActionName(
                for: entry,
                actions: actions
            )

            if entry.repeatsDaily {
                if ScheduleEntryFormatter.selectedWeekdays(for: entry).isEmpty {
                    issues.append(
                        ConfigurationAuditIssue(
                            severity: .error,
                            message: "Recurring Event ‘\(entryName)’ has no repeat days selected."
                        )
                    )
                }

                if let repeatUntil = entry.repeatUntil {
                    let startDay = Calendar.current.startOfDay(for: entry.startDate)
                    let endDay = Calendar.current.startOfDay(for: repeatUntil)

                    if endDay < startDay {
                        issues.append(
                            ConfigurationAuditIssue(
                                severity: .error,
                                message: "Recurring Event ‘\(entryName)’ has an end date before its start date."
                            )
                        )
                    } else {
                        finiteGeneratedEventCount += generatedEventCount(
                            for: entry,
                            through: endDay
                        )
                    }
                } else {
                    openEndedSeriesCount += 1
                }
            } else {
                finiteGeneratedEventCount += 1
            }

            if entry.repeatMode == .intervalDuringDay {
                validateIntervalEntry(
                    entry,
                    entryName: entryName,
                    issues: &issues
                )
            }
        }

        if finiteGeneratedEventCount > 1_000 {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .warning,
                    message: "Finite schedules generate \(finiteGeneratedEventCount) Events. Review high-volume series before live use."
                )
            )
        }

        if openEndedSeriesCount > 0 {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .warning,
                    message: "\(openEndedSeriesCount) recurring series have no end date and will continue indefinitely."
                )
            )
        }

        let removedOccurrenceCount = entries.reduce(0) { partialResult, entry in
            partialResult
            + entry.excludedOccurrenceKeys.count
            + entry.excludedOccurrenceDates.count
        }

        return ConfigurationAuditSummary(
            projectName: configuration.projectName,
            version: configuration.version,
            exportedAt: configuration.exportedAt,
            actionCount: actions.count,
            eventCount: entries.count,
            standaloneEventCount: standaloneEntries.count,
            recurringSeriesCount: recurringEntries.count,
            intervalSeriesCount: intervalEntries.count,
            disabledEventCount: disabledEntries.count,
            removedOccurrenceCount: removedOccurrenceCount,
            finiteGeneratedEventCount: finiteGeneratedEventCount,
            openEndedSeriesCount: openEndedSeriesCount,
            issues: issues
        )
    }

    private func validateIntervalEntry(
        _ entry: ScheduleEntry,
        entryName: String,
        issues: inout [ConfigurationAuditIssue]
    ) {
        guard entry.repeatsDaily else {
            return
        }

        guard let intervalMinutes = entry.intervalMinutes, intervalMinutes > 0 else {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .error,
                    message: "Interval series ‘\(entryName)’ has an invalid repeat interval."
                )
            )
            return
        }

        if intervalMinutes < 5 {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .warning,
                    message: "Interval series ‘\(entryName)’ repeats more often than every 5 minutes."
                )
            )
        }

        guard let intervalEndTime = entry.intervalEndTime else {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .error,
                    message: "Interval series ‘\(entryName)’ is missing an end time."
                )
            )
            return
        }

        let calendar = Calendar.current
        let startSeconds = secondsSinceStartOfDay(
            for: entry.startDate,
            calendar: calendar
        )
        let endSeconds = secondsSinceStartOfDay(
            for: intervalEndTime,
            calendar: calendar
        )

        if endSeconds <= startSeconds {
            issues.append(
                ConfigurationAuditIssue(
                    severity: .error,
                    message: "Interval series ‘\(entryName)’ crosses midnight. Split it into separate same-day series."
                )
            )
        }
    }

    private func generatedEventCount(
        for entry: ScheduleEntry,
        through endDay: Date
    ) -> Int {
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: entry.startDate)

        guard endDay >= startDay else {
            return 0
        }

        var count = 0
        var day = startDay

        while day <= endDay {
            count += ScheduleEntryFormatter.occurrenceDates(
                for: entry,
                on: day,
                calendar: calendar
            ).count

            guard let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: day
            ) else {
                break
            }

            day = nextDay
        }

        return count
    }

    private func configurationActionName(
        for entry: ScheduleEntry,
        actions: [ActionDefinition]
    ) -> String {
        if let seriesName = entry.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines),
           seriesName.isEmpty == false {
            return seriesName
        }

        return actions.first { $0.id == entry.actionDefinitionID }?.name ?? "Missing Action"
    }

    private func secondsSinceStartOfDay(
        for date: Date,
        calendar: Calendar
    ) -> Int {
        let components = calendar.dateComponents(
            [.hour, .minute, .second],
            from: date
        )

        return (components.hour ?? 0) * 3600
            + (components.minute ?? 0) * 60
            + (components.second ?? 0)
    }

    private func validateConfigurationImport(options: ConfigurationImportOptions) throws {
        if options.importEvents && options.importActions == false {
            throw ConfigurationImportError.invalidSelection("Events cannot be imported unless Actions are also imported. Events need valid Action references.")
        }
    }

    private func ensureNoActionsRunningForImport() throws {
        guard runningActionIDs.isEmpty else {
            let runningCount = runningActionIDs.count
            let message = "Configuration import blocked because \(runningCount) Action\(runningCount == 1 ? " is" : "s are") still running."

            lastMessage = message
            logger.warning(message)

            throw ConfigurationImportError.actionsRunning(count: runningCount)
        }
    }

    private func applyConfiguration(_ configuration: LaunchControlConfiguration) {
        let options = ConfigurationImportOptions(
            mode: .replaceSelected,
            importAppPreferences: true,
            importProjectPreferences: true,
            importVolumePreferences: true,
            importActions: true,
            importEvents: true,
            importScheduleEnableStates: true
        )

        _ = try? applyConfiguration(configuration, options: options)
    }

    @discardableResult
    private func applyConfiguration(
        _ configuration: LaunchControlConfiguration,
        options: ConfigurationImportOptions
    ) throws -> [String] {
        var reportLines: [String] = []

        if options.mode == .newBlankShow {
            applyBlankShowBaseline()
            reportLines.append("Started from a blank show before import.")
        }

        if options.importAppPreferences {
            try applyAppPreferences(from: configuration)
        }

        if options.importProjectPreferences {
            applyProjectPreferences(from: configuration)
        }

        if options.importVolumePreferences {
            applyVolumePreferences(from: configuration)
        }

        if options.importScheduleEnableStates {
            applyScheduleEnableStates(from: configuration)
        }

        var actionIDMap: [UUID: UUID] = [:]

        if options.importActions {
            switch options.mode {
            case .mergeWithCurrent:
                let result = mergedActions(from: configuration.actionDefinitions)
                actionDefinitions = result.actions
                actionIDMap = result.idMap
                reportLines.append(contentsOf: result.reportLines)

            case .replaceSelected, .newBlankShow:
                actionDefinitions = configuration.actionDefinitions
                actionIDMap = Dictionary(
                    uniqueKeysWithValues: configuration.actionDefinitions.map { ($0.id, $0.id) }
                )
            }
        }

        if options.importEvents {
            switch options.mode {
            case .mergeWithCurrent:
                let result = mergedScheduleEntries(
                    from: configuration.scheduleEntries,
                    actionIDMap: actionIDMap
                )
                scheduleEntries = result.entries
                scheduledEvents.append(contentsOf: configuration.scheduledEvents)
                reportLines.append(contentsOf: result.reportLines)

            case .replaceSelected, .newBlankShow:
                scheduleEntries = configuration.scheduleEntries.map { entry in
                    remappedScheduleEntry(entry, actionIDMap: actionIDMap)
                }
                scheduledEvents = configuration.scheduledEvents
            }

            scheduleExecutionHistory = []
            PersistenceService.shared.deleteScheduleExecutionHistory()
            resetScheduleOccurrenceGuards()
            lastEventMessage = "No Event has run yet"
        }

        reportLines.append(contentsOf: configurationIntegrityReport())

        refreshLaunchAtStartupStatus()
        refreshSleepPreventionStatus()

        lastMessage = "Imported configuration: \(configuration.projectName)"
        controlStatus = .idle
        logger.info(lastMessage)

        return reportLines
    }

    private func applyAppPreferences(from configuration: LaunchControlConfiguration) throws {
        use24HourTime = configuration.use24HourTime
        weekStartDay = configuration.weekStartDay
        syslogDeviceName = configuration.syslogDeviceName
        operationalLogRetentionDays = clampedOperationalLogRetentionDays(configuration.operationalLogRetentionDays)
        dockIconVisibilityPreference = configuration.dockIconVisibilityPreference

        setPreventComputerSleepEnabled(configuration.preventComputerSleepEnabled)
        try loginStartupService.setEnabled(configuration.launchAtStartupEnabled)
    }

    private func applyProjectPreferences(from configuration: LaunchControlConfiguration) {
        projectName = configuration.projectName
        projectNotes = configuration.projectNotes
        incomingUDPPort = configuration.incomingUDPPort
        defaultDestinationHost = configuration.defaultDestinationHost
        defaultDestinationPort = configuration.defaultDestinationPort
    }

    private func applyVolumePreferences(from configuration: LaunchControlConfiguration) {
        volumePreferenceOutputIsSuspended = true
        volumeDestinationHost = configuration.volumeDestinationHost
        volumeDestinationPort = configuration.volumeDestinationPort
        volumeMessagePrefix = configuration.volumeMessagePrefix
        volumeOutputMinimum = configuration.volumeOutputMinimum
        volumeOutputMaximum = configuration.volumeOutputMaximum
        volumeMuteLevel = configuration.volumeMuteLevel
        volumeLevel = configuration.volumeLevel
        lastUnmutedVolumeLevel = configuration.lastUnmutedVolumeLevel
        isMuted = configuration.isMuted
        lowVolumeLevel = configuration.lowVolumeLevel
        normalVolumeLevel = configuration.normalVolumeLevel
        highVolumeLevel = configuration.highVolumeLevel
        volumePreferenceOutputIsSuspended = false
    }

    private func applyScheduleEnableStates(from configuration: LaunchControlConfiguration) {
        showActionsEnabled = configuration.showActionsEnabled
        utilityActionsEnabled = configuration.utilityActionsEnabled
        scheduleEnabledOnMessage = configuration.scheduleEnabledOnMessage
        scheduleEnabledOffMessage = configuration.scheduleEnabledOffMessage
    }

    private func applyBlankShowBaseline() {
        projectName = "Untitled Project"
        projectNotes = ""
        incomingUDPPort = 8000
        defaultDestinationHost = "127.0.0.1"
        defaultDestinationPort = 8001

        volumePreferenceOutputIsSuspended = true
        volumeDestinationHost = "127.0.0.1"
        volumeDestinationPort = 8001
        volumeMessagePrefix = "/cue/selected/level/0/"
        volumeOutputMinimum = -60
        volumeOutputMaximum = 12
        volumeMuteLevel = -60
        volumeLevel = 0.75
        lastUnmutedVolumeLevel = 0.75
        isMuted = false
        lowVolumeLevel = 0.35
        normalVolumeLevel = 0.75
        highVolumeLevel = 0.90
        volumePreferenceOutputIsSuspended = false

        showActionsEnabled = true
        utilityActionsEnabled = true
        scheduleEnabledOnMessage = "SCHEDULE_ENABLED"
        scheduleEnabledOffMessage = "SCHEDULE_DISABLED"

        actionDefinitions = []
        PersistenceService.shared.deleteActionDefinitions()
        deleteEventsAndScheduleHistory()
    }

    private func mergedActions(
        from importedActions: [ActionDefinition]
    ) -> (actions: [ActionDefinition], idMap: [UUID: UUID], reportLines: [String]) {
        var result = actionDefinitions
        var existingIDs = Set(result.map { $0.id })
        var existingNames = Set(result.map { $0.name.lowercased() })
        var idMap: [UUID: UUID] = [:]
        var reportLines: [String] = []

        for importedAction in importedActions {
            var action = importedAction
            let idConflict = existingIDs.contains(action.id)
            let nameConflict = existingNames.contains(action.name.lowercased())

            if idConflict || nameConflict {
                let originalName = action.name
                action.id = UUID()
                action.name = uniqueImportedName(
                    baseName: originalName,
                    existingNames: existingNames
                )
                reportLines.append("Action conflict: imported \"\(originalName)\" as \"\(action.name)\".")
            }

            idMap[importedAction.id] = action.id
            result.append(action)
            existingIDs.insert(action.id)
            existingNames.insert(action.name.lowercased())
        }

        return (result, idMap, reportLines)
    }

    private func mergedScheduleEntries(
        from importedEntries: [ScheduleEntry],
        actionIDMap: [UUID: UUID]
    ) -> (entries: [ScheduleEntry], reportLines: [String]) {
        var result = scheduleEntries
        var existingEntryIDs = Set(result.map { $0.id })
        var existingSeriesIDs = Set(result.compactMap { $0.seriesID })
        var existingSeriesNames = Set(result.compactMap { $0.seriesName?.lowercased() })
        var seriesIDMap: [UUID: UUID] = [:]
        var reportLines: [String] = []

        for importedEntry in importedEntries {
            var entry = remappedScheduleEntry(importedEntry, actionIDMap: actionIDMap)

            if existingEntryIDs.contains(entry.id) {
                entry.id = UUID()
                reportLines.append("Event conflict: imported Event with a new ID.")
            }

            if let seriesID = entry.seriesID {
                if let mappedSeriesID = seriesIDMap[seriesID] {
                    entry.seriesID = mappedSeriesID
                } else if existingSeriesIDs.contains(seriesID) {
                    let newSeriesID = UUID()
                    seriesIDMap[seriesID] = newSeriesID
                    entry.seriesID = newSeriesID
                    reportLines.append("Series conflict: imported recurring series with a new ID.")
                } else {
                    seriesIDMap[seriesID] = seriesID
                    existingSeriesIDs.insert(seriesID)
                }
            }

            if let seriesName = entry.seriesName,
               existingSeriesNames.contains(seriesName.lowercased()) {
                let newName = uniqueImportedName(
                    baseName: seriesName,
                    existingNames: existingSeriesNames
                )
                entry.seriesName = newName
                existingSeriesNames.insert(newName.lowercased())
                reportLines.append("Series name conflict: imported \"\(seriesName)\" as \"\(newName)\".")
            } else if let seriesName = entry.seriesName {
                existingSeriesNames.insert(seriesName.lowercased())
            }

            result.append(entry)
            existingEntryIDs.insert(entry.id)
        }

        return (result, reportLines)
    }

    private func remappedScheduleEntry(
        _ entry: ScheduleEntry,
        actionIDMap: [UUID: UUID]
    ) -> ScheduleEntry {
        var remapped = entry

        if let mappedActionID = actionIDMap[entry.actionDefinitionID] {
            remapped.actionDefinitionID = mappedActionID
        }

        return remapped
    }

    private func uniqueImportedName(
        baseName: String,
        existingNames: Set<String>
    ) -> String {
        let trimmedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmedBaseName.isEmpty ? "Imported" : trimmedBaseName
        let copyName = "\(base) copy"

        if existingNames.contains(copyName.lowercased()) == false {
            return copyName
        }

        var index = 2
        while true {
            let candidate = "\(base) copy \(index)"
            if existingNames.contains(candidate.lowercased()) == false {
                return candidate
            }
            index += 1
        }
    }

    private func configurationIntegrityReport() -> [String] {
        let actionIDs = Set(actionDefinitions.map { $0.id })
        let missingActionEvents = scheduleEntries.filter {
            actionIDs.contains($0.actionDefinitionID) == false
        }

        guard missingActionEvents.isEmpty == false else {
            return []
        }

        return ["\(missingActionEvents.count) Event\(missingActionEvents.count == 1 ? "" : "s") reference missing Actions after import."]
    }

    // MARK: - Reset / Destructive Actions

    func restoreDefaultAppPreferences() throws {
        try ensureNoActionsRunningForReset()
        do {
            try createAutomaticConfigurationBackup(reason: "restore-default-app-preferences")
        } catch {
            logger.error("Automatic reset backup failed: \(error.localizedDescription)")
            throw AppResetError.backupFailed(error.localizedDescription)
        }

        use24HourTime = true
        weekStartDay = 1
        operationalLogRetentionDays = 90
        syslogDeviceName = AppState.defaultSyslogDeviceName()
        dockIconVisibilityPreference = .showWhenDashboardWindowIsOpen

        setPreventComputerSleepEnabled(false)

        try loginStartupService.setEnabled(false)
        refreshLaunchAtStartupStatus()
        refreshSleepPreventionStatus()

        controlStatus = .idle
        lastMessage = "Restored default app preferences"
        logger.warning(lastMessage)
    }

    func restoreDefaultProjectPreferences() throws {
        try ensureNoActionsRunningForReset()
        do {
            try createAutomaticConfigurationBackup(reason: "restore-default-project-preferences")
        } catch {
            logger.error("Automatic reset backup failed: \(error.localizedDescription)")
            throw AppResetError.backupFailed(error.localizedDescription)
        }

        projectName = "Untitled Project"
        projectNotes = ""

        incomingUDPPort = 8000
        defaultDestinationHost = "127.0.0.1"
        defaultDestinationPort = 8001

        volumePreferenceOutputIsSuspended = true
        volumeDestinationHost = "127.0.0.1"
        volumeDestinationPort = 8001
        volumeMessagePrefix = "/cue/selected/level/0/"
        volumeOutputMinimum = -60
        volumeOutputMaximum = 12
        volumeMuteLevel = -60
        volumeLevel = 0.75
        lastUnmutedVolumeLevel = 0.75
        isMuted = false
        lowVolumeLevel = 0.35
        normalVolumeLevel = 0.75
        highVolumeLevel = 0.90
        volumePreferenceOutputIsSuspended = false

        showActionsEnabled = true
        utilityActionsEnabled = true
        scheduleEnabledOnMessage = "SCHEDULE_ENABLED"
        scheduleEnabledOffMessage = "SCHEDULE_DISABLED"

        sendVolumeLevel()

        controlStatus = .idle
        lastMessage = "Restored default project preferences"
        logger.warning(lastMessage)
    }

    func deleteAllEvents() throws {
        try ensureNoActionsRunningForReset()
        do {
            try createAutomaticConfigurationBackup(reason: "delete-all-events")
        } catch {
            logger.error("Automatic reset backup failed: \(error.localizedDescription)")
            throw AppResetError.backupFailed(error.localizedDescription)
        }

        deleteEventsAndScheduleHistory()

        controlStatus = .idle
        lastMessage = "Deleted all Events"
        logger.warning(lastMessage)
    }

    func deleteAllActionsAndEvents() throws {
        try ensureNoActionsRunningForReset()
        do {
            try createAutomaticConfigurationBackup(reason: "delete-all-actions-and-events")
        } catch {
            logger.error("Automatic reset backup failed: \(error.localizedDescription)")
            throw AppResetError.backupFailed(error.localizedDescription)
        }

        actionDefinitions = []
        PersistenceService.shared.deleteActionDefinitions()

        deleteEventsAndScheduleHistory()

        controlStatus = .idle
        lastMessage = "Deleted all Actions and Events"
        logger.warning(lastMessage)
    }

    private func ensureNoActionsRunningForReset() throws {
        guard runningActionIDs.isEmpty else {
            let runningCount = runningActionIDs.count
            let message = "Reset blocked because \(runningCount) Action\(runningCount == 1 ? " is" : "s are") still running."

            lastMessage = message
            logger.warning(message)

            throw AppResetError.actionsRunning(count: runningCount)
        }
    }

    private func deleteEventsAndScheduleHistory() {
        scheduledEvents = []
        scheduleEntries = []
        scheduleExecutionHistory = []

        PersistenceService.shared.deleteScheduledEvents()
        PersistenceService.shared.deleteScheduleEntries()
        PersistenceService.shared.deleteScheduleExecutionHistory()

        resetScheduleOccurrenceGuards()
        lastEventMessage = "No Event has run yet"
    }

    private func resetScheduleOccurrenceGuards() {
        processedScheduleOccurrences.removeAll()
        processedScheduleOccurrenceDay = Calendar.current.startOfDay(for: Date())
        processedScheduleOccurrenceTotalCount = 0
    }

    // MARK: - Schedule Toggles

    func setShowActionsEnabled(_ enabled: Bool) {
        showActionsEnabled = enabled
        lastMessage = enabled ? "Show Actions schedule enabled" : "Show Actions schedule disabled"
        logger.info(lastMessage)
    }

    func setUtilityActionsEnabled(_ enabled: Bool) {
        utilityActionsEnabled = enabled
        lastMessage = enabled ? "Utility Actions schedule enabled" : "Utility Actions schedule disabled"
        logger.info(lastMessage)
    }

    // MARK: - Action Execution

    @MainActor
    func runAction(_ action: ActionDefinition) {
        startTrackedActionTask(
            action,
            source: .manual,
            visitedActionIDs: Set([action.id])
        )
    }

    @MainActor
    private func runAction(
        _ action: ActionDefinition,
        source: ActionRunSource
    ) {
        startTrackedActionTask(
            action,
            source: source,
            visitedActionIDs: Set([action.id])
        )
    }

    @MainActor
    private func startTrackedActionTask(
        _ action: ActionDefinition,
        source: ActionRunSource,
        visitedActionIDs: Set<UUID>,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard runningActionIDs.contains(action.id) == false,
              runningActionTasks[action.id] == nil else {
            updateDuplicateActionMessage(action, source: source)
            completion?(false)
            return
        }

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            let completed = await self.executeAction(
                action,
                source: source,
                visitedActionIDs: visitedActionIDs
            )

            await MainActor.run {
                self.runningActionTasks[action.id] = nil
                self.updateRunningActionCount()
                completion?(completed)
            }
        }

        runningActionTasks[action.id] = task
        updateRunningActionCount()
    }

    @MainActor
    func cancelRunningActions() {
        let cancelCount = max(runningActionCount, runningActionTasks.count)

        guard cancelCount > 0 else {
            lastMessage = "No running Actions to cancel"
            logger.info(lastMessage)
            return
        }

        for task in runningActionTasks.values {
            task.cancel()
        }

        lastMessage = "Cancel requested for \(cancelCount) running Action\(cancelCount == 1 ? "" : "s")"
        logger.warning(lastMessage)
    }

    @MainActor
    @discardableResult
    private func executeAction(
        _ action: ActionDefinition,
        source: ActionRunSource,
        visitedActionIDs: Set<UUID>
    ) async -> Bool {
        guard beginActionRun(action, source: source) else {
            return false
        }

        defer {
            finishActionRun(action)
        }

        let actionStartDate = Date()
        controlStatus = .sending

        switch source {
        case .manual:
            lastMessage = "Manual Action started: \(action.name)"
            logger.info(lastMessage)

        case .scheduled:
            lastMessage = "Scheduled Action started: \(action.name)"
            logger.info(lastMessage)

        case .automated:
            lastMessage = "Automated Action started: \(action.name)"
            logger.info(lastMessage)
        }

        let completed: Bool

        switch action.type {
        case .show:
            completed = await executeShowAction(
                action,
                actionStartDate: actionStartDate
            )

        case .utility:
            completed = await executeUtilityAction(
                action,
                visitedActionIDs: visitedActionIDs,
                actionStartDate: actionStartDate
            )
        }

        guard completed else {
            return false
        }

        let timestamp = formattedEventTimestamp(Date())

        switch source {
        case .manual:
            lastMessage = "Ran Manual Action: \(action.name)"

        case .scheduled:
            lastMessage = "Ran Scheduled Action: \(action.name)"

        case .automated:
            lastMessage = "Ran Automated Action: \(action.name)"
        }

        lastEventMessage = "\(timestamp) — \(action.name)"
        controlStatus = runningActionIDs.count > 1 ? .sending : .idle
        logger.info(lastMessage)
        return true
    }

    @MainActor
    private func beginActionRun(
        _ action: ActionDefinition,
        source: ActionRunSource
    ) -> Bool {
        guard runningActionIDs.contains(action.id) == false else {
            updateDuplicateActionMessage(action, source: source)
            return false
        }

        runningActionIDs.insert(action.id)
        updateRunningActionCount()
        return true
    }

    @MainActor
    private func finishActionRun(_ action: ActionDefinition) {
        runningActionIDs.remove(action.id)
        updateRunningActionCount()

        if runningActionIDs.isEmpty,
           controlStatus == .sending {
            controlStatus = .idle
        }
    }

    @MainActor
    private func updateRunningActionCount() {
        runningActionCount = runningActionIDs.count
    }

    @MainActor
    private func updateDuplicateActionMessage(
        _ action: ActionDefinition,
        source: ActionRunSource
    ) {
        switch source {
        case .manual:
            lastMessage = "Action already running: \(action.name)"

        case .scheduled:
            lastMessage = "Skipped scheduled Action already running: \(action.name)"

        case .automated:
            lastMessage = "Skipped Automated Action already running: \(action.name)"
        }

        logger.warning(lastMessage)
    }

    @MainActor
    private func actionIsRunning(_ actionID: UUID) -> Bool {
        runningActionIDs.contains(actionID)
    }

    @MainActor
    private func actionRuntimeIsAvailable(
        actionName: String,
        actionStartDate: Date
    ) -> Bool {
        let elapsed = Date().timeIntervalSince(actionStartDate)

        guard elapsed < maximumActionRuntimeSeconds else {
            lastMessage = "Action runtime exceeded 2-minute maximum: \(actionName)"
            controlStatus = .error
            logger.error(lastMessage)
            return false
        }

        return true
    }

    @MainActor
    private func actionCancellationAllowsContinue(actionName: String) -> Bool {
        guard Task.isCancelled == false else {
            lastMessage = "Action cancelled: \(actionName)"
            logger.warning(lastMessage)
            return false
        }

        return true
    }

    @MainActor
    private func executeShowAction(
        _ action: ActionDefinition,
        actionStartDate: Date
    ) async -> Bool {
        guard action.commands.isEmpty == false else {
            lastMessage = "Show Action has no Message Steps: \(action.name)"
            logger.warning(lastMessage)
            return false
        }

        guard actionCancellationAllowsContinue(actionName: action.name) else {
            return false
        }

        for command in action.commands {
            guard actionCancellationAllowsContinue(actionName: action.name) else {
                return false
            }

            guard actionRuntimeIsAvailable(
                actionName: action.name,
                actionStartDate: actionStartDate
            ) else {
                return false
            }

            let delayCompleted = await waitForDelay(
                command.delaySeconds,
                actionName: action.name,
                actionStartDate: actionStartDate
            )

            guard delayCompleted else {
                return false
            }

            guard actionCancellationAllowsContinue(actionName: action.name) else {
                return false
            }

            guard sendMessageCommand(command) else {
                controlStatus = .error
                return false
            }

            lastMessage = "Sent \(command.messageType.rawValue) Step: \(command.name)"
        }

        return true
    }

    @MainActor
    private func executeUtilityAction(
        _ action: ActionDefinition,
        visitedActionIDs: Set<UUID>,
        actionStartDate: Date
    ) async -> Bool {
        guard action.utilityCommands.isEmpty == false else {
            lastMessage = "Utility Action has no Steps: \(action.name)"
            logger.warning(lastMessage)
            return false
        }

        guard actionCancellationAllowsContinue(actionName: action.name) else {
            return false
        }

        for command in action.utilityCommands {
            guard actionCancellationAllowsContinue(actionName: action.name) else {
                return false
            }

            guard actionRuntimeIsAvailable(
                actionName: action.name,
                actionStartDate: actionStartDate
            ) else {
                return false
            }

            let delayCompleted = await waitForDelay(
                command.delaySeconds,
                actionName: action.name,
                actionStartDate: actionStartDate
            )

            guard delayCompleted else {
                return false
            }

            guard actionCancellationAllowsContinue(actionName: action.name) else {
                return false
            }

            let commandCompleted = await executeUtilityCommand(
                command,
                parentAction: action,
                visitedActionIDs: visitedActionIDs,
                actionStartDate: actionStartDate
            )

            guard commandCompleted else {
                return false
            }
        }

        return true
    }

    @MainActor
    private func executeUtilityCommand(
        _ command: UtilityCommand,
        parentAction: ActionDefinition,
        visitedActionIDs: Set<UUID>,
        actionStartDate: Date
    ) async -> Bool {
        guard actionRuntimeIsAvailable(
            actionName: parentAction.name,
            actionStartDate: actionStartDate
        ) else {
            return false
        }

        guard actionCancellationAllowsContinue(actionName: parentAction.name) else {
            return false
        }

        switch command.kind {
        case .setVolume:
            setVolume(command.volumeLevel)
            lastMessage = "Utility Step: set volume to \(Int(command.volumeLevel * 100))%"
            return true

        case .setShowScheduleEnabled:
            setShowActionsEnabled(command.showScheduleEnabled)
            return true

        case .setUtilityScheduleEnabled:
            setUtilityActionsEnabled(command.utilityScheduleEnabled)
            return true

        case .runAction:
            return await executeRunActionUtilityCommand(
                command,
                parentAction: parentAction,
                visitedActionIDs: visitedActionIDs,
                actionStartDate: actionStartDate
            )

        case .sendUDP:
            sendUtilityUDPCommand(command)
            return controlStatus != .error
        }
    }

    @MainActor
    private func executeRunActionUtilityCommand(
        _ command: UtilityCommand,
        parentAction: ActionDefinition,
        visitedActionIDs: Set<UUID>,
        actionStartDate: Date
    ) async -> Bool {
        guard let actionID = command.actionDefinitionID else {
            lastMessage = "Utility Step skipped: no Action selected"
            logger.warning(lastMessage)
            return false
        }

        guard actionID != parentAction.id else {
            lastMessage = "Utility Step skipped: Action cannot run itself"
            logger.warning(lastMessage)
            return false
        }

        guard visitedActionIDs.contains(actionID) == false else {
            lastMessage = "Utility Step skipped: recursive Action loop blocked"
            logger.warning(lastMessage)
            return false
        }

        guard let targetAction = actionDefinitions.first(where: {
            $0.id == actionID
        }) else {
            lastMessage = "Utility Step skipped: selected Action not found"
            logger.warning(lastMessage)
            return false
        }

        guard actionIsRunning(actionID) == false else {
            lastMessage = "Utility Step skipped: Action already running: \(targetAction.name)"
            logger.warning(lastMessage)
            return false
        }

        guard actionRuntimeIsAvailable(
            actionName: parentAction.name,
            actionStartDate: actionStartDate
        ) else {
            return false
        }

        guard actionCancellationAllowsContinue(actionName: parentAction.name) else {
            return false
        }

        var updatedVisitedActionIDs = visitedActionIDs
        updatedVisitedActionIDs.insert(actionID)

        _ = await executeAction(
            targetAction,
            source: .automated,
            visitedActionIDs: updatedVisitedActionIDs
        )

        return actionRuntimeIsAvailable(
            actionName: parentAction.name,
            actionStartDate: actionStartDate
        )
    }

    @MainActor
    private func waitForDelay(
        _ delaySeconds: Double,
        actionName: String,
        actionStartDate: Date
    ) async -> Bool {
        let delay = max(delaySeconds, 0)

        guard actionCancellationAllowsContinue(actionName: actionName) else {
            return false
        }

        guard delay > 0 else {
            return actionRuntimeIsAvailable(
                actionName: actionName,
                actionStartDate: actionStartDate
            )
        }

        let elapsed = Date().timeIntervalSince(actionStartDate)
        let remainingRuntime = maximumActionRuntimeSeconds - elapsed

        guard remainingRuntime > 0 else {
            return actionRuntimeIsAvailable(
                actionName: actionName,
                actionStartDate: actionStartDate
            )
        }

        let sleepDuration = min(delay, remainingRuntime)
        let nanoseconds = UInt64(sleepDuration * 1_000_000_000)

        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            controlStatus = .idle
            lastMessage = "Action cancelled: \(actionName)"
            logger.warning(lastMessage)
            return false
        }

        if delay > remainingRuntime {
            lastMessage = "Action runtime exceeded 2-minute maximum: \(actionName)"
            controlStatus = .error
            logger.error(lastMessage)
            return false
        }

        return actionRuntimeIsAvailable(
            actionName: actionName,
            actionStartDate: actionStartDate
        )
    }

    private func availableSourceIPAddresses() -> Set<String> {
        Set(
            NetworkInventoryService.currentIPv4Interfaces()
                .filter { $0.isUp && $0.isRunning }
                .map(\.ipv4Address)
        )
    }

    @MainActor
    private func resolvedUDPSource(
        requestedSourceIPAddress: String,
        unavailablePolicy: UDPSourceUnavailablePolicy,
        stepName: String
    ) -> (sourceIPAddress: String?, shouldSend: Bool) {
        let requested = requestedSourceIPAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        guard requested.isEmpty == false else {
            return (nil, true)
        }

        guard availableSourceIPAddresses().contains(requested) else {
            let message = "Selected UDP source IP \(requested) is unavailable for Step: \(stepName)."

            switch unavailablePolicy {
            case .useAutomaticRouting:
                logger.warning("\(message) Using Automatic Routing.")
                lastMessage = "\(message) Using Automatic Routing."
                return (nil, true)

            case .doNotSend:
                logger.error("\(message) UDP message not sent.")
                lastMessage = "\(message) UDP message not sent."
                controlStatus = .error
                return (nil, false)
            }
        }

        return (requested, true)
    }

    private func payloadExceedsRecommendedUDPSize(_ payload: String) -> Bool {
        payload.utf8.count > UDPPayloadValidation.warningByteLimit
    }

    func runSingleCommand(_ command: UDPCommand) {
        guard sendMessageCommand(command) else {
            controlStatus = .error
            return
        }

        lastMessage = "Sent \(command.messageType.rawValue) Step: \(command.name)"
    }

    @MainActor
    private func sendMessageCommand(_ command: UDPCommand) -> Bool {
        guard command.port >= 1,
              command.port <= Int(UInt16.max) else {
            lastMessage = "Invalid UDP destination port for Step: \(command.name). Use 1–65535."
            logger.error(lastMessage)
            return false
        }

        let payload: String

        switch command.messageType {
        case .standardUDP:
            payload = command.message

        case .syslog:
            payload = SyslogMessageFormatter.formattedMessage(
                severity: command.syslogSeverity,
                deviceName: syslogDeviceName,
                message: command.message
            )
        }

        if payloadExceedsRecommendedUDPSize(payload) {
            logger.warning("UDP payload for Step \"\(command.name)\" is \(payload.utf8.count) bytes. Payloads over \(UDPPayloadValidation.warningByteLimit) bytes may fragment or drop.")
        }

        let resolvedSource = resolvedUDPSource(
            requestedSourceIPAddress: command.sourceIPAddress,
            unavailablePolicy: command.sourceUnavailablePolicy,
            stepName: command.name
        )

        guard resolvedSource.shouldSend else {
            return false
        }

        udpService.send(
            message: payload,
            host: command.host,
            port: UInt16(command.port),
            sourceIPAddress: resolvedSource.sourceIPAddress,
            allowsBroadcast: command.allowsBroadcast
        )

        let sourceDescription = resolvedSource.sourceIPAddress == nil ? "automatic source" : "source \(resolvedSource.sourceIPAddress ?? "")"
        let broadcastDescription = command.allowsBroadcast ? " broadcast" : ""
        logger.info("Sent \(command.messageType.rawValue) Step: \(command.name) to \(command.host):\(command.port) using \(sourceDescription)\(broadcastDescription)")

        return true
    }

    @MainActor
    private func sendUtilityUDPCommand(_ command: UtilityCommand) {
        guard command.udpPort >= 1,
              command.udpPort <= Int(UInt16.max) else {
            lastMessage = "Invalid UDP destination port for Utility Step: \(command.name). Use 1–65535."
            controlStatus = .error
            logger.error(lastMessage)
            return
        }

        if payloadExceedsRecommendedUDPSize(command.udpMessage) {
            logger.warning("UDP payload for Utility Step \"\(command.name)\" is \(command.udpMessage.utf8.count) bytes. Payloads over \(UDPPayloadValidation.warningByteLimit) bytes may fragment or drop.")
        }

        let resolvedSource = resolvedUDPSource(
            requestedSourceIPAddress: command.udpSourceIPAddress,
            unavailablePolicy: command.udpSourceUnavailablePolicy,
            stepName: command.name
        )

        guard resolvedSource.shouldSend else {
            return
        }

        udpService.send(
            message: command.udpMessage,
            host: command.udpHost,
            port: UInt16(command.udpPort),
            sourceIPAddress: resolvedSource.sourceIPAddress,
            allowsBroadcast: command.udpAllowsBroadcast
        )

        lastMessage = "Utility UDP Step sent: \(command.name)"
    }

    // MARK: - Volume

    var volumeSliderLowerBound: Double {
        min(volumeOutputMinimum, volumeOutputMaximum)
    }

    var volumeSliderUpperBound: Double {
        let lower = volumeSliderLowerBound
        let upper = max(volumeOutputMinimum, volumeOutputMaximum)

        if upper == lower {
            return lower + 1
        }

        return upper
    }

    var currentVolumeOutputValue: Double {
        isMuted ? volumeMuteLevel : scaledVolumeOutputValue(for: volumeLevel)
    }

    func setVolume(_ level: Double) {
        let clampedLevel = min(max(level, 0), 1)

        volumeLevel = clampedLevel
        lastUnmutedVolumeLevel = clampedLevel
        isMuted = false

        sendVolumeLevel()
    }

    func setVolumeOutputLevel(_ outputLevel: Double) {
        setVolume(normalizedVolumeLevel(forOutputValue: outputLevel))
    }

    func toggleMute() {
        if isMuted {
            isMuted = false
            volumeLevel = min(max(lastUnmutedVolumeLevel, 0), 1)
        } else {
            lastUnmutedVolumeLevel = min(max(volumeLevel, 0), 1)
            isMuted = true
        }

        sendVolumeLevel()
    }

    func applyVolumePreset(_ level: Double) {
        setVolume(level)
    }

    func sendVolumeLevel() {
        guard volumeDestinationPort >= 1,
              volumeDestinationPort <= Int(UInt16.max) else {
            lastMessage = "Invalid volume UDP destination port. Use 1–65535."
            controlStatus = .error
            logger.error(lastMessage)
            return
        }

        let outputValue = currentVolumeOutputValue
        let formattedValue = formattedVolumeOutputValue(outputValue)
        let message = "\(volumeMessagePrefix)\(formattedValue)"

        udpService.send(
            message: message,
            host: volumeDestinationHost,
            port: UInt16(volumeDestinationPort)
        )

        if isMuted {
            lastMessage = "Volume muted → \(formattedValue)"
        } else {
            let percent = Int(volumeLevel * 100)
            lastMessage = "Volume set to \(formattedValue) (slider \(percent)%)"
        }
    }

    func scaledVolumeOutputValue(for level: Double) -> Double {
        let clampedLevel = min(max(level, 0), 1)
        let outputRange = volumeSliderUpperBound - volumeSliderLowerBound

        return volumeSliderLowerBound + (clampedLevel * outputRange)
    }

    func normalizedVolumeLevel(forOutputValue outputValue: Double) -> Double {
        let lower = volumeSliderLowerBound
        let upper = volumeSliderUpperBound
        let clampedOutputValue = min(max(outputValue, lower), upper)
        let outputRange = upper - lower

        guard outputRange > 0 else {
            return 0
        }

        return (clampedOutputValue - lower) / outputRange
    }

    func formattedVolumeOutputValue(_ value: Double) -> String {
        let roundedValue = (value * 1000).rounded() / 1000

        if roundedValue.rounded() == roundedValue {
            return String(Int(roundedValue))
        }

        return String(roundedValue)
    }

    private func handleVolumePreferenceChange() {
        guard volumePreferenceOutputIsSuspended == false else {
            return
        }

        sendVolumeLevel()
    }

    // MARK: - Schedule Engine

    private func startScheduleEngine() {
        scheduleEngine.start { [weak self] in
            self?.processScheduledEvents()
        }
    }

    private func processScheduledEvents() {
        guard scheduleProcessingIsActive == false else {
            return
        }

        scheduleProcessingIsActive = true
        defer {
            scheduleProcessingIsActive = false
        }

        let now = Date()

        resetProcessedOccurrencesIfNeeded(now: now)

        let entriesToProcess = scheduleEntries

        for event in entriesToProcess {
            processScheduledEvent(event, now: now)
        }
    }

    private func processScheduledEvent(
        _ event: ScheduleEntry,
        now: Date
    ) {
        guard event.enabled else {
            return
        }

        guard let occurrenceDate = occurrenceDateForScheduleProcessing(
            event,
            now: now
        ) else {
            return
        }

        let secondsSinceOccurrence = now.timeIntervalSince(occurrenceDate)

        guard secondsSinceOccurrence >= 0,
              secondsSinceOccurrence <= scheduleFireToleranceSeconds else {
            return
        }

        guard processedOccurrenceLimitsAllowProcessing(now: now) else {
            return
        }

        let occurrenceKey = processedOccurrenceKey(
            event: event,
            occurrenceDate: occurrenceDate
        )

        guard processedScheduleOccurrences.contains(occurrenceKey) == false else {
            return
        }

        processedScheduleOccurrences.insert(occurrenceKey)
        processedScheduleOccurrenceTotalCount += 1

        guard let action = actionDefinitions.first(where: {
            $0.id == event.actionDefinitionID
        }) else {
            lastMessage = "Skipped scheduled Event: missing Action"
            logger.warning(lastMessage)
            recordScheduleExecution(
                event: event,
                occurrenceDate: occurrenceDate,
                result: .skipped,
                message: "Missing Action"
            )
            return
        }

        guard scheduledActionIsAllowed(action) else {
            lastMessage = "Skipped scheduled Event: \(action.name)"
            logger.warning(lastMessage)
            recordScheduleExecution(
                event: event,
                occurrenceDate: occurrenceDate,
                result: .skipped,
                message: scheduleDisabledMessage(for: action)
            )
            return
        }

        logger.info("Running scheduled Action: \(action.name)")
        runScheduledEvent(
            event,
            action: action,
            occurrenceDate: occurrenceDate
        )
    }

    private func runScheduledEvent(
        _ event: ScheduleEntry,
        action: ActionDefinition,
        occurrenceDate: Date
    ) {
        Task { @MainActor [weak self] in
            self?.startTrackedActionTask(
                action,
                source: .scheduled,
                visitedActionIDs: Set([action.id])
            ) { [weak self] completed in
                self?.recordScheduleExecution(
                    event: event,
                    occurrenceDate: occurrenceDate,
                    result: completed ? .ran : .failed,
                    message: completed ? "Ran" : "Failed"
                )
            }
        }
    }

    private func recordScheduleExecution(
        event: ScheduleEntry,
        occurrenceDate: Date,
        result: ScheduleExecutionResult,
        message: String
    ) {
        let occurrenceKey = scheduleExecutionOccurrenceKey(
            eventID: event.id,
            occurrenceDate: occurrenceDate
        )

        let record = ScheduleExecutionRecord(
            eventID: event.id,
            occurrenceKey: occurrenceKey,
            scheduledDate: occurrenceDate,
            actualDate: result == .ran ? Date() : nil,
            result: result,
            message: message
        )

        scheduleExecutionHistory.removeAll { existingRecord in
            existingRecord.occurrenceKey == occurrenceKey
        }

        scheduleExecutionHistory.append(record)
        pruneScheduleExecutionHistory(now: Date())
    }

    func scheduleExecutionRecord(
        for eventID: UUID,
        occurrenceDate: Date
    ) -> ScheduleExecutionRecord? {
        let occurrenceKey = scheduleExecutionOccurrenceKey(
            eventID: eventID,
            occurrenceDate: occurrenceDate
        )

        return scheduleExecutionHistory.first { record in
            record.occurrenceKey == occurrenceKey
        }
    }

    private func scheduleExecutionOccurrenceKey(
        eventID: UUID,
        occurrenceDate: Date
    ) -> String {
        ScheduleEntryFormatter.occurrenceKey(
            eventID: eventID,
            occurrenceDate: occurrenceDate
        )
    }

    private func scheduleDisabledMessage(for action: ActionDefinition) -> String {
        switch action.type {
        case .show:
            return "Show Actions Off"

        case .utility:
            return "Utility Actions Off"
        }
    }

    private func pruneScheduleExecutionHistory(now: Date) {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -scheduleExecutionHistoryRetentionDays,
            to: now
        ) ?? now.addingTimeInterval(-TimeInterval(scheduleExecutionHistoryRetentionDays) * 86_400)

        scheduleExecutionHistory.removeAll { record in
            record.scheduledDate < cutoffDate
        }
    }

    private func processedOccurrenceLimitsAllowProcessing(now: Date) -> Bool {
        if processedScheduleOccurrences.count >= processedScheduleOccurrenceDailyLimit {
            lastMessage = "Processed schedule occurrence daily limit reached. Clearing occurrence guard and skipping this tick."
            logger.warning(lastMessage)

            processedScheduleOccurrenceDay = Calendar.current.startOfDay(for: now)
            processedScheduleOccurrences.removeAll()
            return false
        }

        if processedScheduleOccurrenceTotalCount >= processedScheduleOccurrenceTotalLimit {
            lastMessage = "Processed schedule occurrence total limit reached. Clearing occurrence guard and skipping this tick."
            logger.warning(lastMessage)

            processedScheduleOccurrenceDay = Calendar.current.startOfDay(for: now)
            processedScheduleOccurrences.removeAll()
            processedScheduleOccurrenceTotalCount = 0
            return false
        }

        return true
    }

    private func scheduledActionIsAllowed(_ action: ActionDefinition) -> Bool {
        switch action.type {
        case .show:
            return showActionsEnabled

        case .utility:
            return utilityActionsEnabled
        }
    }

    private func occurrenceDateForScheduleProcessing(
        _ event: ScheduleEntry,
        now: Date
    ) -> Date? {
        ScheduleEntryFormatter.occurrenceDateForScheduleProcessing(
            for: event,
            now: now
        )
    }

    private static let eventTimestamp24HourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let eventTimestamp12HourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd h:mm:ss a"
        return formatter
    }()

    private func processedOccurrenceKey(
        event: ScheduleEntry,
        occurrenceDate: Date
    ) -> String {
        ScheduleEntryFormatter.occurrenceKey(
            eventID: event.id,
            occurrenceDate: occurrenceDate
        )
    }

    private func resetProcessedOccurrencesIfNeeded(now: Date) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        guard todayStart != processedScheduleOccurrenceDay else {
            return
        }

        processedScheduleOccurrenceDay = todayStart
        processedScheduleOccurrences.removeAll()
    }

    // MARK: - Formatting

    private func formattedEventTimestamp(_ date: Date) -> String {
        if use24HourTime {
            return AppState.eventTimestamp24HourFormatter.string(from: date)
        }

        return AppState.eventTimestamp12HourFormatter.string(from: date)
    }
}

// MARK: - Configuration Export Model

private struct LaunchControlConfiguration: Codable {
    let version: Int
    let exportedAt: Date

    let projectName: String
    let projectNotes: String
    let use24HourTime: Bool
    let weekStartDay: Int

    let syslogDeviceName: String
    let operationalLogRetentionDays: Int
    let dockIconVisibilityPreference: DockIconVisibilityPreference
    let launchAtStartupEnabled: Bool
    let preventComputerSleepEnabled: Bool

    let incomingUDPPort: Int
    let defaultDestinationHost: String
    let defaultDestinationPort: Int

    let volumeDestinationHost: String
    let volumeDestinationPort: Int
    let volumeMessagePrefix: String
    let volumeOutputMinimum: Double
    let volumeOutputMaximum: Double
    let volumeMuteLevel: Double

    let showActionsEnabled: Bool
    let utilityActionsEnabled: Bool
    let scheduleEnabledOnMessage: String
    let scheduleEnabledOffMessage: String

    let volumeLevel: Double
    let lastUnmutedVolumeLevel: Double
    let isMuted: Bool

    let lowVolumeLevel: Double
    let normalVolumeLevel: Double
    let highVolumeLevel: Double

    let actionDefinitions: [ActionDefinition]
    let scheduledEvents: [ScheduledEvent]
    let scheduleEntries: [ScheduleEntry]

    enum CodingKeys: String, CodingKey {
        case version
        case exportedAt

        case projectName
        case projectNotes
        case use24HourTime
        case weekStartDay

        case syslogDeviceName
        case operationalLogRetentionDays
        case dockIconVisibilityPreference
        case launchAtStartupEnabled
        case preventComputerSleepEnabled

        case incomingUDPPort
        case defaultDestinationHost
        case defaultDestinationPort

        case volumeDestinationHost
        case volumeDestinationPort
        case volumeMessagePrefix
        case volumeOutputMinimum
        case volumeOutputMaximum
        case volumeMuteLevel

        case showActionsEnabled
        case utilityActionsEnabled
        case scheduleEnabledOnMessage
        case scheduleEnabledOffMessage

        case volumeLevel
        case lastUnmutedVolumeLevel
        case isMuted

        case lowVolumeLevel
        case normalVolumeLevel
        case highVolumeLevel
        case openingVolumeLevel

        case actionDefinitions
        case scheduledEvents
        case scheduleEntries
    }

    init(
        version: Int,
        exportedAt: Date,
        projectName: String,
        projectNotes: String,
        use24HourTime: Bool,
        weekStartDay: Int,
        syslogDeviceName: String,
        operationalLogRetentionDays: Int,
        dockIconVisibilityPreference: DockIconVisibilityPreference,
        launchAtStartupEnabled: Bool,
        preventComputerSleepEnabled: Bool,
        incomingUDPPort: Int,
        defaultDestinationHost: String,
        defaultDestinationPort: Int,
        volumeDestinationHost: String,
        volumeDestinationPort: Int,
        volumeMessagePrefix: String,
        volumeOutputMinimum: Double,
        volumeOutputMaximum: Double,
        volumeMuteLevel: Double,
        showActionsEnabled: Bool,
        utilityActionsEnabled: Bool,
        scheduleEnabledOnMessage: String,
        scheduleEnabledOffMessage: String,
        volumeLevel: Double,
        lastUnmutedVolumeLevel: Double,
        isMuted: Bool,
        lowVolumeLevel: Double,
        normalVolumeLevel: Double,
        highVolumeLevel: Double,
        actionDefinitions: [ActionDefinition],
        scheduledEvents: [ScheduledEvent],
        scheduleEntries: [ScheduleEntry]
    ) {
        self.version = version
        self.exportedAt = exportedAt

        self.projectName = projectName
        self.projectNotes = projectNotes
        self.use24HourTime = use24HourTime
        self.weekStartDay = weekStartDay

        self.syslogDeviceName = syslogDeviceName
        self.operationalLogRetentionDays = operationalLogRetentionDays
        self.dockIconVisibilityPreference = dockIconVisibilityPreference
        self.launchAtStartupEnabled = launchAtStartupEnabled
        self.preventComputerSleepEnabled = preventComputerSleepEnabled

        self.incomingUDPPort = incomingUDPPort
        self.defaultDestinationHost = defaultDestinationHost
        self.defaultDestinationPort = defaultDestinationPort

        self.volumeDestinationHost = volumeDestinationHost
        self.volumeDestinationPort = volumeDestinationPort
        self.volumeMessagePrefix = volumeMessagePrefix
        self.volumeOutputMinimum = volumeOutputMinimum
        self.volumeOutputMaximum = volumeOutputMaximum
        self.volumeMuteLevel = volumeMuteLevel

        self.showActionsEnabled = showActionsEnabled
        self.utilityActionsEnabled = utilityActionsEnabled
        self.scheduleEnabledOnMessage = scheduleEnabledOnMessage
        self.scheduleEnabledOffMessage = scheduleEnabledOffMessage

        self.volumeLevel = volumeLevel
        self.lastUnmutedVolumeLevel = lastUnmutedVolumeLevel
        self.isMuted = isMuted

        self.lowVolumeLevel = lowVolumeLevel
        self.normalVolumeLevel = normalVolumeLevel
        self.highVolumeLevel = highVolumeLevel

        self.actionDefinitions = actionDefinitions
        self.scheduledEvents = scheduledEvents
        self.scheduleEntries = scheduleEntries
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date()

        projectName = try container.decodeIfPresent(String.self, forKey: .projectName) ?? "Untitled Project"
        projectNotes = try container.decodeIfPresent(String.self, forKey: .projectNotes) ?? ""
        use24HourTime = try container.decodeIfPresent(Bool.self, forKey: .use24HourTime) ?? true
        weekStartDay = try container.decodeIfPresent(Int.self, forKey: .weekStartDay) ?? 1

        syslogDeviceName = try container.decodeIfPresent(String.self, forKey: .syslogDeviceName) ?? AppState.defaultSyslogDeviceName()
        operationalLogRetentionDays = try container.decodeIfPresent(Int.self, forKey: .operationalLogRetentionDays) ?? 90
        dockIconVisibilityPreference = try container.decodeIfPresent(DockIconVisibilityPreference.self, forKey: .dockIconVisibilityPreference) ?? .showWhenDashboardWindowIsOpen
        launchAtStartupEnabled = try container.decodeIfPresent(Bool.self, forKey: .launchAtStartupEnabled) ?? false
        preventComputerSleepEnabled = try container.decodeIfPresent(Bool.self, forKey: .preventComputerSleepEnabled) ?? false

        incomingUDPPort = try container.decodeIfPresent(Int.self, forKey: .incomingUDPPort) ?? 8000
        defaultDestinationHost = try container.decodeIfPresent(String.self, forKey: .defaultDestinationHost) ?? "127.0.0.1"
        defaultDestinationPort = try container.decodeIfPresent(Int.self, forKey: .defaultDestinationPort) ?? 8001

        volumeDestinationHost = try container.decodeIfPresent(String.self, forKey: .volumeDestinationHost) ?? "127.0.0.1"
        volumeDestinationPort = try container.decodeIfPresent(Int.self, forKey: .volumeDestinationPort) ?? 8001
        volumeMessagePrefix = try container.decodeIfPresent(String.self, forKey: .volumeMessagePrefix) ?? "/cue/selected/level/0/"
        volumeOutputMinimum = try container.decodeIfPresent(Double.self, forKey: .volumeOutputMinimum) ?? -60
        volumeOutputMaximum = try container.decodeIfPresent(Double.self, forKey: .volumeOutputMaximum) ?? 12
        volumeMuteLevel = try container.decodeIfPresent(Double.self, forKey: .volumeMuteLevel) ?? -60

        showActionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .showActionsEnabled) ?? true
        utilityActionsEnabled = try container.decodeIfPresent(Bool.self, forKey: .utilityActionsEnabled) ?? true
        scheduleEnabledOnMessage = try container.decodeIfPresent(String.self, forKey: .scheduleEnabledOnMessage) ?? "SCHEDULE_ENABLED"
        scheduleEnabledOffMessage = try container.decodeIfPresent(String.self, forKey: .scheduleEnabledOffMessage) ?? "SCHEDULE_DISABLED"

        volumeLevel = try container.decodeIfPresent(Double.self, forKey: .volumeLevel) ?? 0.75
        lastUnmutedVolumeLevel = try container.decodeIfPresent(Double.self, forKey: .lastUnmutedVolumeLevel) ?? 0.75
        isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false

        lowVolumeLevel = try container.decodeIfPresent(Double.self, forKey: .lowVolumeLevel) ?? 0.35
        normalVolumeLevel = try container.decodeIfPresent(Double.self, forKey: .normalVolumeLevel) ?? 0.75

        highVolumeLevel =
            try container.decodeIfPresent(Double.self, forKey: .highVolumeLevel)
            ?? container.decodeIfPresent(Double.self, forKey: .openingVolumeLevel)
            ?? 0.90

        actionDefinitions = try container.decodeIfPresent([ActionDefinition].self, forKey: .actionDefinitions) ?? []
        scheduledEvents = try container.decodeIfPresent([ScheduledEvent].self, forKey: .scheduledEvents) ?? []
        scheduleEntries = try container.decodeIfPresent([ScheduleEntry].self, forKey: .scheduleEntries) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(version, forKey: .version)
        try container.encode(exportedAt, forKey: .exportedAt)

        try container.encode(projectName, forKey: .projectName)
        try container.encode(projectNotes, forKey: .projectNotes)
        try container.encode(use24HourTime, forKey: .use24HourTime)
        try container.encode(weekStartDay, forKey: .weekStartDay)

        try container.encode(syslogDeviceName, forKey: .syslogDeviceName)
        try container.encode(operationalLogRetentionDays, forKey: .operationalLogRetentionDays)
        try container.encode(dockIconVisibilityPreference, forKey: .dockIconVisibilityPreference)
        try container.encode(launchAtStartupEnabled, forKey: .launchAtStartupEnabled)
        try container.encode(preventComputerSleepEnabled, forKey: .preventComputerSleepEnabled)

        try container.encode(incomingUDPPort, forKey: .incomingUDPPort)
        try container.encode(defaultDestinationHost, forKey: .defaultDestinationHost)
        try container.encode(defaultDestinationPort, forKey: .defaultDestinationPort)

        try container.encode(volumeDestinationHost, forKey: .volumeDestinationHost)
        try container.encode(volumeDestinationPort, forKey: .volumeDestinationPort)
        try container.encode(volumeMessagePrefix, forKey: .volumeMessagePrefix)
        try container.encode(volumeOutputMinimum, forKey: .volumeOutputMinimum)
        try container.encode(volumeOutputMaximum, forKey: .volumeOutputMaximum)
        try container.encode(volumeMuteLevel, forKey: .volumeMuteLevel)

        try container.encode(showActionsEnabled, forKey: .showActionsEnabled)
        try container.encode(utilityActionsEnabled, forKey: .utilityActionsEnabled)
        try container.encode(scheduleEnabledOnMessage, forKey: .scheduleEnabledOnMessage)
        try container.encode(scheduleEnabledOffMessage, forKey: .scheduleEnabledOffMessage)

        try container.encode(volumeLevel, forKey: .volumeLevel)
        try container.encode(lastUnmutedVolumeLevel, forKey: .lastUnmutedVolumeLevel)
        try container.encode(isMuted, forKey: .isMuted)

        try container.encode(lowVolumeLevel, forKey: .lowVolumeLevel)
        try container.encode(normalVolumeLevel, forKey: .normalVolumeLevel)
        try container.encode(highVolumeLevel, forKey: .highVolumeLevel)

        try container.encode(actionDefinitions, forKey: .actionDefinitions)
        try container.encode(scheduledEvents, forKey: .scheduledEvents)
        try container.encode(scheduleEntries, forKey: .scheduleEntries)
    }
}

// MARK: - Action Run Source

private enum ActionRunSource {
    case manual
    case scheduled
    case automated
}



