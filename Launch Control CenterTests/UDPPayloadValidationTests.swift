//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: UDPPayloadValidationTests.swift
//  Purpose: Verifies UDP payload warning threshold behavior.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import XCTest
@testable import Launch_Control_Center

final class UDPPayloadValidationTests: XCTestCase {
    func testPayloadAtWarningLimitDoesNotExceedLimit() {
        let message = String(repeating: "A", count: UDPPayloadValidation.warningByteLimit)
        XCTAssertFalse(message.utf8.count > UDPPayloadValidation.warningByteLimit)
    }

    func testPayloadAboveWarningLimitExceedsLimit() {
        let message = String(repeating: "A", count: UDPPayloadValidation.warningByteLimit + 1)
        XCTAssertTrue(message.utf8.count > UDPPayloadValidation.warningByteLimit)
    }
}
