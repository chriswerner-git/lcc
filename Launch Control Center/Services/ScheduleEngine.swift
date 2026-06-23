//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduleEngine.swift
//  Purpose: Provides the heartbeat used to check scheduled Events.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

final class ScheduleEngine {
    // MARK: - Properties

    private var timer: Timer?

    // MARK: - Control

    func start(
        interval: TimeInterval = 0.1,
        handler: @escaping () -> Void
    ) {
        stop()

        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { _ in
            handler()
        }

        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
