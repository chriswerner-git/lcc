//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: LoginStartupService.swift
//  Purpose: Wraps macOS login item registration for Launch at Startup.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation
import ServiceManagement

struct LoginStartupService {
    enum StartupStatus {
        case enabled
        case disabled
        case requiresApproval
        case unavailable
        case unknown
    }

    var status: StartupStatus {
        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled

        case .notRegistered:
            return .disabled

        case .requiresApproval:
            return .requiresApproval

        case .notFound:
            return .unavailable

        @unknown default:
            return .unknown
        }
    }

    var isEnabled: Bool {
        status == .enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
