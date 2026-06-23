//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: SystemLifecycleService.swift
//  Purpose: Monitors macOS sleep, wake, activation, and termination events.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import Foundation

final class SystemLifecycleService {
    // MARK: - Event

    enum Event {
        case willSleep(Date)
        case didWake(Date)
        case didBecomeActive
        case willTerminate(Date)
    }

    // MARK: - Observer Token

    private struct ObserverToken {
        let center: NotificationCenter
        let token: NSObjectProtocol
    }

    // MARK: - Properties

    private var observerTokens: [ObserverToken] = []

    private(set) var isMonitoring: Bool = false

    // MARK: - Control

    func start(handler: @escaping (Event) -> Void) {
        stop()

        addObserver(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.willSleepNotification
        ) { _ in
            handler(.willSleep(Date()))
        }

        addObserver(
            center: NSWorkspace.shared.notificationCenter,
            name: NSWorkspace.didWakeNotification
        ) { _ in
            handler(.didWake(Date()))
        }

        addObserver(
            center: NotificationCenter.default,
            name: NSApplication.didBecomeActiveNotification
        ) { _ in
            handler(.didBecomeActive)
        }

        addObserver(
            center: NotificationCenter.default,
            name: NSApplication.willTerminateNotification
        ) { _ in
            handler(.willTerminate(Date()))
        }

        isMonitoring = true
    }

    func stop() {
        for observerToken in observerTokens {
            observerToken.center.removeObserver(observerToken.token)
        }

        observerTokens.removeAll()
        isMonitoring = false
    }

    deinit {
        stop()
    }

    // MARK: - Observer Helper

    private func addObserver(
        center: NotificationCenter,
        name: Notification.Name,
        handler: @escaping (Notification) -> Void
    ) {
        let token = center.addObserver(
            forName: name,
            object: nil,
            queue: .main,
            using: handler
        )

        observerTokens.append(
            ObserverToken(
                center: center,
                token: token
            )
        )
    }
}

