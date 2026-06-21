//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduleEngine.swift
//  Purpose: Provides the heartbeat used to check scheduled Events.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

final class ScheduleEngine {
    private var timer: Timer?

    func start(
        interval: TimeInterval = 1.0,
        handler: @escaping () -> Void
    ) {
        stop()

        timer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { _ in
            handler()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
