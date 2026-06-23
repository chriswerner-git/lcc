//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: TodayScheduleView.swift
//  Purpose: Displays today's scheduled Events on the Dashboard.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI

struct TodayScheduleView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Body

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            let scheduleItems = todaysScheduleItems(referenceDate: context.date)
            let nextEventID = nextUpcomingEventID(
                now: context.date,
                items: scheduleItems
            )

            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(eventCount: scheduleItems.count)

                VStack(alignment: .leading, spacing: 0) {
                    if scheduleItems.isEmpty {
                        emptyState
                    } else {
                        eventList(
                            items: scheduleItems,
                            now: context.date,
                            nextEventID: nextEventID
                        )
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

    private func sectionHeader(eventCount: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Today's Events")
                .font(.headline)

            Text("\(eventCount) scheduled")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.bottom, 1)
    }

    // MARK: - Event List

    private func eventList(
        items: [TodayScheduleItem],
        now: Date,
        nextEventID: String?
    ) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        ScheduleEntryRow(
                            event: item.event,
                            occurrenceDate: item.occurrenceDate,
                            isPast: item.occurrenceDate < now,
                            isNext: item.id == nextEventID
                        )
                        .environmentObject(appState)
                        .id(item.id)

                        if item.id != items.last?.id {
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
            .onChange(of: items.map(\.id)) { _, _ in
                scrollToNextEvent(
                    nextEventID,
                    using: scrollProxy,
                    animated: true
                )
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.secondary)

            Text("No enabled Events scheduled for today.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Scrolling

    private func scrollToNextEvent(
        _ eventID: String?,
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

    // MARK: - Schedule Item Calculation

    private func todaysScheduleItems(referenceDate: Date) -> [TodayScheduleItem] {
        appState.scheduleEntries
            .filter { $0.enabled }
            .flatMap { event -> [TodayScheduleItem] in
                ScheduleEntryFormatter.occurrenceDates(
                    for: event,
                    on: referenceDate
                )
                .map { occurrenceDate in
                    TodayScheduleItem(
                        event: event,
                        occurrenceDate: occurrenceDate
                    )
                }
            }
            .sorted { $0.occurrenceDate < $1.occurrenceDate }
    }

    private func nextUpcomingEventID(
        now: Date,
        items: [TodayScheduleItem]
    ) -> String? {
        items.first { $0.occurrenceDate >= now }?.id
    }

    private func selectedWeekdays(for event: ScheduleEntry) -> Set<Int> {
        ScheduleEntryFormatter.selectedWeekdays(for: event)
    }

    // MARK: - Styling

    private var todayCardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LCCDesign.ColorToken.controlBackground.opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var todayCardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }
}

// MARK: - Today Schedule Item

private struct TodayScheduleItem: Identifiable {
    let event: ScheduleEntry
    let occurrenceDate: Date

    var id: String {
        ScheduleEntryFormatter.occurrenceKey(
            eventID: event.id,
            occurrenceDate: occurrenceDate
        )
    }
}

// MARK: - Schedule Entry Row

struct ScheduleEntryRow: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Properties

    let event: ScheduleEntry
    let occurrenceDate: Date
    let isPast: Bool
    let isNext: Bool

    // MARK: - Derived State

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
        guard let action else {
            return .secondary
        }

        return LCCDesign.actionColor(for: action.type)
    }

    private var timeText: String {
        if appState.use24HourTime {
            return ScheduleEntryRow.time24HourFormatter.string(from: occurrenceDate)
        }

        return ScheduleEntryRow.time12HourFormatter.string(from: occurrenceDate)
    }

    private var actionTypeText: String {
        action?.type.rawValue ?? "Missing"
    }

    private var repeatText: String {
        ScheduleEntryFormatter.repeatSummary(for: event)
    }

    // MARK: - Body

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

            statusLabel

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

    // MARK: - Row Pieces

    private var nextIndicator: some View {
        Circle()
            .fill(isNext ? LCCDesign.ColorToken.active : Color.clear)
            .frame(width: 9, height: 9)
    }

    private var typePill: some View {
        Text(actionTypeText)
            .font(.caption2)
            .bold()
            .foregroundStyle(
                action == nil
                    ? secondaryForeground
                    : actionTypeColor.opacity(isPast ? 0.48 : 1.0)
            )
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(
                        actionTypeColor.opacity(
                            action == nil
                                ? 0.08
                                : (isPast ? 0.08 : 0.16)
                        )
                    )
            )
    }

    private var statusLabel: some View {
        Group {
            if isPast {
                Text("Past")
                    .font(.caption)
                    .foregroundStyle(Color.secondary.opacity(0.40))
            } else if isNext {
                Text("Next")
                    .font(.caption)
                    .foregroundStyle(LCCDesign.ColorToken.active)
            }
        }
    }

    private var rowBackground: some View {
        Rectangle()
            .fill(
                isPast
                    ? Color.black.opacity(0.14)
                    : (isNext ? LCCDesign.ColorToken.active.opacity(0.055) : Color.clear)
            )
    }

    // MARK: - Date Formatting

    private static let time24HourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let time12HourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter
    }()

    // MARK: - Weekday Helpers

    private func selectedWeekdays(for event: ScheduleEntry) -> Set<Int> {
        ScheduleEntryFormatter.selectedWeekdays(for: event)
    }

}


