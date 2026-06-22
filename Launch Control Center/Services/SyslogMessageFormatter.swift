//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: SyslogMessageFormatter.swift
//  Purpose: Builds syslog-style UDP message payloads.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

enum SyslogMessageFormatter {
    // Facility local0 = 16.
    // PRI = facility * 8 + severity.
    private static let local0FacilityValue = 16
    private static let appName = "Launch-Control-Center"

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d HH:mm:ss"
        return formatter
    }()

    static func formattedMessage(
        severity: SyslogSeverity,
        deviceName: String,
        message: String,
        date: Date = Date()
    ) -> String {
        let priority = (local0FacilityValue * 8) + severity.numericValue
        let timestamp = formattedTimestamp(date)
        let hostname = sanitizedHostname(deviceName)
        let cleanMessage = sanitizedMessage(message)

        return "<\(priority)>\(timestamp) \(hostname) \(appName): \(cleanMessage)"
    }

    private static func formattedTimestamp(_ date: Date) -> String {
        timestampFormatter.string(from: date)
    }

    private static func sanitizedHostname(_ value: String) -> String {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        let fallback = Host.current().localizedName
            ?? Host.current().name
            ?? "Launch-Control-Center"

        let source = trimmedValue.isEmpty ? fallback : trimmedValue

        let whitespace = CharacterSet.whitespacesAndNewlines
        let components = source.components(separatedBy: whitespace)
        let joined = components
            .filter { $0.isEmpty == false }
            .joined(separator: "-")

        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        let filtered = joined.unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()

        return filtered.isEmpty ? "Launch-Control-Center" : filtered
    }

    private static func sanitizedMessage(_ value: String) -> String {
        let cleaned = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "No message" : cleaned
    }
}

