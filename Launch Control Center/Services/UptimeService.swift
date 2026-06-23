//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: UptimeService.swift
//  Purpose: Provides app and computer uptime formatting for diagnostics.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

enum UptimeService {
    // MARK: - App Start

    private static let appStartDate = Date()

    // MARK: - Public Values

    static var appUptime: TimeInterval {
        Date().timeIntervalSince(appStartDate)
    }

    static var computerUptime: TimeInterval {
        ProcessInfo.processInfo.systemUptime
    }

    // MARK: - Formatting

    static func formattedAppUptime() -> String {
        formattedDuration(
            appUptime,
            includeSeconds: true
        )
    }

    static func formattedComputerUptime() -> String {
        formattedDuration(
            computerUptime,
            includeSeconds: false
        )
    }

    private static func formattedDuration(
        _ interval: TimeInterval,
        includeSeconds: Bool
    ) -> String {
        let totalSeconds = max(Int(interval), 0)

        let days = totalSeconds / 86_400
        let hours = (totalSeconds % 86_400) / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if days > 0 {
            if includeSeconds {
                return "\(days)d \(hours)h \(minutes)m \(seconds)s"
            }

            return "\(days)d \(hours)h \(minutes)m"
        }

        if includeSeconds {
            return String(
                format: "%02dh %02dm %02ds",
                hours,
                minutes,
                seconds
            )
        }

        return String(
            format: "%02dh %02dm",
            hours,
            minutes
        )
    }
}
