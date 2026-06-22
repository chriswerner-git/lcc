//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AppState.swift
//  Purpose: Central app state, persistence coordination, scheduling, and Action execution.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  Notes:
//  - Launch at Startup is an app/user preference and is not exported with project configurations.
//  - Prevent Computer Sleep is an app/user preference and is not exported with project configurations.
//  - Operational Log Retention is an app/user preference and is not exported with project configurations.
//  - Syslog Device Name is an app/user preference and is not exported with project configurations.
//  - Schedule enable toggles affect scheduled Events only.
//  - Manual Action buttons still run regardless of schedule toggle state.
//  - Show Actions execute message steps.
//  - Utility Actions execute dashboard-level Utility steps.
//

import AppKit
import Combine
import Foundation

// MARK: - Dock Icon Visibility Preference

enum DockIconVisibilityPreference: String, CaseIterable, Identifiable {
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

    private let maximumActionRuntimeSeconds: TimeInterval = 120
    private let appLaunchDate = Date()

    private var dailyHealthLogTimer: Timer?

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
        didSet { UserDefaults.standard.set(volumeOutputMinimum, forKey: "volumeOutputMinimum") }
    }

    @Published var volumeOutputMaximum: Double {
        didSet { UserDefaults.standard.set(volumeOutputMaximum, forKey: "volumeOutputMaximum") }
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

        self.actionDefinitions = PersistenceService.shared.loadActionDefinitions()
        self.scheduledEvents = PersistenceService.shared.loadScheduledEvents()
        self.scheduleEntries = PersistenceService.shared.loadScheduleEntries()
        self.scheduleExecutionHistory = PersistenceService.shared.loadScheduleExecutionHistory()
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

        scheduleEngine.stop()
        systemLifecycleService.stop()
        sleepPreventionService.disable()
    }

    // MARK: - App Defaults

    private static func defaultSyslogDeviceName() -> String {
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
            incomingUDPPort: incomingUDPPort,
            defaultDestinationHost: defaultDestinationHost,
            defaultDestinationPort: defaultDestinationPort,
            volumeDestinationHost: volumeDestinationHost,
            volumeDestinationPort: volumeDestinationPort,
            volumeMessagePrefix: volumeMessagePrefix,
            volumeOutputMinimum: volumeOutputMinimum,
            volumeOutputMaximum: volumeOutputMaximum,
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
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let configuration = try decoder.decode(
            LaunchControlConfiguration.self,
            from: data
        )

        applyConfiguration(configuration)
    }

    private func applyConfiguration(_ configuration: LaunchControlConfiguration) {
        projectName = configuration.projectName
        projectNotes = configuration.projectNotes
        use24HourTime = configuration.use24HourTime
        weekStartDay = configuration.weekStartDay

        incomingUDPPort = configuration.incomingUDPPort
        defaultDestinationHost = configuration.defaultDestinationHost
        defaultDestinationPort = configuration.defaultDestinationPort

        volumeDestinationHost = configuration.volumeDestinationHost
        volumeDestinationPort = configuration.volumeDestinationPort
        volumeMessagePrefix = configuration.volumeMessagePrefix
        volumeOutputMinimum = configuration.volumeOutputMinimum
        volumeOutputMaximum = configuration.volumeOutputMaximum

        showActionsEnabled = configuration.showActionsEnabled
        utilityActionsEnabled = configuration.utilityActionsEnabled
        scheduleEnabledOnMessage = configuration.scheduleEnabledOnMessage
        scheduleEnabledOffMessage = configuration.scheduleEnabledOffMessage

        volumeLevel = configuration.volumeLevel
        lastUnmutedVolumeLevel = configuration.lastUnmutedVolumeLevel
        isMuted = configuration.isMuted

        lowVolumeLevel = configuration.lowVolumeLevel
        normalVolumeLevel = configuration.normalVolumeLevel
        highVolumeLevel = configuration.highVolumeLevel

        actionDefinitions = configuration.actionDefinitions
        scheduledEvents = configuration.scheduledEvents
        scheduleEntries = configuration.scheduleEntries

        processedScheduleOccurrences.removeAll()
        processedScheduleOccurrenceDay = Calendar.current.startOfDay(for: Date())
        processedScheduleOccurrenceTotalCount = 0

        runningActionIDs.removeAll()

        refreshLaunchAtStartupStatus()
        refreshSleepPreventionStatus()

        lastMessage = "Imported configuration: \(configuration.projectName)"
        controlStatus = .idle
        logger.info(lastMessage)
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

    func runAction(_ action: ActionDefinition) {
        runAction(action, source: .manual)
    }

    private func runAction(
        _ action: ActionDefinition,
        source: ActionRunSource
    ) {
        Task { [weak self] in
            await self?.executeAction(
                action,
                source: source,
                visitedActionIDs: Set([action.id])
            )
        }
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
            switch source {
            case .manual:
                lastMessage = "Action already running: \(action.name)"

            case .scheduled:
                lastMessage = "Skipped scheduled Action already running: \(action.name)"

            case .automated:
                lastMessage = "Skipped Automated Action already running: \(action.name)"
            }

            logger.warning(lastMessage)
            return false
        }

        runningActionIDs.insert(action.id)
        return true
    }

    @MainActor
    private func finishActionRun(_ action: ActionDefinition) {
        runningActionIDs.remove(action.id)

        if runningActionIDs.isEmpty,
           controlStatus == .sending {
            controlStatus = .idle
        }
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
    private func executeShowAction(
        _ action: ActionDefinition,
        actionStartDate: Date
    ) async -> Bool {
        guard action.commands.isEmpty == false else {
            lastMessage = "Show Action has no Message Steps: \(action.name)"
            logger.warning(lastMessage)
            return false
        }

        for command in action.commands {
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

        for command in action.utilityCommands {
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

    func runSingleCommand(_ command: UDPCommand) {
        guard sendMessageCommand(command) else {
            controlStatus = .error
            return
        }

        lastMessage = "Sent \(command.messageType.rawValue) Step: \(command.name)"
    }

    @MainActor
    private func sendMessageCommand(_ command: UDPCommand) -> Bool {
        guard command.port >= 0,
              command.port <= Int(UInt16.max) else {
            lastMessage = "Invalid UDP port for Step: \(command.name)"
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

        udpService.send(
            message: payload,
            host: command.host,
            port: UInt16(command.port)
        )

        logger.info("Sent \(command.messageType.rawValue) Step: \(command.name) to \(command.host):\(command.port)")

        return true
    }

    @MainActor
    private func sendUtilityUDPCommand(_ command: UtilityCommand) {
        guard command.udpPort >= 0,
              command.udpPort <= Int(UInt16.max) else {
            lastMessage = "Invalid UDP port for Utility Step: \(command.name)"
            controlStatus = .error
            logger.error(lastMessage)
            return
        }

        udpService.send(
            message: command.udpMessage,
            host: command.udpHost,
            port: UInt16(command.udpPort)
        )

        lastMessage = "Utility UDP Step sent: \(command.name)"
    }

    // MARK: - Volume

    func setVolume(_ level: Double) {
        let clampedLevel = min(max(level, 0), 1)

        volumeLevel = clampedLevel

        if clampedLevel > 0 {
            lastUnmutedVolumeLevel = clampedLevel
            isMuted = false
        }

        sendVolumeLevel()
    }

    func toggleMute() {
        if isMuted {
            isMuted = false
            volumeLevel = lastUnmutedVolumeLevel
        } else {
            if volumeLevel > 0 {
                lastUnmutedVolumeLevel = volumeLevel
            }

            isMuted = true
            volumeLevel = 0
        }

        sendVolumeLevel()
    }

    func applyVolumePreset(_ level: Double) {
        isMuted = false
        setVolume(level)
    }

    func sendVolumeLevel() {
        guard volumeDestinationPort >= 0,
              volumeDestinationPort <= Int(UInt16.max) else {
            lastMessage = "Invalid volume UDP port"
            controlStatus = .error
            logger.error(lastMessage)
            return
        }

        let scaledValue = scaledVolumeOutputValue(for: volumeLevel)
        let formattedValue = formattedVolumeOutputValue(scaledValue)
        let message = "\(volumeMessagePrefix)\(formattedValue)"

        udpService.send(
            message: message,
            host: volumeDestinationHost,
            port: UInt16(volumeDestinationPort)
        )

        let percent = Int(volumeLevel * 100)
        lastMessage = "Volume set to \(percent)% → \(formattedValue)"
    }

    private func scaledVolumeOutputValue(for level: Double) -> Double {
        let clampedLevel = min(max(level, 0), 1)
        let outputRange = volumeOutputMaximum - volumeOutputMinimum

        return volumeOutputMinimum + (clampedLevel * outputRange)
    }

    private func formattedVolumeOutputValue(_ value: Double) -> String {
        let roundedValue = (value * 1000).rounded() / 1000

        if roundedValue.rounded() == roundedValue {
            return String(Int(roundedValue))
        }

        return String(roundedValue)
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
        Task { [weak self] in
            guard let self else {
                return
            }

            let completed = await self.executeAction(
                action,
                source: .scheduled,
                visitedActionIDs: Set([action.id])
            )

            await MainActor.run {
                self.recordScheduleExecution(
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
        "\(eventID.uuidString)-\(Int(occurrenceDate.timeIntervalSince1970))"
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
        if event.repeatsDaily {
            return dailyOccurrenceDate(for: event, now: now)
        }

        return event.startDate
    }

    private func dailyOccurrenceDate(
        for event: ScheduleEntry,
        now: Date
    ) -> Date? {
        let calendar = Calendar.current

        let todayStart = calendar.startOfDay(for: now)
        let eventStartDay = calendar.startOfDay(for: event.startDate)

        guard todayStart >= eventStartDay else {
            return nil
        }

        if let repeatUntil = event.repeatUntil {
            let repeatUntilDay = calendar.startOfDay(for: repeatUntil)

            guard todayStart <= repeatUntilDay else {
                return nil
            }
        }

        let todayWeekday = calendar.component(.weekday, from: now)
        let selectedWeekdays = selectedWeekdaysForScheduling(event)

        guard selectedWeekdays.contains(todayWeekday) else {
            return nil
        }

        guard eventIsNotExcluded(event, on: now) else {
            return nil
        }

        let todayComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: now
        )

        let timeComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: event.startDate
        )

        var occurrenceComponents = DateComponents()
        occurrenceComponents.year = todayComponents.year
        occurrenceComponents.month = todayComponents.month
        occurrenceComponents.day = todayComponents.day
        occurrenceComponents.hour = timeComponents.hour
        occurrenceComponents.minute = timeComponents.minute
        occurrenceComponents.second = timeComponents.second

        return calendar.date(from: occurrenceComponents)
    }

    private func selectedWeekdaysForScheduling(_ event: ScheduleEntry) -> Set<Int> {
        ScheduleEntryFormatter.selectedWeekdays(for: event)
    }

    private func eventIsNotExcluded(
        _ event: ScheduleEntry,
        on date: Date
    ) -> Bool {
        let calendar = Calendar.current

        return event.excludedOccurrenceDates.contains { excludedDate in
            calendar.isDate(excludedDate, inSameDayAs: date)
        } == false
    }

    private static let processedOccurrenceDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

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
        let dateKey: String

        if event.repeatsDaily {
            dateKey = AppState.processedOccurrenceDateFormatter.string(from: occurrenceDate)
        } else {
            dateKey = String(Int(event.startDate.timeIntervalSince1970))
        }

        return "\(event.id.uuidString)-\(dateKey)"
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

    let incomingUDPPort: Int
    let defaultDestinationHost: String
    let defaultDestinationPort: Int

    let volumeDestinationHost: String
    let volumeDestinationPort: Int
    let volumeMessagePrefix: String
    let volumeOutputMinimum: Double
    let volumeOutputMaximum: Double

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

        case incomingUDPPort
        case defaultDestinationHost
        case defaultDestinationPort

        case volumeDestinationHost
        case volumeDestinationPort
        case volumeMessagePrefix
        case volumeOutputMinimum
        case volumeOutputMaximum

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
        incomingUDPPort: Int,
        defaultDestinationHost: String,
        defaultDestinationPort: Int,
        volumeDestinationHost: String,
        volumeDestinationPort: Int,
        volumeMessagePrefix: String,
        volumeOutputMinimum: Double,
        volumeOutputMaximum: Double,
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

        self.incomingUDPPort = incomingUDPPort
        self.defaultDestinationHost = defaultDestinationHost
        self.defaultDestinationPort = defaultDestinationPort

        self.volumeDestinationHost = volumeDestinationHost
        self.volumeDestinationPort = volumeDestinationPort
        self.volumeMessagePrefix = volumeMessagePrefix
        self.volumeOutputMinimum = volumeOutputMinimum
        self.volumeOutputMaximum = volumeOutputMaximum

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

        incomingUDPPort = try container.decodeIfPresent(Int.self, forKey: .incomingUDPPort) ?? 8000
        defaultDestinationHost = try container.decodeIfPresent(String.self, forKey: .defaultDestinationHost) ?? "127.0.0.1"
        defaultDestinationPort = try container.decodeIfPresent(Int.self, forKey: .defaultDestinationPort) ?? 8001

        volumeDestinationHost = try container.decodeIfPresent(String.self, forKey: .volumeDestinationHost) ?? "127.0.0.1"
        volumeDestinationPort = try container.decodeIfPresent(Int.self, forKey: .volumeDestinationPort) ?? 8001
        volumeMessagePrefix = try container.decodeIfPresent(String.self, forKey: .volumeMessagePrefix) ?? "/cue/selected/level/0/"
        volumeOutputMinimum = try container.decodeIfPresent(Double.self, forKey: .volumeOutputMinimum) ?? -60
        volumeOutputMaximum = try container.decodeIfPresent(Double.self, forKey: .volumeOutputMaximum) ?? 12

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

        try container.encode(incomingUDPPort, forKey: .incomingUDPPort)
        try container.encode(defaultDestinationHost, forKey: .defaultDestinationHost)
        try container.encode(defaultDestinationPort, forKey: .defaultDestinationPort)

        try container.encode(volumeDestinationHost, forKey: .volumeDestinationHost)
        try container.encode(volumeDestinationPort, forKey: .volumeDestinationPort)
        try container.encode(volumeMessagePrefix, forKey: .volumeMessagePrefix)
        try container.encode(volumeOutputMinimum, forKey: .volumeOutputMinimum)
        try container.encode(volumeOutputMaximum, forKey: .volumeOutputMaximum)

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

