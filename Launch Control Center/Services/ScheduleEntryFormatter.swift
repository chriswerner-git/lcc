//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduleEntryFormatter.swift
//  Purpose: Shared operator-facing formatting helpers for scheduled Events.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

enum ScheduleEntryFormatter {
    // MARK: - Weekday Constants

    static let allWeekdays: Set<Int> = Set(1...7)
    static let weekdays: Set<Int> = Set([2, 3, 4, 5, 6])
    static let weekends: Set<Int> = Set([1, 7])
    static let orderedWeekdays: [Int] = [1, 2, 3, 4, 5, 6, 7]

    // MARK: - Repeat Summaries

    static func repeatSummary(
        for event: ScheduleEntry,
        oneTimeText: String = "One-time",
        includeRepeatUntil: Bool = false
    ) -> String {
        guard event.repeatsDaily else {
            return oneTimeText
        }

        let baseText = weekdaySummary(for: event)

        guard includeRepeatUntil, let repeatUntil = event.repeatUntil else {
            return baseText
        }

        return "\(baseText), until \(shortDateFormatter.string(from: repeatUntil))"
    }

    static func weekdaySummary(for event: ScheduleEntry) -> String {
        weekdaySummary(for: selectedWeekdays(for: event))
    }

    static func weekdaySummary(for weekdays: Set<Int>) -> String {
        if weekdays == allWeekdays {
            return "Every day"
        }

        if weekdays == Self.weekdays {
            return "Weekdays"
        }

        if weekdays == weekends {
            return "Weekends"
        }

        return weekdayNames(for: weekdays).joined(separator: ", ")
    }

    // MARK: - Weekday Helpers

    static func selectedWeekdays(for event: ScheduleEntry) -> Set<Int> {
        event.repeatWeekdays.isEmpty ? allWeekdays : event.repeatWeekdays
    }

    static func weekdayNames(for weekdays: Set<Int>) -> [String] {
        orderedWeekdays
            .filter { weekdays.contains($0) }
            .map { shortWeekdayName(for: $0) }
    }

    static func shortWeekdayName(for weekday: Int) -> String {
        switch weekday {
        case 1:
            return "Sun"

        case 2:
            return "Mon"

        case 3:
            return "Tue"

        case 4:
            return "Wed"

        case 5:
            return "Thu"

        case 6:
            return "Fri"

        case 7:
            return "Sat"

        default:
            return "?"
        }
    }

    // MARK: - Date Formatting

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

