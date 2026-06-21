//
//  ScheduleCalendarView.swift
//  Launch Control Center
//
//  Weekly and monthly graphical schedule view.
//
//  Weekly view uses an hour grid.
//  Monthly view shows daily counts by Action type.
//
//  Event actions are available by right-click context menu.
//  Double-click an Event chip to edit.
//

import SwiftUI

struct ScheduleCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    @AppStorage("scheduleHourRowHeight") private var storedHourRowHeight: Double = 92

    @State private var visibleWeekStart: Date = ScheduleCalendarView.startOfWeek(
        containing: Date(),
        startingOn: 1
    )

    @State private var visibleMonthDate: Date = Date()
    @State private var selectedViewMode: ScheduleViewMode = .week

    @State private var editingOccurrence: ScheduleOccurrence?
    @State private var deletingOccurrence: ScheduleOccurrence?

    private let timeColumnWidth: CGFloat = 62
    private let dayHeaderHeight: CGFloat = 74

    private var hourRowHeight: CGFloat {
        CGFloat(storedHourRowHeight)
    }

    private var weekDays: [Date] {
        (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: visibleWeekStart)
        }
    }

    private var deleteDialogIsPresented: Binding<Bool> {
        Binding(
            get: {
                deletingOccurrence != nil
            },
            set: { newValue in
                if newValue == false {
                    deletingOccurrence = nil
                }
            }
        )
    }

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 14) {
                header
                topControls

                switch selectedViewMode {
                case .week:
                    weekGrid

                case .month:
                    monthGrid
                }
            }
            .padding(20)
        }
        .frame(minWidth: 1220, minHeight: 780)
        .onAppear {
            visibleWeekStart = Self.startOfWeek(
                containing: Date(),
                startingOn: appState.weekStartDay
            )

            visibleMonthDate = Date()
        }
        .onChange(of: appState.weekStartDay) { _, newValue in
            visibleWeekStart = Self.startOfWeek(
                containing: visibleWeekStart,
                startingOn: newValue
            )
        }
        .sheet(item: $editingOccurrence) { occurrence in
            ScheduleEventEditSheet(occurrence: occurrence)
                .environmentObject(appState)
        }
        .confirmationDialog(
            "Delete Event",
            isPresented: deleteDialogIsPresented,
            titleVisibility: .visible
        ) {
            if let occurrence = deletingOccurrence {
                deleteDialogButtons(for: occurrence)
            } else {
                Button("Cancel", role: .cancel) { }
            }
        } message: {
            if let occurrence = deletingOccurrence {
                deleteDialogMessage(for: occurrence)
            } else {
                Text("No Event selected.")
            }
        }
    }

    // MARK: - Main Sections

    private var background: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.58)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 40, height: 40)

                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Schedule")
                    .font(.largeTitle)
                    .bold()

                Text("Weekly time grid and monthly overview of scheduled Events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openWindow(id: "actions-window")
            } label: {
                Label("Define Actions", systemImage: "rectangle.stack.badge.play")
            }
            .buttonStyle(.bordered)

            Button {
                openWindow(id: "event-editor-window")
            } label: {
                Label("Add Events", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var topControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker("", selection: $selectedViewMode) {
                    ForEach(ScheduleViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)

                Divider()
                    .frame(height: 22)

                Button {
                    moveVisibleRange(by: -1)
                } label: {
                    Label(previousButtonTitle, systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)

                Button {
                    moveToCurrentRange()
                } label: {
                    Label(currentButtonTitle, systemImage: "dot.scope")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    moveVisibleRange(by: 1)
                } label: {
                    Label(nextButtonTitle, systemImage: "chevron.right")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(visibleRangeText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if selectedViewMode == .week {
                HStack(spacing: 10) {
                    Text("Hour Height")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: $storedHourRowHeight, in: 58...150)
                        .frame(width: 220)

                    Text("\(Int(storedHourRowHeight))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)

                    Text("Right-click Events for Run, Edit, Delete. Double-click to edit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
    }

    private var previousButtonTitle: String {
        selectedViewMode == .week ? "Previous Week" : "Previous Month"
    }

    private var currentButtonTitle: String {
        selectedViewMode == .week ? "This Week" : "This Month"
    }

    private var nextButtonTitle: String {
        selectedViewMode == .week ? "Next Week" : "Next Month"
    }

    private var visibleRangeText: String {
        switch selectedViewMode {
        case .week:
            return weekRangeText

        case .month:
            return monthRangeText
        }
    }

    // MARK: - Week Grid

    private var weekGrid: some View {
        GeometryReader { geometry in
            let dayColumnWidth = max((geometry.size.width - timeColumnWidth) / 7, 124)
            let gridWidth = timeColumnWidth + (dayColumnWidth * 7)
            let gridHeight = hourRowHeight * 24

            VStack(spacing: 0) {
                dayHeaderRow(dayColumnWidth: dayColumnWidth)

                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        weeklyGridLines(
                            width: gridWidth,
                            height: gridHeight,
                            dayColumnWidth: dayColumnWidth
                        )

                        HStack(alignment: .top, spacing: 0) {
                            hourLabelColumn

                            HStack(alignment: .top, spacing: 0) {
                                ForEach(weekDays, id: \.self) { day in
                                    dayTimeColumn(
                                        day: day,
                                        width: dayColumnWidth
                                    )
                                }
                            }
                        }
                    }
                    .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
                }
                .background(gridBackground)
            }
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private func weeklyGridLines(
        width: CGFloat,
        height: CGFloat,
        dayColumnWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: width, height: 1)
                    .offset(y: CGFloat(hour) * hourRowHeight)
            }

            ForEach(0...7, id: \.self) { column in
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: height)
                    .offset(x: timeColumnWidth + (CGFloat(column) * dayColumnWidth))
            }

            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1, height: height)
                .offset(x: timeColumnWidth)
        }
        .allowsHitTesting(false)
    }

    private func dayHeaderRow(dayColumnWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .trailing) {
                Spacer()

                Text("Time")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 8)
                    .padding(.bottom, 10)
            }
            .frame(width: timeColumnWidth, height: dayHeaderHeight)
            .background(headerBackground)

            ForEach(weekDays, id: \.self) { day in
                dayHeaderCell(day)
                    .frame(width: dayColumnWidth, height: dayHeaderHeight)
                    .background(headerBackground)
                    .overlay(verticalDivider, alignment: .leading)
            }
        }
    }

    private func dayHeaderCell(_ day: Date) -> some View {
        let count = eventOccurrences(on: day).count

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(shortWeekdayText(for: day))
                    .font(.headline)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(dayNumberText(for: day))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text(monthText(for: day))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if Calendar.current.isDateInToday(day) {
                    Text("Today")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.16))
                        )
                }

                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var hourLabelColumn: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack {
                    Spacer()

                    Text(hourLabel(for: hour))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 8)
                        .padding(.top, 5)
                }
                .frame(width: timeColumnWidth, height: hourRowHeight, alignment: .topTrailing)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.32))
    }

    private func dayTimeColumn(
        day: Date,
        width: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                hourCell(
                    day: day,
                    hour: hour
                )
                .frame(width: width, height: hourRowHeight)
            }
        }
    }

    private func hourCell(
        day: Date,
        hour: Int
    ) -> some View {
        let occurrences = eventOccurrences(on: day, hour: hour)

        return ZStack(alignment: .topLeading) {
            if occurrences.isEmpty == false {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(occurrences) { occurrence in
                        CompactScheduleEventChip(
                            occurrence: occurrence,
                            use24HourTime: appState.use24HourTime,
                            runAction: {
                                appState.runAction(occurrence.action)
                            },
                            editAction: {
                                editingOccurrence = occurrence
                            },
                            deleteAction: {
                                deletingOccurrence = occurrence
                            }
                        )
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
            }
        }
        .background(hourBackground(hour: hour))
    }

    // MARK: - Month Grid

    private var monthGrid: some View {
        GeometryReader { geometry in
            let columns = Array(
                repeating: GridItem(.flexible(), spacing: 0),
                count: 7
            )

            VStack(spacing: 0) {
                monthWeekdayHeader

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(monthCalendarDays) { calendarDay in
                        MonthDayCell(
                            calendarDay: calendarDay,
                            showCount: showEventCount(on: calendarDay.date),
                            utilityCount: utilityEventCount(on: calendarDay.date),
                            isCurrentMonth: Calendar.current.isDate(
                                calendarDay.date,
                                equalTo: visibleMonthDate,
                                toGranularity: .month
                            ),
                            isToday: Calendar.current.isDateInToday(calendarDay.date)
                        )
                        .frame(height: max((geometry.size.height - 34) / 6, 90))
                        .overlay(verticalDivider, alignment: .leading)
                        .overlay(hourDivider, alignment: .top)
                    }
                }
            }
            .background(cardBackground)
            .overlay(cardBorder)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var monthWeekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(orderedWeekdayNumbers, id: \.self) { weekday in
                Text(shortWeekdayName(for: weekday))
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(headerBackground)
                    .overlay(verticalDivider, alignment: .leading)
            }
        }
    }

    private var monthCalendarDays: [MonthCalendarDay] {
        let calendar = Calendar.current
        let monthStart = startOfMonth(for: visibleMonthDate)
        let firstVisibleDay = Self.startOfWeek(
            containing: monthStart,
            startingOn: appState.weekStartDay
        )

        return (0..<42).compactMap { offset in
            guard let date = calendar.date(
                byAdding: .day,
                value: offset,
                to: firstVisibleDay
            ) else {
                return nil
            }

            return MonthCalendarDay(date: date)
        }
    }

    private var orderedWeekdayNumbers: [Int] {
        let start = min(max(appState.weekStartDay, 1), 7)
        return (0..<7).map { offset in
            ((start - 1 + offset) % 7) + 1
        }
    }

    // MARK: - Delete Handling

    @ViewBuilder
    private func deleteDialogButtons(for occurrence: ScheduleOccurrence) -> some View {
        if occurrence.event.repeatsDaily {
            Button("Delete This Occurrence", role: .destructive) {
                deleteSingleOccurrence(occurrence)
                deletingOccurrence = nil
            }

            Button("Delete Entire Series", role: .destructive) {
                deleteEntireEventSeries(occurrence)
                deletingOccurrence = nil
            }
        } else {
            Button("Delete Event", role: .destructive) {
                deleteEntireEventSeries(occurrence)
                deletingOccurrence = nil
            }
        }

        Button("Cancel", role: .cancel) {
            deletingOccurrence = nil
        }
    }

    private func deleteDialogMessage(for occurrence: ScheduleOccurrence) -> some View {
        if occurrence.event.repeatsDaily {
            Text("This is a recurring Event. Delete only this occurrence, or delete the entire series?")
        } else {
            Text("This will permanently delete this scheduled Event.")
        }
    }

    private func deleteSingleOccurrence(_ occurrence: ScheduleOccurrence) {
        guard let index = appState.scheduleEntries.firstIndex(where: {
            $0.id == occurrence.event.id
        }) else {
            return
        }

        let occurrenceDay = Calendar.current.startOfDay(for: occurrence.occurrenceDate)

        let alreadyExcluded = appState.scheduleEntries[index].excludedOccurrenceDates.contains { excludedDate in
            Calendar.current.isDate(excludedDate, inSameDayAs: occurrenceDay)
        }

        if alreadyExcluded == false {
            appState.scheduleEntries[index].excludedOccurrenceDates.append(occurrenceDay)
        }
    }

    private func deleteEntireEventSeries(_ occurrence: ScheduleOccurrence) {
        appState.scheduleEntries.removeAll {
            $0.id == occurrence.event.id
        }
    }

    // MARK: - Occurrence Calculation

    private func eventOccurrences(on day: Date) -> [ScheduleOccurrence] {
        let now = Date()
        let nextID = nextOccurrenceID(now: now)

        let occurrences = appState.scheduleEntries.compactMap { event -> ScheduleOccurrence? in
            guard eventOccurs(on: day, event: event) else {
                return nil
            }

            guard let occurrenceDate = occurrenceDate(
                on: day,
                usingTimeFrom: event.startDate
            ) else {
                return nil
            }

            guard let action = appState.actionDefinitions.first(where: {
                $0.id == event.actionDefinitionID
            }) else {
                return nil
            }

            var occurrence = ScheduleOccurrence(
                event: event,
                action: action,
                occurrenceDate: occurrenceDate,
                isPast: occurrenceDate < now,
                isNext: false
            )

            occurrence.isNext = occurrence.id == nextID
            return occurrence
        }

        return occurrences.sorted {
            $0.occurrenceDate < $1.occurrenceDate
        }
    }

    private func eventOccurrences(
        on day: Date,
        hour: Int
    ) -> [ScheduleOccurrence] {
        eventOccurrences(on: day).filter { occurrence in
            Calendar.current.component(.hour, from: occurrence.occurrenceDate) == hour
        }
    }

    private func showEventCount(on day: Date) -> Int {
        eventOccurrences(on: day).filter {
            $0.action.type == .show
        }
        .count
    }

    private func utilityEventCount(on day: Date) -> Int {
        eventOccurrences(on: day).filter {
            $0.action.type == .utility
        }
        .count
    }

    private func nextOccurrenceID(now: Date) -> String? {
        let visibleDays: [Date]

        switch selectedViewMode {
        case .week:
            visibleDays = weekDays

        case .month:
            visibleDays = monthCalendarDays.map { $0.date }
        }

        let occurrences = visibleDays.flatMap { day in
            appState.scheduleEntries.compactMap { event -> ScheduleOccurrence? in
                guard event.enabled else {
                    return nil
                }

                guard eventOccurs(on: day, event: event) else {
                    return nil
                }

                guard let occurrenceDate = occurrenceDate(
                    on: day,
                    usingTimeFrom: event.startDate
                ) else {
                    return nil
                }

                guard let action = appState.actionDefinitions.first(where: {
                    $0.id == event.actionDefinitionID
                }) else {
                    return nil
                }

                return ScheduleOccurrence(
                    event: event,
                    action: action,
                    occurrenceDate: occurrenceDate,
                    isPast: occurrenceDate < now,
                    isNext: false
                )
            }
        }

        return occurrences
            .filter { $0.occurrenceDate >= now }
            .sorted { $0.occurrenceDate < $1.occurrenceDate }
            .first?
            .id
    }

    private func eventOccurs(
        on day: Date,
        event: ScheduleEntry
    ) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)

        let isExcluded = event.excludedOccurrenceDates.contains { excludedDate in
            calendar.isDate(excludedDate, inSameDayAs: day)
        }

        guard isExcluded == false else {
            return false
        }

        if event.repeatsDaily == false {
            return calendar.isDate(event.startDate, inSameDayAs: day)
        }

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

        let weekday = calendar.component(.weekday, from: day)
        return selectedWeekdays(for: event).contains(weekday)
    }

    private func selectedWeekdays(for event: ScheduleEntry) -> Set<Int> {
        event.repeatWeekdays.isEmpty ? Set(1...7) : event.repeatWeekdays
    }

    private func occurrenceDate(
        on day: Date,
        usingTimeFrom timeSource: Date
    ) -> Date? {
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

        return calendar.date(from: components)
    }

    // MARK: - Navigation / Formatting

    private func moveVisibleRange(by offset: Int) {
        switch selectedViewMode {
        case .week:
            visibleWeekStart = Calendar.current.date(
                byAdding: .day,
                value: offset * 7,
                to: visibleWeekStart
            ) ?? visibleWeekStart

        case .month:
            visibleMonthDate = Calendar.current.date(
                byAdding: .month,
                value: offset,
                to: visibleMonthDate
            ) ?? visibleMonthDate
        }
    }

    private func moveToCurrentRange() {
        switch selectedViewMode {
        case .week:
            visibleWeekStart = Self.startOfWeek(
                containing: Date(),
                startingOn: appState.weekStartDay
            )

        case .month:
            visibleMonthDate = Date()
        }
    }

    private var weekRangeText: String {
        guard let weekEnd = Calendar.current.date(
            byAdding: .day,
            value: 6,
            to: visibleWeekStart
        ) else {
            return ""
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"

        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"

        return "\(dateFormatter.string(from: visibleWeekStart)) – \(dateFormatter.string(from: weekEnd)), \(yearFormatter.string(from: weekEnd))"
    }

    private var monthRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: visibleMonthDate)
    }

    private func hourLabel(for hour: Int) -> String {
        if appState.use24HourTime {
            return String(format: "%02d:00", hour)
        }

        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let suffix = hour < 12 ? "AM" : "PM"

        return "\(displayHour) \(suffix)"
    }

    private func shortWeekdayText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func shortWeekdayName(for weekday: Int) -> String {
        switch weekday {
        case 1: return "Sun"
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "?"
        }
    }

    private func dayNumberText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func monthText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)

        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private static func startOfWeek(
        containing date: Date,
        startingOn weekStartDay: Int
    ) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let currentWeekday = calendar.component(.weekday, from: startOfDay)

        let normalizedStartDay = min(max(weekStartDay, 1), 7)
        let daysToSubtract = (currentWeekday - normalizedStartDay + 7) % 7

        return calendar.date(
            byAdding: .day,
            value: -daysToSubtract,
            to: startOfDay
        ) ?? startOfDay
    }

    // MARK: - Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    }

    private var headerBackground: some View {
        Color(nsColor: .controlBackgroundColor).opacity(0.58)
    }

    private var gridBackground: some View {
        Color(nsColor: .textBackgroundColor).opacity(0.08)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
    }

    private var hourDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(height: 1)
    }

    private func hourBackground(hour: Int) -> some View {
        let opacity = hour % 2 == 0 ? 0.04 : 0.02
        return Color.white.opacity(opacity)
    }
}

