//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Launch Control Center                                      │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: CodableCompatibilityTests.swift
//  Purpose: Verifies older saved command payloads decode with safe defaults.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import XCTest
@testable import Launch_Control_Center

@MainActor
final class CodableCompatibilityTests: XCTestCase {
    func testUDPCommandDecodesMissingNetworkOptionsWithSafeDefaults() throws {
        let json = #"""
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "messageType": "Standard UDP",
            "name": "Legacy UDP Step",
            "host": "127.0.0.1",
            "port": 8001,
            "message": "RUN_SHOW",
            "delaySeconds": 0
        }
        """#.data(using: .utf8)!

        let command = try JSONDecoder().decode(UDPCommand.self, from: json)

        XCTAssertEqual(command.sourceIPAddress, "")
        XCTAssertEqual(command.sourceUnavailablePolicy, .useAutomaticRouting)
        XCTAssertFalse(command.allowsBroadcast)
    }

    func testUtilityCommandDecodesMissingUDPNetworkOptionsWithSafeDefaults() throws {
        let json = #"""
        {
            "id": "22222222-2222-2222-2222-222222222222",
            "name": "Legacy Utility UDP Step",
            "kind": "Send UDP",
            "delaySeconds": 0,
            "udpHost": "127.0.0.1",
            "udpPort": 8001,
            "udpMessage": "PING"
        }
        """#.data(using: .utf8)!

        let command = try JSONDecoder().decode(UtilityCommand.self, from: json)

        XCTAssertEqual(command.udpSourceIPAddress, "")
        XCTAssertEqual(command.udpSourceUnavailablePolicy, .useAutomaticRouting)
        XCTAssertFalse(command.udpAllowsBroadcast)
    }
}
