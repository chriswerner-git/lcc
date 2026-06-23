//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: ConfigurationBackupSnapshotTests.swift
//  Purpose: Verifies backup snapshot presentation and restore eligibility.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import XCTest
@testable import Launch_Control_Center

final class ConfigurationBackupSnapshotTests: XCTestCase {
    func testReadableBackupSnapshotIsRestorable() {
        let summary = ConfigurationAuditSummary(
            projectName: "Test Project",
            version: 1,
            exportedAt: Date(timeIntervalSince1970: 0),
            actionCount: 3,
            eventCount: 12,
            standaloneEventCount: 10,
            recurringSeriesCount: 2,
            intervalSeriesCount: 0,
            disabledEventCount: 0,
            removedOccurrenceCount: 0,
            finiteGeneratedEventCount: 12,
            openEndedSeriesCount: 0,
            issues: []
        )
        let snapshot = ConfigurationBackupSnapshot(
            id: "backup",
            url: URL(fileURLWithPath: "/tmp/backup.launchcontrol"),
            fileName: "backup.launchcontrol",
            createdAt: Date(timeIntervalSince1970: 0),
            summary: summary,
            errorMessage: nil
        )

        XCTAssertTrue(snapshot.isRestorable)
        XCTAssertEqual(snapshot.projectName, "Test Project")
        XCTAssertTrue(snapshot.detailLine.contains("Actions: 3"))
        XCTAssertTrue(snapshot.detailLine.contains("Events: 12"))
        XCTAssertTrue(snapshot.detailLine.contains("Schedule Check: OK"))
    }

    func testUnreadableBackupSnapshotIsNotRestorable() {
        let snapshot = ConfigurationBackupSnapshot(
            id: "broken",
            url: URL(fileURLWithPath: "/tmp/broken.launchcontrol"),
            fileName: "broken.launchcontrol",
            createdAt: Date(timeIntervalSince1970: 0),
            summary: nil,
            errorMessage: "Could not decode backup."
        )

        XCTAssertFalse(snapshot.isRestorable)
        XCTAssertEqual(snapshot.projectName, "Unreadable Backup")
        XCTAssertEqual(snapshot.detailLine, "Could not decode backup.")
    }
}
