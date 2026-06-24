//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: ConfigurationHealthService.swift
//  Purpose: Evaluates Launch Control Center configuration health using pure,
//           testable rules shared by the Dashboard, startup panel, and tests.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

enum ConfigurationHealthService {
    // MARK: - Evaluation

    static func evaluate(
        actionDefinitions: [ActionDefinition],
        scheduleEntries: [ScheduleEntry],
        showActionsEnabled: Bool,
        utilityActionsEnabled: Bool,
        availableSourceIPs: Set<String>
    ) -> ConfigurationHealthReport {
        var issues: [ConfigurationHealthIssue] = []
        let actionIDs = Set(actionDefinitions.map(\.id))

        if actionDefinitions.isEmpty {
            issues.append(
                ConfigurationHealthIssue(
                    level: .warning,
                    title: "No Actions defined",
                    detail: "Define at least one Show or Utility Action before scheduling playback.",
                    kind: .noActionsDefined
                )
            )
        }

        if scheduleEntries.isEmpty {
            issues.append(
                ConfigurationHealthIssue(
                    level: .warning,
                    title: "No Events scheduled",
                    detail: "No scheduled Events are currently defined. Manual Actions can still run.",
                    kind: .noEventsScheduled
                )
            )
        }

        if !showActionsEnabled || !utilityActionsEnabled {
            issues.append(
                ConfigurationHealthIssue(
                    level: .warning,
                    title: "Schedule partially disabled",
                    detail: disabledScheduleDescription(
                        showActionsEnabled: showActionsEnabled,
                        utilityActionsEnabled: utilityActionsEnabled
                    ),
                    kind: .schedulePartiallyDisabled
                )
            )
        }

        let missingActionReferences = scheduleEntries.filter { !actionIDs.contains($0.actionDefinitionID) }
        if !missingActionReferences.isEmpty {
            issues.append(
                ConfigurationHealthIssue(
                    level: .error,
                    title: "Events reference missing Actions",
                    detail: missingActionReferenceDescription(for: missingActionReferences),
                    kind: .missingActionReferences,
                    affectedEvents: missingActionReferences.map(ConfigurationHealthAffectedEvent.init)
                )
            )
        }

        let unavailableSourceCount = unavailableSelectedSourceIPAddressCount(
            actionDefinitions: actionDefinitions,
            availableSourceIPs: availableSourceIPs
        )
        if unavailableSourceCount > 0 {
            issues.append(
                ConfigurationHealthIssue(
                    level: .warning,
                    title: "Unavailable UDP source IP",
                    detail: "\(unavailableSourceCount) UDP step\(unavailableSourceCount == 1 ? "" : "s") select a source IP that is not currently available.",
                    kind: .unavailableUDPSource
                )
            )
        }

        let oversizedMessageCount = oversizedUDPPayloadCount(actionDefinitions: actionDefinitions)
        if oversizedMessageCount > 0 {
            issues.append(
                ConfigurationHealthIssue(
                    level: .warning,
                    title: "Oversized UDP payload",
                    detail: "\(oversizedMessageCount) message\(oversizedMessageCount == 1 ? "" : "s") exceed the recommended \(UDPPayloadValidation.warningByteLimit)-byte UDP payload limit.",
                    kind: .oversizedUDPPayload
                )
            )
        }

        let level = issues.map(\.level).max() ?? .healthy
        return ConfigurationHealthReport(level: level, issues: issues)
    }

    // MARK: - Private Helpers

    private static func missingActionReferenceDescription(
        for events: [ScheduleEntry]
    ) -> String {
        let count = events.count
        let eventWord = count == 1 ? "Event" : "Events"
        let verb = count == 1 ? "references" : "reference"

        return "\(count) \(eventWord) \(verb) Actions that are no longer defined. Open Details to identify, reassign, disable, or delete the affected Event."
    }

    private static func disabledScheduleDescription(
        showActionsEnabled: Bool,
        utilityActionsEnabled: Bool
    ) -> String {
        switch (showActionsEnabled, utilityActionsEnabled) {
        case (false, false):
            return "Show and Utility scheduled Events are disabled."

        case (false, true):
            return "Show scheduled Events are disabled."

        case (true, false):
            return "Utility scheduled Events are disabled."

        case (true, true):
            return "Scheduled Events are enabled."
        }
    }

    private static func unavailableSelectedSourceIPAddressCount(
        actionDefinitions: [ActionDefinition],
        availableSourceIPs: Set<String>
    ) -> Int {
        var count = 0

        for action in actionDefinitions {
            for command in action.commands where !command.sourceIPAddress.isEmpty {
                if !availableSourceIPs.contains(command.sourceIPAddress) {
                    count += 1
                }
            }

            for command in action.utilityCommands where (command.kind == .sendUDP || command.kind == .sendUDPSyslog) && !command.udpSourceIPAddress.isEmpty {
                if !availableSourceIPs.contains(command.udpSourceIPAddress) {
                    count += 1
                }
            }
        }

        return count
    }

    private static func oversizedUDPPayloadCount(actionDefinitions: [ActionDefinition]) -> Int {
        var count = 0

        for action in actionDefinitions {
            count += action.commands.filter { command in
                command.message.utf8.count > UDPPayloadValidation.warningByteLimit
            }.count

            count += action.utilityCommands.filter { command in
                (command.kind == .sendUDP || command.kind == .sendUDPSyslog) && command.udpMessage.utf8.count > UDPPayloadValidation.warningByteLimit
            }.count
        }

        return count
    }
}
