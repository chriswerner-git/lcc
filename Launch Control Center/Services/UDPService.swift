//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: UDPService.swift
//  Purpose: Handles UDP send and short-duration listen diagnostics.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Combine
import Darwin
import Foundation
import Network

enum UDPListenerState: String {
    case stopped = "Not Listening"
    case starting = "Starting Listener"
    case listening = "Listening"
    case failed = "Listener Failed"
}

final class UDPService: ObservableObject {
    // MARK: - Published State

    @Published var lastReceivedMessage: String = "No UDP messages received"
    @Published var lastSendStatus: String = "No UDP messages sent"
    @Published var listenerState: UDPListenerState = .stopped
    @Published var listeningPort: UInt16?
    @Published var listeningLocalIPAddress: String?
    @Published var listenerAutomaticStopMessage: String?

    // MARK: - Private Properties

    private var listener: NWListener?
    private var listenerTimeoutTimer: Timer?
    private var listenerCancellationStatusMessage: String = "UDP listener stopped"

    // UDP output is intentionally serialized.
    //
    // Launch Control Center may fire Actions from manual controls, schedule
    // evaluation, or future utility paths.  A dedicated serial queue keeps
    // outbound UDP messages in call order and avoids creating an unbounded
    // number of global worker tasks during bursts.
    private let sendQueue = DispatchQueue(
        label: "com.lunartelephone.launchcontrolcenter.udp.send",
        qos: .userInitiated
    )

    // MARK: - Constants

    private let listenerTimeoutSeconds: TimeInterval = 10 * 60

    // MARK: - Listening

    func startListening(
        port: UInt16,
        localIPAddress: String? = nil
    ) {
        stopListening(
            statusMessage: "UDP listener restarting",
            showAutomaticStopAlert: false
        )

        listenerAutomaticStopMessage = nil

        let trimmedLocalIPAddress = localIPAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundLocalIPAddress = (trimmedLocalIPAddress?.isEmpty == false) ? trimmedLocalIPAddress : nil

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            listenerState = .failed
            listeningPort = nil
            listeningLocalIPAddress = nil
            lastReceivedMessage = "Invalid UDP listen port: \(port)"
            return
        }

        listenerState = .starting
        listeningPort = port
        listeningLocalIPAddress = boundLocalIPAddress

        if let boundLocalIPAddress {
            lastReceivedMessage = "Starting UDP listener on \(boundLocalIPAddress):\(port). Diagnostic listener will stop automatically after 10 minutes."
        } else {
            lastReceivedMessage = "Starting UDP listener on all interfaces, port \(port). Diagnostic listener will stop automatically after 10 minutes."
        }

        do {
            let parameters = NWParameters.udp

            if let boundLocalIPAddress {
                parameters.requiredLocalEndpoint = .hostPort(
                    host: NWEndpoint.Host(boundLocalIPAddress),
                    port: nwPort
                )
            }

            listener = try NWListener(using: parameters, on: nwPort)

            listener?.newConnectionHandler = { [weak self] newConnection in
                guard let self else {
                    newConnection.cancel()
                    return
                }

                newConnection.start(queue: .main)
                self.receive(on: newConnection)
            }

            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }

