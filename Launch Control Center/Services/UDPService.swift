//
//  UDPService.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//

import Foundation
import Network
import Combine

class UDPService: ObservableObject {
    @Published var lastReceivedMessage: String = "No UDP messages received"

    private var listener: NWListener?
    private var connection: NWConnection?

    func startListening(port: UInt16) {
        do {
            listener = try NWListener(using: .udp, on: NWEndpoint.Port(rawValue: port)!)

            listener?.newConnectionHandler = { [weak self] newConnection in
                newConnection.start(queue: .main)
                self?.receive(on: newConnection)
            }

            listener?.start(queue: .main)
            lastReceivedMessage = "Listening on UDP port \(port)"
        } catch {
            lastReceivedMessage = "Failed to listen: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        listener?.cancel()
        listener = nil
        lastReceivedMessage = "UDP listener stopped"
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data,
               let message = String(data: data, encoding: .utf8) {
                self?.lastReceivedMessage = message
            }

            if error == nil {
                self?.receive(on: connection)
            }
        }
    }

    func send(message: String, host: String, port: UInt16) {
        let endpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!

        connection = NWConnection(host: endpoint, port: nwPort, using: .udp)
        connection?.start(queue: .main)

        let data = Data(message.utf8)

        connection?.send(content: data, completion: .contentProcessed { error in
            if let error {
                print("UDP send error: \(error)")
            }
        })
    }
}
