//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduleEntryFormatter.swift
//  Purpose: Shared operator-facing formatting and occurrence helpers for
//           scheduled Events.
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

        let baseText: String

        switch event.repeatMode {
        case .oncePerSelectedDay:
            baseText = weekdaySummary(for: event)

        case .intervalDuringDay:
            baseText = intervalRepeatSummary(for: event)
        }

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

    private static func intervalRepeatSummary(for event: ScheduleEntry) -> String {
        let dayText = weekdaySummary(for: event)
        let intervalText: String

        if let intervalMinutes = event.intervalMinutes, intervalMinutes > 0 {
            if intervalMinutes == 60 {
                intervalText = "hourly"
            } else if intervalMinutes % 60 == 0 {
                intervalText = "every \(intervalMinutes / 60) hours"
            } else {
                intervalText = "every \(intervalMinutes) minutes"
            }
        } else {
            intervalText = "at interval"
        }

        guard let intervalEndTime = event.intervalEndTime else {
            return "\(dayText), \(intervalText)"
        }

        return "\(dayText), \(intervalText) until \(timeFormatter.string(from: intervalEndTime))"
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

    // MARK: - Occurrence Generation

    /// Generates all occurrences for one calendar day.
    ///
    /// Existing Events continue to generate exactly one occurrence per eligible
    /// day. Interval support is present for the upcoming editor pass and remains
    /// same-day only; an invalid or midnight-crossing interval generates no
    /// occurrences instead of guessing operator intent.
    static func occurrenceDates(
        for event: ScheduleEntry,
        on day: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let dayStart = calendar.startOfDay(for: day)

        if event.repeatsDaily == false {
            guard calendar.isDate(event.startDate, inSameDayAs: day) else {
                return []
            }

            guard occurrenceIsNotExcluded(
                event,
                occurrenceDate: event.startDate,
                calendar: calendar
            ) else {
                return []
            }

            return [event.startDate]
        }

        guard eventCanOccur(on: dayStart, event: event, calendar: calendar) else {
            return []
        }

        switch event.repeatMode {
        case .oncePerSelectedDay:
            guard let occurrenceDate = date(
                on: dayStart,
                usingTimeFrom: event.startDate,
                calendar: calendar
            ) else {
                return []
            }

            guard occurrenceIsNotExcluded(
                event,
                occurrenceDate: occurrenceDate,
                calendar: calendar
            ) else {
                return []
            }

            return [occurrenceDate]

        case .intervalDuringDay:
            return intervalOccurrenceDates(
                for: event,
                on: dayStart,
                calendar: calendar
            )
        }
    }

    static func generatedOccurrences(
        for event: ScheduleEntry,
        on day: Date,
        calendar: Calendar = .current
    ) -> [ScheduleEntryOccurrence] {
        occurrenceDates(for: event, on: day, calendar: calendar).map { occurrenceDate in
            ScheduleEntryOccurrence(
                event: event,
                occurrenceDate: occurrenceDate
            )
        }
    }

    static func nextOccurrenceDate(
        for event: ScheduleEntry,
        from now: Date,
        maximumLookaheadDays: Int = 370,
        calendar: Calendar = .current
    ) -> Date? {
        if event.repeatsDaily == false {
            return event.startDate >= now ? event.startDate : nil
        }

        let today = calendar.startOfDay(for: now)
        let eventStartDay = calendar.startOfDay(for: event.startDate)
        let searchStartDay = max(today, eventStartDay)

        for dayOffset in 0...maximumLookaheadDays {
            guard let candidateDay = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: searchStartDay
            ) else {
                continue
            }

            let futureOccurrences = occurrenceDates(
                for: event,
                on: candidateDay,
                calendar: calendar
            )
            .filter { $0 >= now }
            .sorted()

            if let firstOccurrence = futureOccurrences.first {
                return firstOccurrence
            }
        }

        return nil
    }

    /// Returns the occurrence that should be evaluated by the 10 Hz scheduler
    /// for the current tick.
    ///
    /// This intentionally avoids generating an entire day of interval occurrences
    /// on every scheduler tick. The schedule engine runs at 10 Hz, so interval
    /// Events need a direct calculation path here for long-running efficiency.
    /// The returned Date is still checked by AppState's existing fire-tolerance
    /// and occurrence de-duplication guard before anything executes.
    static func occurrenceDateForScheduleProcessing(
        for event: ScheduleEntry,
        now: Date,
        calendar: Calendar = .current
    ) -> Date? {
        if event.repeatsDaily == false {
            guard calendar.isDate(event.startDate, inSameDayAs: now),
                  occurrenceIsNotExcluded(
                    event,
                    occurrenceDate: event.startDate,
                    calendar: calendar
                  ) else {
                return nil
            }

            return event.startDate
        }

        let dayStart = calendar.startOfDay(for: now)

        guard eventCanOccur(on: dayStart, event: event, calendar: calendar) else {
            return nil
        }

        switch event.repeatMode {
        case .oncePerSelectedDay:
            guard let occurrenceDate = date(
                on: dayStart,
                usingTimeFrom: event.startDate,
                calendar: calendar
            ),
            occurrenceIsNotExcluded(
                event,
                occurrenceDate: occurrenceDate,
                calendar: calendar
            ) else {
                return nil
            }

            return occurrenceDate

        case .intervalDuringDay:
            return intervalOccurrenceDateForScheduleProcessing(
                for: event,
                on: dayStart,
                now: now,
                calendar: calendar
            )
        }
    }

    static func occurrenceKey(
        eventID: UUID,
        occurrenceDate: Date
    ) -> String {
        "\(eventID.uuidString)-\(Int(occurrenceDate.timeIntervalSince1970))"
    }

    private static func eventCanOccur(
        on dayStart: Date,
        event: ScheduleEntry,
        calendar: Calendar
    ) -> Bool {
        let eventStartDay = calendar.startOfDay(for: event.startDate)

        guard dayStart >= eventStartDay else {
            return false
        }

        if let repeatUntil = event.repeatUntil {
            let repeatUntilDay = calendar.startOfDay(for: repeatUntil)

            guard dayStart <= repeatUntilDay else {
                return false
            }
        }

        if let seriesEndDate = event.seriesEndDate {
            let seriesEndDay = calendar.startOfDay(for: seriesEndDate)

            guard dayStart <= seriesEndDay else {
                return false
            }
        }

        let weekday = calendar.component(.weekday, from: dayStart)
        return selectedWeekdays(for: event).contains(weekday)
    }

    private static func intervalOccurrenceDateForScheduleProcessing(
        for event: ScheduleEntry,
        on dayStart: Date,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard let intervalMinutes = event.intervalMinutes,
              intervalMinutes > 0,
              let intervalEndTime = event.intervalEndTime,
              let firstOccurrence = date(
                on: dayStart,
                usingTimeFrom: event.startDate,
                calendar: calendar
              ),
              let finalOccurrenceBoundary = date(
                on: dayStart,
                usingTimeFrom: intervalEndTime,
                calendar: calendar
              ) else {
            return nil
        }

        // Same-day interval repeats intentionally may not cross midnight in v1.
        guard finalOccurrenceBoundary >= firstOccurrence else {
            return nil
        }

        let intervalSeconds = TimeInterval(intervalMinutes * 60)

        if now < firstOccurrence {
            return occurrenceIsNotExcluded(
                event,
                occurrenceDate: firstOccurrence,
                calendar: calendar
            ) ? firstOccurrence : nil
        }

        let elapsedSeconds = now.timeIntervalSince(firstOccurrence)
        var stepCount = Int(floor(elapsedSeconds / intervalSeconds))
        let maximumStepCount = Int(floor(finalOccurrenceBoundary.timeIntervalSince(firstOccurrence) / intervalSeconds))

        stepCount = min(max(stepCount, 0), maximumStepCount)

        // Walk backward over excluded occurrences. In normal operation this loop
        // exits immediately. It only iterates when an operator has removed one
        // or more generated instances from a recurring series.
        while stepCount >= 0 {
            let candidate = firstOccurrence.addingTimeInterval(
                TimeInterval(stepCount) * intervalSeconds
            )

            guard candidate <= finalOccurrenceBoundary else {
                stepCount -= 1
                continue
            }

            if occurrenceIsNotExcluded(
                event,
                occurrenceDate: candidate,
                calendar: calendar
            ) {
                return candidate
            }

            stepCount -= 1
        }

        return nil
    }

    private static func intervalOccurrenceDates(
        for event: ScheduleEntry,
        on dayStart: Date,
        calendar: Calendar
    ) -> [Date] {
        guard let intervalMinutes = event.intervalMinutes,
              intervalMinutes > 0,
              let intervalEndTime = event.intervalEndTime,
              let firstOccurrence = date(
                on: dayStart,
                usingTimeFrom: event.startDate,
                calendar: calendar
              ),
              let finalOccurrenceBoundary = date(
                on: dayStart,
                usingTimeFrom: intervalEndTime,
                calendar: calendar
              ) else {
            return []
        }

        // Same-day interval repeats intentionally may not cross midnight in v1.
        guard finalOccurrenceBoundary >= firstOccurrence else {
            return []
        }

        var occurrenceDates: [Date] = []
        var candidate = firstOccurrence
        var guardCount = 0

        while candidate <= finalOccurrenceBoundary, guardCount < 1_440 {
            if occurrenceIsNotExcluded(
                event,
                occurrenceDate: candidate,
                calendar: calendar
            ) {
                occurrenceDates.append(candidate)
            }

            guard let nextCandidate = calendar.date(
                byAdding: .minute,
                value: intervalMinutes,
                to: candidate
            ) else {
                break
            }

            candidate = nextCandidate
            guardCount += 1
        }

        return occurrenceDates
    }

    private static func occurrenceIsNotExcluded(
        _ event: ScheduleEntry,
        occurrenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        let exactKey = occurrenceKey(
            eventID: event.id,
            occurrenceDate: occurrenceDate
        )

        guard event.excludedOccurrenceKeys.contains(exactKey) == false else {
            return false
        }

        return event.excludedOccurrenceDates.contains { excludedDate in
            calendar.isDate(excludedDate, inSameDayAs: occurrenceDate)
        } == false
    }

    static func date(
        on day: Date,
        usingTimeFrom timeSource: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let dayComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: day
        )

        let timeComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: timeSource
        )

        var components = DateComponents()
        components.year = dayComponents.year
        components.month = dayComponents.month
        components.day = dayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second

        return calendar.date(from: components)
    }

    // MARK: - Date Formatting

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

