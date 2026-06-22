//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: StatusPanelView.swift
//  Purpose: Dashboard clock, schedule status, and Event summary panels.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI

// MARK: - Dashboard Clock

struct DashboardClockView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    // MARK: - Derived Time Metadata

    private var timeZoneText: String {
        TimeZone.current.identifier
    }

    private var utcOffsetText: String {
        let seconds = TimeZone.current.secondsFromGMT()
        let sign = seconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(seconds)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60

        if minutes == 0 {
            return "UTC \(sign)\(hours)"
        }

        return String(format: "UTC %@%d:%02d", sign, hours, minutes)
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            ZStack(alignment: .bottomTrailing) {
                clockDisplay(for: context.date)

                lowerLeftDiagnostics
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .bottomLeading
                    )

                clockMetadata(
                    status: timeDataStatus(for: context.date)
                )
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 16)
            .background(dashboardCardBackground)
            .overlay(dashboardCardBorder)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    // MARK: - Clock Display

    private func clockDisplay(for date: Date) -> some View {
        VStack(spacing: 4) {
            Text(appState.projectName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(clockTime(date))
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .monospacedDigit()

            Text("\(dayOfWeek(date)), \(calendarDate(date))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Lower-Left Diagnostics

    private var lowerLeftDiagnostics: some View {
        VStack(alignment: .leading, spacing: 7) {
            uptimeMetadata
            aboutButton
        }
        .padding(.leading, 2)
        .padding(.bottom, 2)
    }

    private var uptimeMetadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Computer Uptime: \(UptimeService.formattedComputerUptime())")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Text("App Uptime: \(UptimeService.formattedAppUptime())")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .help("Computer uptime is time since the Mac last booted. App uptime is time since Launch Control Center started.")
    }

    private var aboutButton: some View {
        Button {
            openWindow(id: "about-lcc-window")
        } label: {
            Label("About LCC", systemImage: "info.circle")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help("About Launch Control Center")
    }

    // MARK: - Clock Metadata

    private func clockMetadata(status: ClockDataStatus) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 5) {
                Circle()
                    .fill(status.color)
                    .frame(width: 7, height: 7)

                Text(status.label)
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(status.color)
            }

            Text("Source: System Clock")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Timezone: \(timeZoneText)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(utcOffsetText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.trailing, 4)
        .padding(.bottom, 2)
        .help("This indicates the Dashboard clock is updating from the local system clock. It does not yet verify an external NTP server.")
    }

    private func timeDataStatus(for timelineDate: Date) -> ClockDataStatus {
        let age = abs(Date().timeIntervalSince(timelineDate))

        if age <= 3 {
            return .fresh
        }

        if age <= 30 {
            return .stale
        }

        return .missing
    }

    // MARK: - Date Formatting

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let calendarDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

    private static let clockTime24HourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let clockTime12HourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter
    }()

    private func dayOfWeek(_ date: Date) -> String {
        DashboardClockView.dayOfWeekFormatter.string(from: date)
    }

    private func calendarDate(_ date: Date) -> String {
        DashboardClockView.calendarDateFormatter.string(from: date)
    }

    private func clockTime(_ date: Date) -> String {
        if appState.use24HourTime {
            return DashboardClockView.clockTime24HourFormatter.string(from: date)
        }

        return DashboardClockView.clockTime12HourFormatter.string(from: date)
    }
}

// MARK: - Clock Data Status

private enum ClockDataStatus {
    case fresh
    case stale
    case missing

    var label: String {
        switch self {
        case .fresh:
            return "Time Data Fresh"

        case .stale:
            return "Time Data Stale"

        case .missing:
            return "Time Data Missing"
        }
    }

    var color: Color {
        switch self {
        case .fresh:
            return .blue

        case .stale:
            return .yellow

        case .missing:
            return .red
        }
    }
}

// MARK: - Schedule Status

