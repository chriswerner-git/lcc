//
//  AppState.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//
import Foundation
import Combine

class AppState: ObservableObject {
    let udpService = UDPService()
    
    @Published var isSystemActive: Bool {
        didSet {
            UserDefaults.standard.set(isSystemActive, forKey: "isSystemActive")
        }
    }

    @Published var udpHost: String {
        didSet {
            UserDefaults.standard.set(udpHost, forKey: "udpHost")
        }
    }

    @Published var udpPort: Int {
        didSet {
            UserDefaults.standard.set(udpPort, forKey: "udpPort")
        }
    }

    @Published var lastMessage: String = "No messages yet"

    init() {
        self.isSystemActive = UserDefaults.standard.object(forKey: "isSystemActive") as? Bool ?? false
        self.udpHost = UserDefaults.standard.string(forKey: "udpHost") ?? "127.0.0.1"
        self.udpPort = UserDefaults.standard.object(forKey: "udpPort") as? Int ?? 8000
    }
}
