//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: DiagnosticBundleService.swift
//  Purpose: Creates operator-support diagnostic bundles containing configuration,
//           health, network, and log snapshots without changing playback behavior.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

struct DiagnosticBundleFile {
    let path: String
    let data: Data

    init(path: String, text: String) {
        self.path = path
        self.data = Data(text.utf8)
    }

    init(path: String, data: Data) {
        self.path = path
        self.data = data
    }
}

enum DiagnosticBundleService {
    // MARK: - Bundle Writing

    static func writeBundle(
        files: [DiagnosticBundleFile],
        to destinationURL: URL
    ) throws {
        let zipData = try makeStoredZipData(files: files)
        try zipData.write(to: destinationURL, options: [.atomic])
    }

    static func recentLogFiles(
        maxCount: Int = 5,
        logsFolderURL: URL? = OperationalLogService.shared.logsFolderURL
    ) -> [DiagnosticBundleFile] {
        guard let logsFolderURL else {
            return []
        }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: logsFolderURL,
                includingPropertiesForKeys: [
                    .contentModificationDateKey,
                    .isRegularFileKey
                ],
                options: [.skipsHiddenFiles]
            )
            .filter { $0.pathExtension.lowercased() == "log" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }
            .prefix(maxCount)

            return fileURLs.compactMap { fileURL in
                guard let data = try? Data(contentsOf: fileURL) else {
                    return nil
                }

                return DiagnosticBundleFile(
                    path: "Logs/\(fileURL.lastPathComponent)",
                    data: data
                )
            }
        } catch {
            return []
        }
    }

    // MARK: - Stored ZIP Writer

    private struct CentralDirectoryRecord {
        let fileNameData: Data
        let crc32: UInt32
        let size: UInt32
        let localHeaderOffset: UInt32
        let modificationTime: UInt16
        let modificationDate: UInt16
    }

    private static func makeStoredZipData(files: [DiagnosticBundleFile]) throws -> Data {
        var zipData = Data()
        var centralDirectoryRecords: [CentralDirectoryRecord] = []
        let dosTimestamp = currentDOSTimestamp()

        for file in files {
            let sanitizedPath = sanitizeZipPath(file.path)
            guard sanitizedPath.isEmpty == false else {
                continue
            }

            guard let fileNameData = sanitizedPath.data(using: .utf8) else {
                continue
            }

            guard fileNameData.count <= UInt16.max,
                  file.data.count <= UInt32.max,
                  zipData.count <= UInt32.max else {
                throw DiagnosticBundleError.fileTooLarge(sanitizedPath)
            }

            let crc = CRC32.checksum(file.data)
            let size = UInt32(file.data.count)
            let localHeaderOffset = UInt32(zipData.count)

            zipData.appendUInt32(0x04034b50)
            zipData.appendUInt16(20)
            zipData.appendUInt16(0)
            zipData.appendUInt16(0)
            zipData.appendUInt16(dosTimestamp.time)
            zipData.appendUInt16(dosTimestamp.date)
            zipData.appendUInt32(crc)
            zipData.appendUInt32(size)
            zipData.appendUInt32(size)
            zipData.appendUInt16(UInt16(fileNameData.count))
            zipData.appendUInt16(0)
            zipData.append(fileNameData)
            zipData.append(file.data)

            centralDirectoryRecords.append(
                CentralDirectoryRecord(
                    fileNameData: fileNameData,
                    crc32: crc,
                    size: size,
                    localHeaderOffset: localHeaderOffset,
                    modificationTime: dosTimestamp.time,
                    modificationDate: dosTimestamp.date
                )
            )
        }

        guard centralDirectoryRecords.count <= UInt16.max,
              zipData.count <= UInt32.max else {
            throw DiagnosticBundleError.bundleTooLarge
        }

        let centralDirectoryOffset = UInt32(zipData.count)

        for record in centralDirectoryRecords {
            zipData.appendUInt32(0x02014b50)
            zipData.appendUInt16(20)
            zipData.appendUInt16(20)
            zipData.appendUInt16(0)
            zipData.appendUInt16(0)
            zipData.appendUInt16(record.modificationTime)
            zipData.appendUInt16(record.modificationDate)
            zipData.appendUInt32(record.crc32)
            zipData.appendUInt32(record.size)
            zipData.appendUInt32(record.size)
            zipData.appendUInt16(UInt16(record.fileNameData.count))
            zipData.appendUInt16(0)
            zipData.appendUInt16(0)
            zipData.appendUInt16(0)
            zipData.appendUInt16(0)
            zipData.appendUInt32(0)
            zipData.appendUInt32(record.localHeaderOffset)
            zipData.append(record.fileNameData)
        }

        guard zipData.count <= UInt32.max else {
            throw DiagnosticBundleError.bundleTooLarge
        }

        let centralDirectorySize = UInt32(zipData.count) - centralDirectoryOffset
        let entryCount = UInt16(centralDirectoryRecords.count)

        zipData.appendUInt32(0x06054b50)
        zipData.appendUInt16(0)
        zipData.appendUInt16(0)
        zipData.appendUInt16(entryCount)
        zipData.appendUInt16(entryCount)
        zipData.appendUInt32(centralDirectorySize)
        zipData.appendUInt32(centralDirectoryOffset)
        zipData.appendUInt16(0)

        return zipData
    }

    private static func sanitizeZipPath(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .filter { part in
                part.isEmpty == false && part != "." && part != ".."
            }
            .joined(separator: "/")
    }

    private static func currentDOSTimestamp() -> (time: UInt16, date: UInt16) {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: Date()
        )

        let year = max((components.year ?? 1980) - 1980, 0)
        let month = max(components.month ?? 1, 1)
        let day = max(components.day ?? 1, 1)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2

        let dosTime = UInt16((hour << 11) | (minute << 5) | second)
        let dosDate = UInt16((year << 9) | (month << 5) | day)

        return (dosTime, dosDate)
    }
}

enum DiagnosticBundleError: LocalizedError {
    case fileTooLarge(String)
    case bundleTooLarge

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let fileName):
            return "Diagnostic file is too large for the lightweight ZIP writer: \(fileName)"

        case .bundleTooLarge:
            return "Diagnostic bundle is too large to export."
        }
    }
}

private enum CRC32 {
    private static let table: [UInt32] = {
        (0...255).map { value -> UInt32 in
            var crc = UInt32(value)

            for _ in 0..<8 {
                if (crc & 1) == 1 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }

            return crc
        }
    }()

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF

        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ table[index]
        }

        return crc ^ 0xFFFFFFFF
    }
}

private extension Data {
    mutating func appendUInt16(_ value: UInt16) {
        append(contentsOf: [
            UInt8(value & 0x00FF),
            UInt8((value & 0xFF00) >> 8)
        ])
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(contentsOf: [
            UInt8(value & 0x000000FF),
            UInt8((value & 0x0000FF00) >> 8),
            UInt8((value & 0x00FF0000) >> 16),
            UInt8((value & 0xFF000000) >> 24)
        ])
    }
}
