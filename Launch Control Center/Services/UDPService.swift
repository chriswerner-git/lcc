//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: UDPService.swift
//  Purpose: Handles UDP send and listen diagnostics.
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

    // MARK: - Private Properties

    private var listener: NWListener?

    // MARK: - Listening

    func startListening(port: UInt16) {
        stopListening()

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            listenerState = .failed
            listeningPort = nil
            lastReceivedMessage = "Invalid UDP listen port: \(port)"
            return
        }

        listenerState = .starting
        listeningPort = port
        lastReceivedMessage = "Starting UDP listener on port \(port)"

        do {
            listener = try NWListener(using: .udp, on: nwPort)

            listener?.newConnectionHandler = { [weak self] newConnection in
                newConnection.start(queue: .main)
                self?.receive(on: newConnection)
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
                        self.lastReceivedMessage = "Listening on UDP port \(port)"

                    case .failed(let error):
                        self.listenerState = .failed
                        self.listeningPort = nil
                        self.lastReceivedMessage = "UDP listener failed: \(error.localizedDescription)"

                    case .cancelled:
                        self.listenerState = .stopped
                        self.listeningPort = nil
                        self.lastReceivedMessage = "UDP listener stopped"

                    default:
                        break
                    }
                }
            }

            listener?.start(queue: .main)
        } catch {
            listenerState = .failed
            listeningPort = nil
            lastReceivedMessage = "Failed to listen: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        listener?.cancel()
        listener = nil
        listenerState = .stopped
        listeningPort = nil
        lastReceivedMessage = "UDP listener stopped"
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            DispatchQueue.main.async {
                if let data,
                   let message = String(data: data, encoding: .utf8) {
                    self?.lastReceivedMessage = message
                }

                if let error {
                    self?.lastReceivedMessage = "UDP receive error: \(error.localizedDescription)"
                }
            }

            if error == nil {
                self?.receive(on: connection)
            }
        }
    }

    // MARK: - Sending

    func send(
        message: String,
        host: String,
        port: UInt16
    ) {
        let destinationHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationPort = String(port)

        guard destinationHost.isEmpty == false else {
            updateSendStatus("UDP send failed: destination host is empty")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.sendUsingSocket(
                message: message,
                host: destinationHost,
                port: destinationPort
            )
        }
    }

    private func sendUsingSocket(
        message: String,
        host: String,
        port: String
    ) {
        let socketFileDescriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

        guard socketFileDescriptor >= 0 else {
            updateSendStatus("UDP socket failed: \(currentSocketError())")
            return
        }

        defer {
            close(socketFileDescriptor)
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

        updateSendStatus("Sent UDP to \(host):\(port) — \(message)")
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
}
