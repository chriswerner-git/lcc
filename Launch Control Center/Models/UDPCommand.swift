//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: UDPCommand.swift
//  Purpose: Defines one message step inside a Show Action.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

enum MessageStepType: String, CaseIterable, Codable, Identifiable {
    case standardUDP = "Standard UDP"
    case syslog = "Syslog"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .standardUDP:
            return "paperplane.fill"

        case .syslog:
            return "doc.text.fill"
        }
    }
}

enum SyslogSeverity: String, CaseIterable, Codable, Identifiable {
    case emergency = "Emergency"
    case alert = "Alert"
    case critical = "Critical"
    case error = "Error"
    case warning = "Warning"
    case notice = "Notice"
    case info = "Info"
    case debug = "Debug"

    var id: String {
        rawValue
    }

    var numericValue: Int {
        switch self {
        case .emergency:
            return 0

        case .alert:
            return 1

        case .critical:
            return 2

        case .error:
            return 3

        case .warning:
            return 4

        case .notice:
            return 5

        case .info:
            return 6

        case .debug:
            return 7
        }
    }
}

struct UDPCommand: Identifiable, Codable {
    // MARK: - Identity

    // Stable identifier for editing, sorting, and persistence.
    var id: UUID = UUID()

    // MARK: - Message Type

    // Defines how the outgoing UDP payload is generated.
    var messageType: MessageStepType = .standardUDP

    // MARK: - Operator Info

    // Operator-facing step name.
    var name: String = "Message Step"

    // MARK: - Destination Endpoint

    var host: String = "127.0.0.1"
    var port: Int = 8001

    // MARK: - Network Options

    // Empty means Automatic routing. When set, the UDP socket attempts to bind
    // to this local IPv4 address before sending.
    var sourceIPAddress: String = ""

    // Enables SO_BROADCAST for this step when sending to a subnet broadcast address.
    var allowsBroadcast: Bool = false

    // MARK: - Message Payload

    // For Standard UDP, this is sent as-is.
    // For Syslog, this is the human-readable log message used to generate
    // the syslog-style UDP payload.
    var message: String = ""

    // MARK: - Syslog

    // Used only when messageType is .syslog.
    var syslogSeverity: SyslogSeverity = .info

    // MARK: - Timing

    // Delay before this command runs, measured from the previous step.
    var delaySeconds: Double = 0

    // MARK: - Init

    init(
        id: UUID = UUID(),
        messageType: MessageStepType = .standardUDP,
        name: String = "Message Step",
        host: String = "127.0.0.1",
        port: Int = 8001,
        sourceIPAddress: String = "",
        allowsBroadcast: Bool = false,
        message: String = "",
        syslogSeverity: SyslogSeverity = .info,
        delaySeconds: Double = 0
    ) {
        self.id = id
        self.messageType = messageType
        self.name = name
        self.host = host
        self.port = port
        self.sourceIPAddress = sourceIPAddress
        self.allowsBroadcast = allowsBroadcast
        self.message = message
        self.syslogSeverity = syslogSeverity
        self.delaySeconds = delaySeconds
    }

    // MARK: - Codable Compatibility

    enum CodingKeys: String, CodingKey {
        case id
        case messageType
        case name
        case host
        case port
        case sourceIPAddress
        case allowsBroadcast
        case message
        case syslogSeverity
        case delaySeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        messageType = try container.decodeIfPresent(MessageStepType.self, forKey: .messageType) ?? .standardUDP
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Message Step"
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? "127.0.0.1"
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 8001
        sourceIPAddress = try container.decodeIfPresent(String.self, forKey: .sourceIPAddress) ?? ""
        allowsBroadcast = try container.decodeIfPresent(Bool.self, forKey: .allowsBroadcast) ?? false
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        syslogSeverity = try container.decodeIfPresent(SyslogSeverity.self, forKey: .syslogSeverity) ?? .info
        delaySeconds = try container.decodeIfPresent(Double.self, forKey: .delaySeconds) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(messageType, forKey: .messageType)
        try container.encode(name, forKey: .name)
        try container.encode(host, forKey: .host)
        try container.encode(port, forKey: .port)
        try container.encode(sourceIPAddress, forKey: .sourceIPAddress)
        try container.encode(allowsBroadcast, forKey: .allowsBroadcast)
        try container.encode(message, forKey: .message)
        try container.encode(syslogSeverity, forKey: .syslogSeverity)
        try container.encode(delaySeconds, forKey: .delaySeconds)
    }
}
