//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: OperationalLogService.swift
//  Purpose: Writes lightweight operational logs for long-running diagnostics.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import Foundation
import OSLog

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
    private let unifiedLogger = Logger(
        subsystem: "com.lunartelephone.launchcontrolcenter",
        category: "Operational"
    )

    // MARK: - Private State

    private let queue = DispatchQueue(
        label: "com.lunartelephone.launchcontrolcenter.operationallog",
        qos: .utility
    )

    private let timestampFormatter: DateFormatter
    private let fileDateFormatter: DateFormatter

    // These values are accessed only from the serial logging queue.
    private var activeFileHandle: FileHandle?
    private var activeLogFileURL: URL?

    private init() {
        timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd"
    }

    deinit {
        closeActiveFileHandle(synchronize: true)
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

        writeToUnifiedLog(
            level: level,
            message: message
        )

        queue.async { [weak self] in
            self?.writeSynchronously(
                level: level,
                message: message,
                date: date
            )
        }
    }

    /// Flushes pending log writes and closes the active file handle.
    ///
    /// This should be called during normal app termination. The method waits for any
    /// queued log writes to finish before closing the handle, which avoids leaving the
    /// last few lifecycle messages stranded in the logging queue during a graceful quit.
    func flushAndClose() {
        queue.sync { [weak self] in
            self?.closeActiveFileHandle(synchronize: true)
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
        var purgeResult: Result<Int, Error>!

        queue.sync { [weak self] in
            guard let self else {
                purgeResult = .success(0)
                return
            }

            do {
                // Close the active handle before pruning so the currently open file is
                // never deleted or rotated underneath an active FileHandle.
                closeActiveFileHandle(synchronize: true)

                let deletedCount = try purgeLogFilesOlderThanSynchronously(days: days)
                purgeResult = .success(deletedCount)
            } catch {
                purgeResult = .failure(error)
            }
        }

        return try purgeResult.get()
    }

    // MARK: - Unified Logging

    private func writeToUnifiedLog(
        level: Level,
        message: String
    ) {
        let cleanMessage = sanitized(message)

        switch level {
        case .info:
            unifiedLogger.info("\(cleanMessage, privacy: .public)")

        case .warning:
            unifiedLogger.warning("\(cleanMessage, privacy: .public)")

        case .error:
            unifiedLogger.error("\(cleanMessage, privacy: .public)")
        }
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

            let fileHandle = try fileHandleForWriting(to: logFileURL)
            try fileHandle.write(contentsOf: data)
        } catch {
            closeActiveFileHandle(synchronize: false)
            NSLog("Launch Control Center log write failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Log Pruning

    private func purgeLogFilesOlderThanSynchronously(days: Int) throws -> Int {
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

    // MARK: - File Handle Management

    private func fileHandleForWriting(to logFileURL: URL) throws -> FileHandle {
        if let activeFileHandle,
           activeLogFileURL == logFileURL {
            return activeFileHandle
        }

        closeActiveFileHandle(synchronize: true)

        if FileManager.default.fileExists(atPath: logFileURL.path) == false {
            FileManager.default.createFile(
                atPath: logFileURL.path,
                contents: nil
            )
        }

        let fileHandle = try FileHandle(forWritingTo: logFileURL)
        try fileHandle.seekToEnd()

        activeFileHandle = fileHandle
        activeLogFileURL = logFileURL

        return fileHandle
    }

    private func closeActiveFileHandle(synchronize: Bool) {
        guard let fileHandle = activeFileHandle else {
            activeLogFileURL = nil
            return
        }

        if synchronize {
            fileHandle.synchronizeFile()
        }

        do {
            try fileHandle.close()
        } catch {
            NSLog("Launch Control Center log close failed: \(error.localizedDescription)")
        }

        activeFileHandle = nil
        activeLogFileURL = nil
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

