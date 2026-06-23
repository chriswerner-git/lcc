//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Launch Control Center                                      │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: UDPPayloadValidationTests.swift
//  Purpose: Verifies UDP payload safety threshold behavior.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import XCTest
@testable import Launch_Control_Center

@MainActor
final class UDPPayloadValidationTests: XCTestCase {
    func testPayloadWarningLimitRemainsAtShowNetworkSafeThreshold() {
        XCTAssertEqual(UDPPayloadValidation.warningByteLimit, 1_400)
    }

    func testPayloadAtLimitDoesNotRequireWarning() {
        let message = String(repeating: "A", count: UDPPayloadValidation.warningByteLimit)

        XCTAssertLessThanOrEqual(message.utf8.count, UDPPayloadValidation.warningByteLimit)
    }

    func testPayloadOverLimitRequiresWarning() {
        let message = String(repeating: "A", count: UDPPayloadValidation.warningByteLimit + 1)

        XCTAssertGreaterThan(message.utf8.count, UDPPayloadValidation.warningByteLimit)
    }
}
