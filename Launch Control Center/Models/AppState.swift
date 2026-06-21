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
//  - Schedule enable toggles affect scheduled Events only.
//  - Manual Action buttons still run regardless of schedule toggle state.
//  - Show Actions execute UDP command steps.
//  - Utility Actions execute dashboard-level Utility steps.
//

import Foundation
import Combine

class AppState: ObservableObject {
    let udpService = UDPService()

    private let scheduleEngine = ScheduleEngine()
    private let scheduleFireToleranceSeconds: TimeInterval = 30

    private var processedScheduleOccurrences: Set<String> = []
    private var processedScheduleOccurrenceDay: Date = Calendar.current.startOfDay(for: Date())

    private let loginStartupService = LoginStartupService()

    // MARK: - App Preferences

    @Published var launchAtStartupEnabled: Bool = false
    @Published var launchAtStartupStatusMessage: String = "Launch at startup status unknown."

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

    // MARK: - Init

    init() {
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

        refreshLaunchAtStartupStatus()
        startScheduleEngine()
    }

    deinit {
        scheduleEngine.stop()
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
        } catch {
            refreshLaunchAtStartupStatus()
            controlStatus = .error
            lastMessage = "Launch at startup update failed: \(error.localizedDescription)"
        }
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

        refreshLaunchAtStartupStatus()