// MARK: - Compact Event Chip

private struct CompactScheduleEventChip: View {
    let occurrence: ScheduleOccurrence
    let use24HourTime: Bool
    let runAction: () -> Void
    let editAction: () -> Void
    let deleteAction: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(timeText(for: occurrence.occurrenceDate))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(occurrence.isPast ? .secondary : .primary)
                .layoutPriority(1)

            Text(occurrence.action.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(occurrence.isPast ? .secondary : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(2)

            Spacer(minLength: 2)

            if occurrence.isNext {
                compactPill(title: "Next", color: .blue)
            } else {
                compactPill(title: occurrence.action.type.rawValue, color: actionColor)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, minHeight: 22, maxHeight: 24)
        .background(chipBackground)
        .overlay(chipBorder)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .opacity(occurrence.event.enabled ? 1.0 : 0.55)
        .help(helpText)
        .onTapGesture(count: 2) {
            editAction()
        }
        .contextMenu {
            Button {
                runAction()
            } label: {
                Label("Run Event Action", systemImage: "play.fill")
            }

            Button {
                editAction()
            } label: {
                Label("Edit Event", systemImage: "pencil")
            }

            Divider()

            Button(role: .destructive) {
                deleteAction()
            } label: {
                Label("Delete Event", systemImage: "trash")
            }
        }
    }

    private var helpText: String {
        "\(timeText(for: occurrence.occurrenceDate)) — \(occurrence.action.name)"
    }

    private var actionColor: Color {
        switch occurrence.action.type {
        case .show:
            return .blue

        case .utility:
            return .purple
        }
    }

    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(actionColor.opacity(occurrence.isPast ? 0.08 : 0.18))
    }

