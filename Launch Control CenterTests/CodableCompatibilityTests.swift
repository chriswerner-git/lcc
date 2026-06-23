//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: CodableCompatibilityTests.swift
//  Purpose: Verifies legacy Codable payloads receive safe defaults.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import XCTest
@testable import Launch_Control_Center

final class CodableCompatibilityTests: XCTestCase {
    func testLegacyUDPCommandDecodesWithNetworkDefaults() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "messageType": "standardUDP",
          "name": "Legacy Step",
          "host": "127.0.0.1",
          "port": 8001,
          "message": "RUN_SHOW",
          "syslogSeverity": "Info",
          "delaySeconds": 0
        }
        """

        let command = try JSONDecoder().decode(UDPCommand.self, from: Data(json.utf8))

        XCTAssertEqual(command.sourceIPAddress, "")
        XCTAssertEqual(command.sourceUnavailablePolicy, .useAutomaticRouting)
        XCTAssertFalse(command.allowsBroadcast)
    }

    func testLegacyUtilityCommandDecodesWithNetworkDefaults() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "name": "Legacy Utility UDP",
          "kind": "Send UDP",
          "delaySeconds": 0,
          "volumeLevel": 0.75,
          "showScheduleEnabled": true,
          "utilityScheduleEnabled": true,
          "udpHost": "127.0.0.1",
          "udpPort": 8001,
          "udpMessage": "PING"
        }
        """

        let command = try JSONDecoder().decode(UtilityCommand.self, from: Data(json.utf8))

        XCTAssertEqual(command.udpSourceIPAddress, "")
        XCTAssertEqual(command.udpSourceUnavailablePolicy, .useAutomaticRouting)
        XCTAssertFalse(command.udpAllowsBroadcast)
    }
}
