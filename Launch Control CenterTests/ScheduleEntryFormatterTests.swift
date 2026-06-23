//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                    │
//  │  Launch Control Center                                      │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduleEntryFormatterTests.swift
//  Purpose: Verifies schedule occurrence generation edge behavior.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import XCTest
@testable import Launch_Control_Center

@MainActor
final class ScheduleEntryFormatterTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testOneTimeEventGeneratesOnlyOnStartDate() throws {
        let actionID = UUID()
        let start = try makeDate(year: 2026, month: 6, day: 22, hour: 16, minute: 30)
        let sameDay = try makeDate(year: 2026, month: 6, day: 22, hour: 0, minute: 0)
        let nextDay = try makeDate(year: 2026, month: 6, day: 23, hour: 0, minute: 0)

        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: start,
            repeatsDaily: false
        )

        XCTAssertEqual(
            ScheduleEntryFormatter.occurrenceDates(for: event, on: sameDay, calendar: calendar),
            [start]
        )

        XCTAssertTrue(
            ScheduleEntryFormatter.occurrenceDates(for: event, on: nextDay, calendar: calendar).isEmpty
        )
    }

    func testIntervalRepeatGeneratesInclusiveSameDayOccurrences() throws {
        let actionID = UUID()
        let start = try makeDate(year: 2026, month: 6, day: 22, hour: 16, minute: 0)
        let end = try makeDate(year: 2026, month: 6, day: 22, hour: 17, minute: 0)
        let day = try makeDate(year: 2026, month: 6, day: 22, hour: 0, minute: 0)

        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: start,
            repeatsDaily: true,
            repeatWeekdays: [2],
            repeatUntil: day,
            repeatMode: .intervalDuringDay,
            intervalMinutes: 30,
            intervalEndTime: end
        )

        let occurrences = ScheduleEntryFormatter.occurrenceDates(
            for: event,
            on: day,
            calendar: calendar
        )

        XCTAssertEqual(occurrences.count, 3)
        XCTAssertEqual(occurrences[0], start)
        XCTAssertEqual(occurrences[1], try makeDate(year: 2026, month: 6, day: 22, hour: 16, minute: 30))
        XCTAssertEqual(occurrences[2], end)
    }

    func testIntervalRepeatDoesNotCrossMidnight() throws {
        let actionID = UUID()
        let start = try makeDate(year: 2026, month: 6, day: 22, hour: 23, minute: 30)
        let end = try makeDate(year: 2026, month: 6, day: 22, hour: 0, minute: 30)
        let day = try makeDate(year: 2026, month: 6, day: 22, hour: 0, minute: 0)

        let event = ScheduleEntry(
            actionDefinitionID: actionID,
            startDate: start,
            repeatsDaily: true,
            repeatWeekdays: [2],
            repeatUntil: day,
            repeatMode: .intervalDuringDay,
            intervalMinutes: 30,
            intervalEndTime: end
        )

        XCTAssertTrue(
            ScheduleEntryFormatter.occurrenceDates(for: event, on: day, calendar: calendar).isEmpty
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int = 0
    ) throws -> Date {
        let date = calendar.date(
            from: DateComponents(
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )

        return try XCTUnwrap(date)
    }
}
