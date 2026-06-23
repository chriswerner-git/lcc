//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: SleepPreventionService.swift
//  Purpose: Manages macOS idle-system-sleep prevention while the app is running.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation
import IOKit.pwr_mgt

final class SleepPreventionService {
    // MARK: - Properties

    private var assertionID = IOPMAssertionID(0)

    // MARK: - State

    var isActive: Bool {
        assertionID != 0
    }

    // MARK: - Control

    func enable(reason: String) throws {
        guard isActive == false else {
            return
        }

        var newAssertionID = IOPMAssertionID(0)

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &newAssertionID
        )

        guard result == kIOReturnSuccess else {
            assertionID = 0
            throw SleepPreventionError.assertionCreationFailed(result)
        }

        assertionID = newAssertionID
    }

    func disable() {
        guard isActive else {
            return
        }

        IOPMAssertionRelease(assertionID)
        assertionID = 0
    }

    deinit {
        disable()
    }
}

// MARK: - Sleep Prevention Error

enum SleepPreventionError: LocalizedError {
    case assertionCreationFailed(IOReturn)

    var errorDescription: String? {
        switch self {
        case .assertionCreationFailed(let code):
            return "macOS sleep-prevention assertion failed with code \(code)."
        }
    }
}
