//
//  LoginStartupService.swift
//  Launch Control Center
//
//  Handles Launch at Startup behavior using Apple's ServiceManagement API.
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
