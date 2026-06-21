//
//  TodayScheduleView.swift
//  Launch Control Center
//
//  Displays today's scheduled Events.
//
//  Events determine when something happens.
//  Actions determine what happens.
//

import SwiftUI

struct TodayScheduleView: View {
    @EnvironmentObject var appState: AppState

    private var todaysEvents: [ScheduleEntry] {
        appState.scheduleEntries
            .filter { eventIsToday($0) }
            .sorted {
                occurrenceDateToday(for: $0) < occurrenceDateToday(for: $1)
            }
    }

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let nextEventID = nextUpcomingEventID(now: context.date)

            VStack(alignment: .leading, spacing: 10) {
                sectionHeader

                VStack(alignment: .leading, spacing: 0) {
                    if todaysEvents.isEmpty {
                        emptyState
                    } else {
                        ScrollViewReader { scrollProxy in
                            ScrollView(.vertical) {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(todaysEvents) { event in
                                        let occurrenceDate = occurrenceDateToday(for: event)

                                        ScheduleEntryRow(
                                            event: event,
                                            occurrenceDate: occurrenceDate,
                                            isPast: occurrenceDate < context.date,
                                            isNext: event.id == nextEventID
                                        )
                                        .environmentObject(appState)
                                        .id(event.id)

                                        if event.id != todaysEvents.last?.id {
                                            Divider()
                                                .opacity(0.28)
                                                .padding(.leading, 24)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .onAppear {
                                scrollToNextEvent(
                                    nextEventID,
                                    using: scrollProxy,
                                    animated: false
                                )
                            }
                            .onChange(of: nextEventID) { _, newValue in
                                scrollToNextEvent(
                                    newValue,
                                    using: scrollProxy,
                                    animated: true
                                )
                            }
                            .onChange(of: todaysEvents.map(\.id)) { _, _ in
                                scrollToNextEvent(
                                    nextEventID,
                                    using: scrollProxy,
                                    animated: true
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(todayCardBackground)
                .overlay(todayCardBorder)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Today's Events")
                .font(.headline)

            Text("\(todaysEvents.count) scheduled")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.bottom, 1)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.secondary)

            Text("No Events scheduled for today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Scrolling

    private func scrollToNextEvent(
        _ eventID: UUID?,
        using scrollProxy: ScrollViewProxy,
        animated: Bool
    ) {
        guard let eventID else {
            return
        }

        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeInOut(duration: 0.25)) {
                    scrollProxy.scrollTo(eventID, anchor: .center)
                }
            } else {
                scrollProxy.scrollTo(eventID, anchor: .center)
            }
        }
    }

    // MARK: - Date Helpers

    private func nextUpcomingEventID(now: Date) -> UUID? {
        todaysEvents
            .filter { occurrenceDateToday(for: $0) >= now }
            .sorted { occurrenceDateToday(for: $0) < occurrenceDateToday(for: $1) }
            .first?
            .id
    }

    private func eventIsToday(_ event: ScheduleEntry) -> Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let isExcluded = event.excludedOccurrenceDates.contains { excludedDate in
            calendar.isDate(excludedDate, inSameDayAs: today)
        }

        guard isExcluded == false else {
            return false
        }

        if event.repeatsDaily == false {
            return calendar.isDateInToday(event.startDate)
        }

        let eventStartDay = calendar.startOfDay(for: event.startDate)

        guard today >= eventStartDay else {
            return false
        }

        if let repeatUntil = event.repeatUntil {
            let repeatUntilDay = calendar.startOfDay(for: repeatUntil)

            guard today <= repeatUntilDay else {
                return false
            }
        }

        let todayWeekday = calendar.component(.weekday, from: today)
        return selectedWeekdays(for: event).contains(todayWeekday)
    }

    private func occurrenceDateToday(for event: ScheduleEntry) -> Date {
        let calendar = Calendar.current

        guard event.repeatsDaily else {
            return event.startDate
        }

        let now = Date()
        let todayComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: now
        )

        let timeComponents = calendar.dateComponents(
            [.hour, .minute, .second],
            from: event.startDate
        )

        var components = DateComponents()
        components.year = todayComponents.year
        components.month = todayComponents.month
        components.day = todayComponents.day
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = timeComponents.second

        return calendar.date(from: components) ?? event.startDate
    }

    private func selectedWeekdays(for event: ScheduleEntry) -> Set<Int> {
        if event.repeatWeekdays.isEmpty {
            return Set(1...7)
        }

        return event.repeatWeekdays
    }

    // MARK: - Styling

    private var todayCardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var todayCardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    }
}

// MARK: - Row

struct ScheduleEntryRow: View {
    @EnvironmentObject var appState: AppState

    let event: ScheduleEntry
    let occurrenceDate: Date
    let isPast: Bool
    let isNext: Bool

    private var action: ActionDefinition? {
        appState.actionDefinitions.first {
            $0.id == event.actionDefinitionID
        }
    }

    private var rowForeground: Color {
        isPast ? Color.primary.opacity(0.34) : .primary
    }

    private var secondaryForeground: Color {
        isPast ? Color.secondary.opacity(0.42) : .secondary
    }

    private var actionTypeColor: Color {
        switch action?.type {
        case .show:
            return .blue

        case .utility:
            return .purple

        case .none:
            return .secondary
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = appState.use24HourTime ? "HH:mm:ss" : "h:mm:ss a"
        return formatter.string(from: occurrenceDate)
    }

    private var actionTypeText: String {
        action?.type.rawValue ?? "Missing"
    }

    private var repeatText: String {
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

        return weekdayNames(for: weekdays).joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            nextIndicator

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(timeText)
                        .font(.system(.body, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(rowForeground)

                    typePill

                    Text(repeatText)
                        .font(.caption)
                        .foregroundStyle(secondaryForeground)
                }

                Text(action?.name ?? "Unknown Action")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(rowForeground)
                    .lineLimit(1)
            }

            Spacer()

            if isPast {
                Text("Past")
                    .font(.caption)
                    .foregroundStyle(Color.secondary.opacity(0.40))
            } else if isNext {
                Text("Next")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }

            Button("Run") {
                if let action {
                    appState.runAction(action)
                }
            }
            .disabled(action == nil)

            Button("Delete") {
                appState.scheduleEntries.removeAll {
                    $0.id == event.id
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(rowBackground)
        .contentShape(Rectangle())
    }

    private var nextIndicator: some View {
        Circle()
            .fill(isNext ? Color.blue : Color.clear)
            .frame(width: 9, height: 9)
    }

    private var typePill: some View {
        Text(actionTypeText)
            .font(.caption2)
            .bold()
            .foregroundStyle(action == nil ? secondaryForeground : actionTypeColor.opacity(isPast ? 0.48 : 1.0))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(actionTypeColor.opacity(action == nil ? 0.08 : (isPast ? 0.08 : 0.16)))
            )
    }

    private var rowBackground: some View {
        Rectangle()
            .fill(
                isPast
                    ? Color.black.opacity(0.14)
                    : (isNext ? Color.blue.opacity(0.055) : Color.clear)
            )
    }

    private func selectedWeekdays(for event: ScheduleEntry) -> Set<Int> {
        if event.repeatWeekdays.isEmpty {
            return Set(1...7)
        }

        return event.repeatWeekdays
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
}
