//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduleEntryFormatterTests.swift
//  Purpose: Verifies basic schedule occurrence generation rules.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import XCTest
@testable import Launch_Control_Center

final class ScheduleEntryFormatterTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testOneTimeEventGeneratesOccurrenceOnSameDayOnly() throws {
        let actionID = UUID()
        let start = try makeDate(year: 2026, month: 6, day: 22, hour: 16, minute: 30)
        let event = ScheduleEntry(actionDefinitionID: actionID, startDate: start)

        let sameDay = try makeDate(year: 2026, month: 6, day: 22, hour: 0, minute: 0)
        let nextDay = try makeDate(year: 2026, month: 6, day: 23, hour: 0, minute: 0)

        XCTAssertEqual(ScheduleEntryFormatter.occurrenceDates(for: event, on: sameDay, calendar: calendar), [start])
        XCTAssertTrue(ScheduleEntryFormatter.occurrenceDates(for: event, on: nextDay, calendar: calendar).isEmpty)
    }

    func testIntervalRepeatGeneratesExpectedSameDayOccurrences() throws {
        let actionID = UUID()
        let start = try makeDate(year: 2026, month: 6, day: 22, hour: 16, minute: 0)
        let end = try makeDate(year: 2026, month: 6, day: 22, hour: 17, minute: 0)
        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: start,
            repeatsDaily: true,
            repeatWeekdays: [2],
            repeatUntil: try makeDate(year: 2026, month: 6, day: 22, hour: 23, minute: 59),
            repeatMode: .intervalDuringDay,
            intervalMinutes: 30,
            intervalEndTime: end
        )

        let occurrences = ScheduleEntryFormatter.occurrenceDates(for: event, on: start, calendar: calendar)

        XCTAssertEqual(occurrences, [
            start,
            try makeDate(year: 2026, month: 6, day: 22, hour: 16, minute: 30),
            end
        ])
    }

    func testIntervalRepeatDoesNotCrossMidnight() throws {
        let actionID = UUID()
        let start = try makeDate(year: 2026, month: 6, day: 22, hour: 23, minute: 30)
        let end = try makeDate(year: 2026, month: 6, day: 23, hour: 0, minute: 30)
        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: start,
            repeatsDaily: true,
            repeatWeekdays: [2],
            repeatUntil: end,
            repeatMode: .intervalDuringDay,
            intervalMinutes: 15,
            intervalEndTime: end
        )

        XCTAssertTrue(ScheduleEntryFormatter.occurrenceDates(for: event, on: start, calendar: calendar).isEmpty)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) throws -> Date {
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )

        return try XCTUnwrap(calendar.date(from: components))
    }
}