    private var chipBorder: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(
                occurrence.isNext ? Color.blue.opacity(0.72) : actionColor.opacity(0.30),
                lineWidth: occurrence.isNext ? 1.5 : 1
            )
    }

    private func compactPill(
        title: String,
        color: Color
    ) -> some View {
        Text(title)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
    }

    private func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourTime ? "HH:mm:ss" : "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Month Day Cell

private struct MonthDayCell: View {
    let calendarDay: MonthCalendarDay
    let showCount: Int
    let utilityCount: Int
    let isCurrentMonth: Bool
    let isToday: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(dayNumberText)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(isCurrentMonth ? .primary : .secondary)

                if isToday {
                    Text("Today")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.16))
                        )
                }

                Spacer()
            }

            if showCount > 0 {
                countPill(
                    count: showCount,
                    singular: "Show Event",
                    plural: "Show Events",
                    color: .blue
                )
            }

            if utilityCount > 0 {
                countPill(
                    count: utilityCount,
                    singular: "Utility Event",
                    plural: "Utility Events",
                    color: .purple
                )
            }

            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            Color.white.opacity(isToday ? 0.055 : 0.02)
        )
        .opacity(isCurrentMonth ? 1.0 : 0.46)
    }

    private var dayNumberText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: calendarDay.date)
    }

    private func countPill(
        count: Int,
        singular: String,
        plural: String,
        color: Color
    ) -> some View {
        Text("\(count) \(count == 1 ? singular : plural)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color.opacity(0.14))
            )
    }
}

