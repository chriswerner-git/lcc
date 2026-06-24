//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: NTPQueryService.swift
//  Purpose: Performs lightweight NTP clock checks for Dashboard time-health status.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation
import Network

struct NTPQueryResult: Codable, Equatable {
    let server: String
    let stratum: Int
    let referenceID: String
    let roundTripDelaySeconds: TimeInterval
    let clockOffsetSeconds: TimeInterval
    let queriedAt: Date

    var offsetMilliseconds: Double {
        clockOffsetSeconds * 1_000
    }

    var roundTripMilliseconds: Double {
        roundTripDelaySeconds * 1_000
    }
}

enum NTPQueryError: LocalizedError {
    case invalidServer
    case timeout
    case noResponse
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .invalidServer:
            return "NTP server is blank."

        case .timeout:
            return "NTP query timed out."

        case .noResponse:
            return "No response from NTP server."

        case .invalidResponse(let reason):
            return "Invalid NTP response: \(reason)."
        }
    }
}

final class NTPQueryService {
    static let defaultServer = "time.apple.com"

    private let timeoutSeconds: TimeInterval
    private let ntpEpochOffset: TimeInterval = 2_208_988_800

    init(timeoutSeconds: TimeInterval = 3) {
        self.timeoutSeconds = timeoutSeconds
    }

    func query(server: String = NTPQueryService.defaultServer) async throws -> NTPQueryResult {
        let trimmedServer = server.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedServer.isEmpty == false else {
            throw NTPQueryError.invalidServer
        }

        guard let port = NWEndpoint.Port(rawValue: 123) else {
            throw NTPQueryError.invalidResponse("invalid NTP port")
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(trimmedServer),
            port: port,
            using: .udp
        )

        let t1 = Date()
        let requestPacket = buildRequestPacket(transmitTime: t1)

        let responseData = try await receiveResponse(
            connection: connection,
            requestPacket: requestPacket
        )

        let t4 = Date()
        return try parseResponse(
            responseData,
            server: trimmedServer,
            t1: t1,
            t4: t4
        )
    }

    private func receiveResponse(
        connection: NWConnection,
        requestPacket: Data
    ) async throws -> Data {
        final class ResumeGate {
            private let lock = NSLock()
            private var didResume = false

            func resumeOnce(_ work: () -> Void) {
                lock.lock()
                defer { lock.unlock() }

                guard didResume == false else {
                    return
                }

                didResume = true
                work()
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            let resumeGate = ResumeGate()
            let queue = DispatchQueue(label: "com.lunartelephone.launchcontrolcenter.ntp.query", qos: .utility)
            let timeout = DispatchWorkItem {
                resumeGate.resumeOnce {
                    connection.cancel()
                    continuation.resume(throwing: NTPQueryError.timeout)
                }
            }

            queue.asyncAfter(deadline: .now() + timeoutSeconds, execute: timeout)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(
                        content: requestPacket,
                        completion: .contentProcessed { error in
                            if let error {
                                resumeGate.resumeOnce {
                                    timeout.cancel()
                                    connection.cancel()
                                    continuation.resume(throwing: error)
                                }
                                return
                            }

                            connection.receiveMessage { data, _, _, error in
                                resumeGate.resumeOnce {
                                    timeout.cancel()
                                    connection.cancel()

                                    if let error {
                                        continuation.resume(throwing: error)
                                    } else if let data {
                                        continuation.resume(returning: data)
                                    } else {
                                        continuation.resume(throwing: NTPQueryError.noResponse)
                                    }
                                }
                            }
                        }
                    )

                case .failed(let error):
                    resumeGate.resumeOnce {
                        timeout.cancel()
                        connection.cancel()
                        continuation.resume(throwing: error)
                    }

                case .cancelled:
                    break

                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }

    private func buildRequestPacket(transmitTime: Date) -> Data {
        var bytes = [UInt8](repeating: 0, count: 48)

        // LI = 0, Version = 4, Mode = 3 (client)
        bytes[0] = 0x23
        writeTimestamp(transmitTime, into: &bytes, at: 40)

        return Data(bytes)
    }

    private func writeTimestamp(
        _ date: Date,
        into bytes: inout [UInt8],
        at offset: Int
    ) {
        let ntpTime = date.timeIntervalSince1970 + ntpEpochOffset
        let seconds = UInt32(ntpTime)
        let fraction = UInt32((ntpTime - Double(seconds)) * 4_294_967_296)

        bytes[offset] = UInt8((seconds >> 24) & 0xFF)
        bytes[offset + 1] = UInt8((seconds >> 16) & 0xFF)
        bytes[offset + 2] = UInt8((seconds >> 8) & 0xFF)
        bytes[offset + 3] = UInt8(seconds & 0xFF)
        bytes[offset + 4] = UInt8((fraction >> 24) & 0xFF)
        bytes[offset + 5] = UInt8((fraction >> 16) & 0xFF)
        bytes[offset + 6] = UInt8((fraction >> 8) & 0xFF)
        bytes[offset + 7] = UInt8(fraction & 0xFF)
    }

    private func parseResponse(
        _ data: Data,
        server: String,
        t1: Date,
        t4: Date
    ) throws -> NTPQueryResult {
        guard data.count >= 48 else {
            throw NTPQueryError.invalidResponse("packet too short (\(data.count) bytes)")
        }

        let bytes = [UInt8](data)
        let stratum = Int(bytes[1])

        guard stratum > 0 else {
            throw NTPQueryError.invalidResponse("server returned stratum 0")
        }

        let referenceID = referenceIdentifier(bytes: bytes, stratum: stratum)
        let t2 = ntpDate(bytes: bytes, offset: 32)
        let t3 = ntpDate(bytes: bytes, offset: 40)

        let roundTrip = (t4.timeIntervalSince(t1)) - (t3.timeIntervalSince(t2))
        let offset = ((t2.timeIntervalSince(t1)) + (t3.timeIntervalSince(t4))) / 2

        return NTPQueryResult(
            server: server,
            stratum: stratum,
            referenceID: referenceID,
            roundTripDelaySeconds: max(0, roundTrip),
            clockOffsetSeconds: offset,
            queriedAt: t4
        )
    }

    private func referenceIdentifier(bytes: [UInt8], stratum: Int) -> String {
        guard bytes.count >= 16 else {
            return "—"
        }

        if stratum <= 1 {
            let scalars = bytes[12...15].compactMap { byte -> UnicodeScalar? in
                guard byte > 0x20, byte < 0x7F else {
                    return nil
                }

                return UnicodeScalar(byte)
            }

            let text = String(String.UnicodeScalarView(scalars))
            return text.isEmpty ? "—" : text
        }

        return "\(bytes[12]).\(bytes[13]).\(bytes[14]).\(bytes[15])"
    }

    private func ntpDate(bytes: [UInt8], offset: Int) -> Date {
        let seconds = UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])

        let fraction = UInt32(bytes[offset + 4]) << 24
            | UInt32(bytes[offset + 5]) << 16
            | UInt32(bytes[offset + 6]) << 8
            | UInt32(bytes[offset + 7])

        let unixTime = Double(seconds) - ntpEpochOffset
            + Double(fraction) / 4_294_967_296

        return Date(timeIntervalSince1970: unixTime)
    }
}