struct ScheduleStatusView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader

            HStack(spacing: 14) {
                scheduleToggleCard(
                    title: "Show Actions",
                    subtitle: "Scheduled show playback",
                    isEnabled: appState.showActionsEnabled,
                    setEnabled: appState.setShowActionsEnabled
                )

                scheduleToggleCard(
                    title: "Utility Actions",
                    subtitle: "Scheduled utility macros",
                    isEnabled: appState.utilityActionsEnabled,
                    setEnabled: appState.setUtilityActionsEnabled
                )
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Schedule")
                .font(.headline)

            Text("Affects scheduled Events only. Manual Actions are not affected by these toggles.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.bottom, 1)
    }

    // MARK: - Toggle Cards

    private func scheduleToggleCard(
        title: String,
        subtitle: String,
        isEnabled: Bool,
        setEnabled: @escaping (Bool) -> Void
    ) -> some View {
        HStack(spacing: 12) {
            statusDot(isEnabled: isEnabled)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .foregroundStyle(isEnabled ? .blue : .secondary)

            Toggle(
                "",
                isOn: Binding(
                    get: {
                        isEnabled
                    },
                    set: { newValue in
                        setEnabled(newValue)
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(dashboardCardBackground)
        .overlay(dashboardCardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusDot(isEnabled: Bool) -> some View {
        Circle()
            .fill(isEnabled ? .blue : Color.secondary.opacity(0.45))
            .frame(width: 9, height: 9)
    }
}

// MARK: - Event Summary

struct EventSummaryView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Layout Constants

    private let eventCardHeight: CGFloat = 86

    // MARK: - Body

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader

                HStack(alignment: .top, spacing: 14) {
                    eventCardContainer {
                        nextEventContent(now: context.date)
                    }

                    eventCardContainer {
                        lastEventContent
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Events")
                .font(.headline)

            Text("Next scheduled Event and most recent run")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.bottom, 1)
    }

    // MARK: - Cards

    private func eventCardContainer<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: eventCardHeight, alignment: .topLeading)
            .background(dashboardCardBackground)
            .overlay(dashboardCardBorder)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func nextEventContent(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Next Event")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let next = nextEvent(from: now) {
                Text(next.action.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formattedDateTime(next.occurrenceDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text(repeatSummary(for: next.event))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text("Starts in \(countdown(to: next.occurrenceDate, from: now))")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)
            } else {
                Text("No upcoming enabled Event")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("Schedule is clear.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var lastEventContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last Event")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(appState.lastEventMessage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Event Selection

    private func nextEvent(from now: Date) -> (event: ScheduleEntry, action: ActionDefinition, occurrenceDate: Date)? {
        appState.scheduleEntries
            .filter { $0.enabled }
            .compactMap { event -> (ScheduleEntry, ActionDefinition, Date)? in
                guard let action = appState.actionDefinitions.first(where: {
                    $0.id == event.actionDefinitionID
                }) else {
                    return nil
                }

                guard eventIsAllowed(action) else {
                    return nil
                }

                guard let occurrenceDate = nextOccurrenceDate(
                    for: event,
                    from: now
                ) else {
                    return nil
                }

                return (event, action, occurrenceDate)
            }
            .sorted { $0.2 < $1.2 }
            .first
    }

    private func eventIsAllowed(_ action: ActionDefinition) -> Bool {
        switch action.type {
        case .show:
            return appState.showActionsEnabled

        case .utility:
            return appState.utilityActionsEnabled
        }
    }

    // MARK: - Occurrence Calculation

    private func nextOccurrenceDate(
        for event: ScheduleEntry,
        from now: Date
    ) -> Date? {
        if event.repeatsDaily == false {
            return event.startDate >= now ? event.startDate : nil
        }

        let calendar = Calendar.current
        let selectedWeekdays = selectedWeekdays(for: event)
        let eventStartDay = calendar.startOfDay(for: event.startDate)

        for dayOffset in 0...370 {
            guard let candidateDay = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: calendar.startOfDay(for: now)
            ) else {
                continue
            }

            guard candidateDay >= eventStartDay else {
                continue
            }

            if let repeatUntil = event.repeatUntil {
                let repeatUntilDay = calendar.startOfDay(for: repeatUntil)

                guard candidateDay <= repeatUntilDay else {
                    return nil
                }
            }

            guard eventIsNotExcluded(event, on: candidateDay) else {
                continue
            }

            let candidateWeekday = calendar.component(
                .weekday,
                from: candidateDay
            )

            guard selectedWeekdays.contains(candidateWeekday) else {
                continue
            }

            let occurrenceDate = occurrenceDate(
                on: candidateDay,
                usingTimeFrom: event.startDate
            )

            if occurrenceDate >= now {
                return occurrenceDate
            }
        }

        return nil
    }

    private func occurrenceDate(
        on day: Date,
        usingTimeFrom timeSource: Date
    ) -> Date {
        let calendar = Calendar.current

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

        return calendar.date(from: components) ?? timeSource
    }

    private func selectedWeekdays(for event: ScheduleEntry) -> Set<Int> {
        if event.repeatWeekdays.isEmpty {
            return Set(1...7)
        }

        return event.repeatWeekdays
    }

    private func eventIsNotExcluded(
        _ event: ScheduleEntry,
        on date: Date
    ) -> Bool {
        let calendar = Calendar.current

        return event.excludedOccurrenceDates.contains { excludedDate in
            calendar.isDate(excludedDate, inSameDayAs: date)
        } == false
    }

    // MARK: - Event Text Formatting

    private func repeatSummary(for event: ScheduleEntry) -> String {
        guard event.repeatsDaily else {
            return "One-time"
        }

        let weekdays = selectedWeekdays(for: event)

        if weekdays == Set(1...7) {
            return "Every day"
        }

        if weekdays == Set([2, 3, 4, 5, 6]) {
            return "Weekdays"
        }

        if weekdays == Set([1, 7]) {
            return "Weekends"
        }

        let names = weekdayNames(for: weekdays)
        return names.joined(separator: ", ")
    }

    private func weekdayNames(for weekdays: Set<Int>) -> [String] {
        let orderedWeekdays = [1, 2, 3, 4, 5, 6, 7]

        return orderedWeekdays
            .filter { weekdays.contains($0) }
            .map { weekdayShortName($0) }
    }

    private func weekdayShortName(_ weekday: Int) -> String {
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

    private static let dateTime24HourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss"
        return formatter
    }()

    private static let dateTime12HourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM yyyy h:mm:ss a"
        return formatter
    }()

    private func formattedDateTime(_ date: Date) -> String {
        if appState.use24HourTime {
            return EventSummaryView.dateTime24HourFormatter.string(from: date)
        }

        return EventSummaryView.dateTime12HourFormatter.string(from: date)
    }

    private func countdown(to date: Date, from now: Date) -> String {
        let interval = max(Int(date.timeIntervalSince(now)), 0)

        let days = interval / 86_400
        let hours = (interval % 86_400) / 3_600
        let minutes = (interval % 3_600) / 60
        let seconds = interval % 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m \(seconds)s"
        }

        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        }

        return "\(minutes)m \(seconds)s"
    }
}

// MARK: - Shared Dashboard Card Styling

private var dashboardCardBackground: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
        .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
}

private var dashboardCardBorder: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
}

