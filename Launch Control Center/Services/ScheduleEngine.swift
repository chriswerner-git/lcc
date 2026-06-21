//
//  ScheduleEngine.swift
//  Launch Control Center
//
//  Lightweight repeating timer used by AppState to check scheduled Events.
//
//  The engine does not decide what should run.
//  It simply provides a reliable heartbeat.
//
//  Schedule logic lives in AppState so it can access:
//  - saved schedule entries
//  - saved action definitions
//  - Show / Utility enable toggles
//  - dashboard status state
//
//
//  Lightweight repeating timer used by AppState to check scheduled Events.
//

import Foundation

final class ScheduleEngine {
    private var timer: Timer?

    func start(
        interval: TimeInterval = 1.0,
        handler: @escaping () -> Void
    ) {
        stop()

        let newTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { _ in
            handler()
        }

        timer = newTimer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