                    switch state {
                    case .ready:
                        self.listenerState = .listening
                        self.listeningPort = port
                        self.listeningLocalIPAddress = boundLocalIPAddress

                        if let boundLocalIPAddress {
                            self.lastReceivedMessage = "Listening on \(boundLocalIPAddress):\(port). Listener will stop automatically after 10 minutes."
                        } else {
                            self.lastReceivedMessage = "Listening on all interfaces, port \(port). Listener will stop automatically after 10 minutes."
                        }

                        self.startListenerTimeoutTimer()

                    case .failed(let error):
                        self.cancelListenerTimeoutTimer()
                        self.listenerState = .failed
                        self.listeningPort = nil
                        self.listeningLocalIPAddress = nil
                        self.lastReceivedMessage = "UDP listener failed: \(error.localizedDescription)"

                    case .cancelled:
                        self.cancelListenerTimeoutTimer()
                        self.listenerState = .stopped
                        self.listeningPort = nil
                        self.listeningLocalIPAddress = nil
                        self.lastReceivedMessage = self.listenerCancellationStatusMessage

                    default:
                        break
                    }
                }
            }

            listener?.start(queue: .main)
        } catch {
            cancelListenerTimeoutTimer()
            listenerState = .failed
            listeningPort = nil
            listeningLocalIPAddress = nil
            lastReceivedMessage = "Failed to listen: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        stopListening(
            statusMessage: "UDP listener stopped",
            showAutomaticStopAlert: false
        )
    }

    private func stopListening(
        statusMessage: String,
        showAutomaticStopAlert: Bool
    ) {
        cancelListenerTimeoutTimer()

        listenerCancellationStatusMessage = statusMessage

        if showAutomaticStopAlert {
            listenerAutomaticStopMessage = statusMessage
        }

        listener?.cancel()
        listener = nil

        listenerState = .stopped
        listeningPort = nil
        listeningLocalIPAddress = nil
        lastReceivedMessage = statusMessage
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            DispatchQueue.main.async {
                guard let self else {
                    connection?.cancel()
                    return
                }

                guard self.listenerState == .listening else {
                    connection?.cancel()
                    return
                }

                if let data,
                   let message = String(data: data, encoding: .utf8) {
                    self.lastReceivedMessage = message
                }

                if let error {
                    self.lastReceivedMessage = "UDP receive error: \(error.localizedDescription)"
                }
            }

            guard error == nil else {
                connection?.cancel()
                return
            }

            DispatchQueue.main.async { [weak self, weak connection] in
                guard let self,
                      let connection,
                      self.listenerState == .listening else {
                    connection?.cancel()
                    return
                }

                self.receive(on: connection)
            }
        }
    }

    // MARK: - Listener Timeout

    private func startListenerTimeoutTimer() {
        cancelListenerTimeoutTimer()

        listenerTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: listenerTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.listenerTimedOut()
            }
        }

        if let listenerTimeoutTimer {
            RunLoop.main.add(listenerTimeoutTimer, forMode: .common)
        }
    }

    private func cancelListenerTimeoutTimer() {
        listenerTimeoutTimer?.invalidate()
        listenerTimeoutTimer = nil
    }

    private func listenerTimedOut() {
        stopListening(
            statusMessage: "UDP diagnostic listener stopped automatically after 10 minutes.",
            showAutomaticStopAlert: true
        )
    }

    func clearAutomaticStopMessage() {
        listenerAutomaticStopMessage = nil
    }

    // MARK: - Sending

    func send(
        message: String,
        host: String,
        port: UInt16,
        sourceIPAddress: String? = nil,
        allowsBroadcast: Bool = false
    ) {
        let destinationHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationPort = String(port)
        let trimmedSourceIPAddress = sourceIPAddress?.trimmingCharacters(in: .whitespacesAndNewlines)
        let boundSourceIPAddress = (trimmedSourceIPAddress?.isEmpty == false) ? trimmedSourceIPAddress : nil

        guard destinationHost.isEmpty == false else {
            updateSendStatus("UDP send failed: destination host is empty")
            return
        }

        sendQueue.async { [weak self] in
            self?.sendUsingSocket(
                message: message,
                host: destinationHost,
                port: destinationPort,
                sourceIPAddress: boundSourceIPAddress,
                allowsBroadcast: allowsBroadcast
            )
        }
    }

    private func sendUsingSocket(
        message: String,
        host: String,
        port: String,
        sourceIPAddress: String?,
        allowsBroadcast: Bool
    ) {
        let socketFileDescriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

        guard socketFileDescriptor >= 0 else {
            updateSendStatus("UDP socket failed: \(currentSocketError())")
            return
        }

        defer {
            close(socketFileDescriptor)
        }

        if allowsBroadcast {
            var broadcastEnabled: Int32 = 1
            let broadcastResult = setsockopt(
                socketFileDescriptor,
                SOL_SOCKET,
                SO_BROADCAST,
                &broadcastEnabled,
                socklen_t(MemoryLayout<Int32>.size)
            )

            guard broadcastResult == 0 else {
                updateSendStatus("UDP broadcast setup failed: \(currentSocketError())")
                return
            }
        }

        if let sourceIPAddress {
            guard bindSocket(socketFileDescriptor, to: sourceIPAddress) else {
                updateSendStatus("UDP source bind failed for \(sourceIPAddress): \(currentSocketError())")
                return
            }
        }

        var hints = addrinfo(
            ai_flags: 0,
            ai_family: AF_INET,
            ai_socktype: SOCK_DGRAM,
            ai_protocol: IPPROTO_UDP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var addressInfoPointer: UnsafeMutablePointer<addrinfo>?

        let lookupResult = getaddrinfo(
            host,
            port,
            &hints,
            &addressInfoPointer
        )

        guard lookupResult == 0,
              let addressInfoPointer else {
            let errorMessage = String(cString: gai_strerror(lookupResult))
            updateSendStatus("UDP address lookup failed: \(errorMessage)")
            return
        }

        defer {
            freeaddrinfo(addressInfoPointer)
        }

        let messageData = Array(message.utf8)

        let sentByteCount = messageData.withUnsafeBytes { rawBufferPointer in
            sendto(
                socketFileDescriptor,
                rawBufferPointer.baseAddress,
                rawBufferPointer.count,
                0,
                addressInfoPointer.pointee.ai_addr,
                addressInfoPointer.pointee.ai_addrlen
            )
        }

        guard sentByteCount >= 0 else {
            updateSendStatus("UDP send failed: \(currentSocketError())")
            return
        }

        let sourceDescription = sourceIPAddress.map { " from \($0)" } ?? ""
        let broadcastDescription = allowsBroadcast ? " broadcast" : ""
        updateSendStatus("Sent UDP\(broadcastDescription)\(sourceDescription) to \(host):\(port) — \(message)")
    }

    private func bindSocket(
        _ socketFileDescriptor: Int32,
        to sourceIPAddress: String
    ) -> Bool {
        var sourceAddress = sockaddr_in()
        sourceAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        sourceAddress.sin_family = sa_family_t(AF_INET)
        sourceAddress.sin_port = 0

        guard inet_pton(AF_INET, sourceIPAddress, &sourceAddress.sin_addr) == 1 else {
            errno = EINVAL
            return false
        }

        return withUnsafePointer(to: &sourceAddress) { sourceAddressPointer in
            sourceAddressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddressPointer in
                bind(
                    socketFileDescriptor,
                    socketAddressPointer,
                    socklen_t(MemoryLayout<sockaddr_in>.size)
                ) == 0
            }
        }
    }

    // MARK: - Status Helpers

    private func updateSendStatus(_ status: String) {
        DispatchQueue.main.async { [weak self] in
            self?.lastSendStatus = status
        }
    }

    private func currentSocketError() -> String {
        String(cString: strerror(errno))
    }

    deinit {
        stopListening(
            statusMessage: "UDP listener stopped",
            showAutomaticStopAlert: false
        )
    }
}