// MARK: - Edit Sheet

private struct ScheduleEventEditSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let occurrence: ScheduleOccurrence

    @State private var selectedActionID: UUID?
    @State private var selectedDate: Date
    @State private var hour: Int
    @State private var minute: Int
    @State private var second: Int
    @State private var repeatsDaily: Bool
    @State private var repeatWeekdays: Set<Int>
    @State private var repeatUntil: Date
    @State private var editScope: ScheduleEditScope

    init(occurrence: ScheduleOccurrence) {
        self.occurrence = occurrence

        let components = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: occurrence.occurrenceDate
        )

        _selectedActionID = State(initialValue: occurrence.event.actionDefinitionID)
        _selectedDate = State(initialValue: occurrence.occurrenceDate)
        _hour = State(initialValue: components.hour ?? 0)
        _minute = State(initialValue: components.minute ?? 0)
        _second = State(initialValue: components.second ?? 0)
        _repeatsDaily = State(initialValue: occurrence.event.repeatsDaily)
        _repeatWeekdays = State(
            initialValue: occurrence.event.repeatWeekdays.isEmpty
                ? Set(1...7)
                : occurrence.event.repeatWeekdays
        )
        _repeatUntil = State(initialValue: occurrence.event.repeatUntil ?? occurrence.occurrenceDate)
        _editScope = State(initialValue: occurrence.event.repeatsDaily ? .thisOccurrence : .entireSeries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if occurrence.event.repeatsDaily {
                scopePicker
            }

            actionPicker
            dateTimeSection

            if editScope == .entireSeries {
                repeatSection
            }

            footer
        }
        .padding(20)
        .frame(width: 560, height: editScope == .entireSeries ? 620 : 460)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Edit Event")
                .font(.largeTitle)
                .bold()

            Text(headerSubtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var headerSubtitle: String {
        occurrence.event.repeatsDaily
            ? "Edit this occurrence or the entire recurring series."
            : "Edit this scheduled Event."
    }

    private var scopePicker: some View {
        Picker("Edit Scope", selection: $editScope) {
            ForEach(ScheduleEditScope.allCases) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .pickerStyle(.segmented)
    }

    private var actionPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Action")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Action", selection: $selectedActionID) {
                ForEach(sortedActions) { action in
                    Text("\(action.name) — \(action.type.rawValue)")
                        .tag(Optional(action.id))
                }
            }
            .labelsHidden()
        }
    }

    private var sortedActions: [ActionDefinition] {
        appState.actionDefinitions.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            DatePicker(
                "Date",
                selection: $selectedDate,
                displayedComponents: [.date]
            )

            HStack {
                integerField("Hour", value: $hour, range: 0...23)
                integerField("Minute", value: $minute, range: 0...59)
                integerField("Second", value: $second, range: 0...59)

                Spacer()
            }
        }
    }

    private func integerField(
        _ label: String,
        value: Binding<Int>,
        range: ClosedRange<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                label,
                value: value,
                format: .number.grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 90)
            .onChange(of: value.wrappedValue) { _, newValue in
                value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
            }
        }
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle("Repeat", isOn: $repeatsDaily)

            if repeatsDaily {
                weekdayGrid

                DatePicker(
                    "Repeat Until",
                    selection: $repeatUntil,
                    displayedComponents: [.date]
                )
            }
        }
    }

    private var weekdayGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
            spacing: 8
        ) {
            ForEach(WeekdayEditOption.allCases) { weekday in
                weekdayButton(weekday)
            }
        }
    }

    private func weekdayButton(_ weekday: WeekdayEditOption) -> some View {
        let isSelected = repeatWeekdays.contains(weekday.rawValue)

        return Button {
            if isSelected {
                repeatWeekdays.remove(weekday.rawValue)
            } else {
                repeatWeekdays.insert(weekday.rawValue)
            }
        } label: {
            Text(weekday.shortName)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .blue : .secondary)
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Spacer()

            Button("Save") {
                saveChanges()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedActionID == nil)
        }
    }

    private func saveChanges() {
        guard let selectedActionID else {
            return
        }

        guard let index = appState.scheduleEntries.firstIndex(where: {
            $0.id == occurrence.event.id
        }) else {
            dismiss()
            return
        }

        let newStartDate = composedDate()

        if occurrence.event.repeatsDaily && editScope == .thisOccurrence {
            saveSingleOccurrenceEdit(
                originalIndex: index,
                selectedActionID: selectedActionID,
                newStartDate: newStartDate
            )
        } else {
            saveSeriesEdit(
                index: index,
                selectedActionID: selectedActionID,
                newStartDate: newStartDate
            )
        }

        dismiss()
    }

    private func saveSingleOccurrenceEdit(
        originalIndex: Int,
        selectedActionID: UUID,
        newStartDate: Date
    ) {
        let occurrenceDay = Calendar.current.startOfDay(for: occurrence.occurrenceDate)

        appState.scheduleEntries[originalIndex].excludedOccurrenceDates.append(occurrenceDay)

        let oneTimeEvent = ScheduleEntry(
            actionDefinitionID: selectedActionID,
            startDate: newStartDate,
            enabled: true,
            repeatsDaily: false
        )

        appState.scheduleEntries.append(oneTimeEvent)
    }

    private func saveSeriesEdit(
        index: Int,
        selectedActionID: UUID,
        newStartDate: Date
    ) {
        appState.scheduleEntries[index].actionDefinitionID = selectedActionID
        appState.scheduleEntries[index].startDate = newStartDate
        appState.scheduleEntries[index].repeatsDaily = repeatsDaily
        appState.scheduleEntries[index].repeatWeekdays = repeatsDaily ? repeatWeekdays : []
        appState.scheduleEntries[index].repeatUntil = repeatsDaily ? endOfDay(for: repeatUntil) : nil
    }

    private func composedDate() -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: selectedDate
        )

        var components = DateComponents()
        components.year = dateComponents.year
        components.month = dateComponents.month
        components.day = dateComponents.day
        components.hour = hour
        components.minute = minute
        components.second = second

        return calendar.date(from: components) ?? selectedDate
    }

    private func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        return calendar.date(
            byAdding: DateComponents(day: 1, second: -1),
            to: startOfDay
        ) ?? date
    }
}

// MARK: - Models

private enum ScheduleViewMode: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"

    var id: String {
        rawValue
    }
}

private struct ScheduleOccurrence: Identifiable {
    let event: ScheduleEntry
    let action: ActionDefinition
    let occurrenceDate: Date
    let isPast: Bool
    var isNext: Bool

    var id: String {
        "\(event.id.uuidString)-\(Int(occurrenceDate.timeIntervalSince1970))"
    }
}

private struct MonthCalendarDay: Identifiable {
    let date: Date

    var id: TimeInterval {
        Calendar.current.startOfDay(for: date).timeIntervalSince1970
    }
}

private enum ScheduleEditScope: String, CaseIterable, Identifiable {
    case thisOccurrence = "This Occurrence Only"
    case entireSeries = "Entire Series"

    var id: String {
        rawValue
    }
}

private enum WeekdayEditOption: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int {
        rawValue
    }

    var shortName: String {
        switch self {
        case .sunday:
            return "Sun"
        case .monday:
            return "Mon"
        case .tuesday:
            return "Tue"
        case .wednesday:
            return "Wed"
        case .thursday:
            return "Thu"
        case .friday:
            return "Fri"
        case .saturday:
            return "Sat"
        }
    }
}
