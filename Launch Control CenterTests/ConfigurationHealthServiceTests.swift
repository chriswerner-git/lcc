//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: ConfigurationHealthServiceTests.swift
//  Purpose: Verifies pure configuration health evaluation rules.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import XCTest
@testable import Launch_Control_Center

final class ConfigurationHealthServiceTests: XCTestCase {
    func testHealthyConfigurationHasNoIssues() {
        let actionID = UUID()
        let action = ActionDefinition(
            id: actionID,
            name: "Show Action",
            type: .show,
            commands: [UDPCommand(message: "RUN_SHOW")]
        )
        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: Date()
        )

        let report = ConfigurationHealthService.evaluate(
            actionDefinitions: [action],
            scheduleEntries: [event],
            showActionsEnabled: true,
            utilityActionsEnabled: true,
            availableSourceIPs: []
        )

        XCTAssertEqual(report.level, .healthy)
        XCTAssertTrue(report.issues.isEmpty)
    }

    func testMissingActionReferenceProducesError() {
        let action = ActionDefinition(
            id: UUID(),
            name: "Show Action",
            type: .show,
            commands: [UDPCommand(message: "RUN_SHOW")]
        )
        let orphanedEvent = ScheduleEntry(
            actionDefinitionID: UUID(),
            startDate: Date()
        )

        let report = ConfigurationHealthService.evaluate(
            actionDefinitions: [action],
            scheduleEntries: [orphanedEvent],
            showActionsEnabled: true,
            utilityActionsEnabled: true,
            availableSourceIPs: []
        )

        XCTAssertEqual(report.level, .error)
        XCTAssertTrue(report.issues.contains { $0.title == "Events reference missing Actions" })
    }

    func testUnavailableSelectedSourceIPProducesWarning() {
        let actionID = UUID()
        let command = UDPCommand(
            host: "10.10.1.255",
            port: 8000,
            sourceIPAddress: "10.10.1.20",
            allowsBroadcast: true,
            message: "PING"
        )
        let action = ActionDefinition(
            id: actionID,
            name: "Broadcast Action",
            type: .show,
            commands: [command]
        )
        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: Date()
        )

        let report = ConfigurationHealthService.evaluate(
            actionDefinitions: [action],
            scheduleEntries: [event],
            showActionsEnabled: true,
            utilityActionsEnabled: true,
            availableSourceIPs: ["10.10.1.21"]
        )

        XCTAssertEqual(report.level, .warning)
        XCTAssertTrue(report.issues.contains { $0.title == "Unavailable UDP source IP" })
    }

    func testOversizedUDPPayloadProducesWarning() {
        let actionID = UUID()
        let largeMessage = String(repeating: "A", count: UDPPayloadValidation.warningByteLimit + 1)
        let action = ActionDefinition(
            id: actionID,
            name: "Large Message Action",
            type: .show,
            commands: [UDPCommand(message: largeMessage)]
        )
        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: Date()
        )

        let report = ConfigurationHealthService.evaluate(
            actionDefinitions: [action],
            scheduleEntries: [event],
            showActionsEnabled: true,
            utilityActionsEnabled: true,
            availableSourceIPs: []
        )

        XCTAssertEqual(report.level, .warning)
        XCTAssertTrue(report.issues.contains { $0.title == "Oversized UDP payload" })
    }

    func testDisabledScheduleProducesWarning() {
        let actionID = UUID()
        let action = ActionDefinition(
            id: actionID,
            name: "Show Action",
            type: .show,
            commands: [UDPCommand(message: "RUN_SHOW")]
        )
        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: Date()
        )

        let report = ConfigurationHealthService.evaluate(
            actionDefinitions: [action],
            scheduleEntries: [event],
            showActionsEnabled: false,
            utilityActionsEnabled: true,
            availableSourceIPs: []
        )

        XCTAssertEqual(report.level, .warning)
        XCTAssertTrue(report.issues.contains { $0.title == "Schedule partially disabled" })
    }
}
