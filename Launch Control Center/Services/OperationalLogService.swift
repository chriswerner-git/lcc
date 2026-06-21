//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: OperationalLogService.swift
//  Purpose: Writes lightweight operational logs for long-running diagnostics.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import Foundation

final class OperationalLogService {
    // MARK: - Shared Instance

    static let shared = OperationalLogService()

    // MARK: - Log Level

    enum Level: String {
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    // MARK: - Constants

    private let appSupportFolderName = "Launch Control Center"
    private let logsFolderName = "Logs"
    private let maxLogFileSizeBytes: UInt64 = 5 * 1024 * 1024

    // MARK: - Private State

    private let queue = DispatchQueue(
        label: "com.lunartelephone.launchcontrolcenter.operationallog",
        qos: .utility
    )

    private let timestampFormatter: DateFormatter
    private let fileDateFormatter: DateFormatter

    private init() {
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd"
    }

    // MARK: - Public Logging

    func info(_ message: String) {
        write(level: .info, message: message)
    }

    func warning(_ message: String) {
        write(level: .warning, message: message)
    }

    func error(_ message: String) {
        write(level: .error, message: message)
    }

    func write(
        level: Level,
        message: String
    ) {
        let date = Date()

        queue.async { [weak self] in
            self?.writeSynchronously(
                level: level,
                message: message,
                date: date
            )
        }
    }

    // MARK: - Folder Access

    var logsFolderURL: URL? {
        do {
            return try createLogsFolderIfNeeded()
        } catch {
            return nil
        }
    }

    func openLogsFolder() throws {
        let url = try createLogsFolderIfNeeded()
        NSWorkspace.shared.open(url)
    }

    // MARK: - Log Pruning

    @discardableResult
    func purgeLogFilesOlderThan(days: Int) throws -> Int {
        let safeDays = max(days, 1)
        let logsFolderURL = try createLogsFolderIfNeeded()
        let cutoffDate = Date().addingTimeInterval(-Double(safeDays) * 86_400)

        let fileURLs = try FileManager.default.contentsOfDirectory(
            at: logsFolderURL,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .isRegularFileKey
            ],
            options: [
                .skipsHiddenFiles
            ]
        )

        var deletedCount = 0

        for fileURL in fileURLs {
            guard fileURL.pathExtension.lowercased() == "log" else {
                continue
            }

            let resourceValues = try fileURL.resourceValues(
                forKeys: [
                    .contentModificationDateKey,
                    .isRegularFileKey
                ]
            )

            guard resourceValues.isRegularFile == true else {
                continue
            }

            let modificationDate = resourceValues.contentModificationDate ?? Date()

            guard modificationDate < cutoffDate else {
                continue
            }

            try FileManager.default.removeItem(at: fileURL)
            deletedCount += 1
        }

        return deletedCount
    }

    // MARK: - Private Write

    private func writeSynchronously(
        level: Level,
        message: String,
        date: Date
    ) {
        do {
            let logsFolderURL = try createLogsFolderIfNeeded()
            let logFileURL = try currentLogFileURL(
                in: logsFolderURL,
                date: date
            )

            let cleanMessage = sanitized(message)
            let timestamp = timestampFormatter.string(from: date)
            let line = "[\(timestamp)] [\(level.rawValue)] \(cleanMessage)\n"

            guard let data = line.data(using: .utf8) else {
                return
            }

            if FileManager.default.fileExists(atPath: logFileURL.path) == false {
                FileManager.default.createFile(
                    atPath: logFileURL.path,
                    contents: nil
                )
            }

            let fileHandle = try FileHandle(forWritingTo: logFileURL)

            defer {
                try? fileHandle.close()
            }

            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)
        } catch {
            NSLog("Launch Control Center log write failed: \(error.localizedDescription)")
        }
    }

    // MARK: - File Helpers

    private func createLogsFolderIfNeeded() throws -> URL {
        let applicationSupportURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appFolderURL = applicationSupportURL
            .appendingPathComponent(appSupportFolderName, isDirectory: true)

        let logsFolderURL = appFolderURL
            .appendingPathComponent(logsFolderName, isDirectory: true)

        try FileManager.default.createDirectory(
            at: logsFolderURL,
            withIntermediateDirectories: true
        )

        return logsFolderURL
    }

    private func currentLogFileURL(
        in logsFolderURL: URL,
        date: Date
    ) throws -> URL {
        let dateStamp = fileDateFormatter.string(from: date)
        let baseName = "LaunchControlCenter_\(dateStamp)"
        let baseURL = logsFolderURL.appendingPathComponent("\(baseName).log")

        if logFileIsBelowSizeLimit(baseURL) {
            return baseURL
        }

        for index in 1...999 {
            let rotatedURL = logsFolderURL.appendingPathComponent("\(baseName)_\(index).log")

            if logFileIsBelowSizeLimit(rotatedURL) {
                return rotatedURL
            }
        }

        return baseURL
    }

    private func logFileIsBelowSizeLimit(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return true
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(
                atPath: url.path
            )

            let fileSize = attributes[.size] as? UInt64 ?? 0
            return fileSize < maxLogFileSizeBytes
        } catch {
            return true
        }
    }

    private func sanitized(_ message: String) -> String {
        message
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