        lastMessage = "Imported configuration: \(configuration.projectName)"
        controlStatus = .idle
    }

    // MARK: - Schedule Toggles

    func setShowActionsEnabled(_ enabled: Bool) {
        showActionsEnabled = enabled
        lastMessage = enabled ? "Show Actions schedule enabled" : "Show Actions schedule disabled"
    }

    func setUtilityActionsEnabled(_ enabled: Bool) {
        utilityActionsEnabled = enabled
        lastMessage = enabled ? "Utility Actions schedule enabled" : "Utility Actions schedule disabled"
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
    private func executeAction(
        _ action: ActionDefinition,
        source: ActionRunSource,
        visitedActionIDs: Set<UUID>
    ) async {
        controlStatus = .sending

        switch source {
        case .manual:
            lastMessage = "Manual Action started: \(action.name)"

        case .scheduled:
            lastMessage = "Scheduled Action started: \(action.name)"
        }

        switch action.type {
        case .show:
            await executeShowAction(action)

        case .utility:
            await executeUtilityAction(
                action,
                visitedActionIDs: visitedActionIDs
            )
        }

        let timestamp = formattedEventTimestamp(Date())

        switch source {
        case .manual:
            lastMessage = "Ran Manual Action: \(action.name)"

        case .scheduled:
            lastMessage = "Ran Scheduled Action: \(action.name)"
        }

        lastEventMessage = "\(timestamp) — \(action.name)"
        controlStatus = .idle
    }

    @MainActor
    private func executeShowAction(_ action: ActionDefinition) async {
        guard action.commands.isEmpty == false else {
            lastMessage = "Show Action has no UDP Steps: \(action.name)"
            return
        }

        for command in action.commands {
            let delayCompleted = await waitForDelay(command.delaySeconds)

            guard delayCompleted else {
                controlStatus = .idle
                lastMessage = "Action cancelled: \(action.name)"
                return
            }

            guard sendUDPCommand(command) else {
                controlStatus = .error
                return
            }

            lastMessage = "Sent Step: \(command.name)"
        }
    }

    @MainActor
    private func executeUtilityAction(
        _ action: ActionDefinition,
        visitedActionIDs: Set<UUID>
    ) async {
        guard action.utilityCommands.isEmpty == false else {
            lastMessage = "Utility Action has no Steps: \(action.name)"
            return
        }

        for command in action.utilityCommands {
            let delayCompleted = await waitForDelay(command.delaySeconds)

            guard delayCompleted else {
                controlStatus = .idle
                lastMessage = "Utility Action cancelled: \(action.name)"
                return
            }

            await executeUtilityCommand(
                command,
                parentAction: action,
                visitedActionIDs: visitedActionIDs
            )
        }
    }

    @MainActor
    private func executeUtilityCommand(
        _ command: UtilityCommand,
        parentAction: ActionDefinition,
        visitedActionIDs: Set<UUID>
    ) async {
        switch command.kind {
        case .setVolume:
            setVolume(command.volumeLevel)
            lastMessage = "Utility Step: set volume to \(Int(command.volumeLevel * 100))%"

        case .setShowScheduleEnabled:
            setShowActionsEnabled(command.showScheduleEnabled)

        case .setUtilityScheduleEnabled:
            setUtilityActionsEnabled(command.utilityScheduleEnabled)

        case .runAction:
            await executeRunActionUtilityCommand(
                command,
                parentAction: parentAction,
                visitedActionIDs: visitedActionIDs
            )

        case .sendUDP:
            sendUtilityUDPCommand(command)
        }
    }

    @MainActor
    private func executeRunActionUtilityCommand(
        _ command: UtilityCommand,
        parentAction: ActionDefinition,
        visitedActionIDs: Set<UUID>
    ) async {
        guard let actionID = command.actionDefinitionID else {
            lastMessage = "Utility Step skipped: no Action selected"
            return
        }

        guard actionID != parentAction.id else {
            lastMessage = "Utility Step skipped: Action cannot run itself"
            return
        }

        guard visitedActionIDs.contains(actionID) == false else {
            lastMessage = "Utility Step skipped: recursive Action loop blocked"
            return
        }

        guard let targetAction = actionDefinitions.first(where: {
            $0.id == actionID
        }) else {
            lastMessage = "Utility Step skipped: selected Action not found"
            return
        }

        var updatedVisitedActionIDs = visitedActionIDs
        updatedVisitedActionIDs.insert(actionID)

        await executeAction(
            targetAction,
            source: .manual,
            visitedActionIDs: updatedVisitedActionIDs
        )
    }

    @MainActor
    private func waitForDelay(_ delaySeconds: Double) async -> Bool {
        let delay = max(delaySeconds, 0)

        guard delay > 0 else {
            return true
        }

        let nanoseconds = UInt64(delay * 1_000_000_000)

        do {
            try await Task.sleep(nanoseconds: nanoseconds)
            return true
        } catch {
            return false
        }
    }

    func runSingleCommand(_ command: UDPCommand) {
        guard sendUDPCommand(command) else {
            controlStatus = .error
            return
        }

        lastMessage = "Sent Step: \(command.name)"
    }

    @MainActor
    private func sendUDPCommand(_ command: UDPCommand) -> Bool {
        guard command.port >= 0,
              command.port <= Int(UInt16.max) else {
            lastMessage = "Invalid UDP port for Step: \(command.name)"
            return false
        }

        udpService.send(
            message: command.message,
            host: command.host,
            port: UInt16(command.port)
        )

        return true
    }

    @MainActor
    private func sendUtilityUDPCommand(_ command: UtilityCommand) {
        guard command.udpPort >= 0,
              command.udpPort <= Int(UInt16.max) else {
            lastMessage = "Invalid UDP port for Utility Step: \(command.name)"
            controlStatus = .error
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
        let now = Date()

        resetProcessedOccurrencesIfNeeded(now: now)

        for event in scheduleEntries {
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

        let occurrenceKey = processedOccurrenceKey(
            event: event,
            occurrenceDate: occurrenceDate
        )

        guard processedScheduleOccurrences.contains(occurrenceKey) == false else {
            return
        }

        processedScheduleOccurrences.insert(occurrenceKey)

        guard let action = actionDefinitions.first(where: {
            $0.id == event.actionDefinitionID
        }) else {
            lastMessage = "Skipped scheduled Event: missing Action"
            return
        }

        guard scheduledActionIsAllowed(action) else {
            lastMessage = "Skipped scheduled Action: \(action.name)"
            return
        }

        runAction(action, source: .scheduled)
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
        if event.repeatWeekdays.isEmpty {
            return Set(1...7)
        }

        return event.repeatWeekdays
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

    private func processedOccurrenceKey(
        event: ScheduleEntry,
        occurrenceDate: Date
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let dateKey: String

        if event.repeatsDaily {
            dateKey = dateFormatter.string(from: occurrenceDate)
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
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourTime ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd h:mm:ss a"
        return formatter.string(from: date)
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
}

