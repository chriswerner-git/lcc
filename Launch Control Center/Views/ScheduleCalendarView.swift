//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduleCalendarView.swift
//  Purpose: Schedule calendar and list interface for viewing, editing,
//           auditing, and managing scheduled Events.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  Notes:
//  - Supports Calendar and List presentations.
//  - Supports day, week, and month schedule ranges.
//  - Scheduled Events trigger saved ActionDefinition records.
//  - Repeating Events may include selected weekdays, repeat-until dates,
//    and excluded occurrences.
//  - Week start behavior follows the app preference in AppState.
//

import SwiftUI

struct ScheduleCalendarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    @AppStorage("scheduleHourRowHeight") private var storedHourRowHeight: Double = 92

    @State private var selectedPresentationMode: SchedulePresentationMode = .calendar
    @State private var selectedRangeMode: ScheduleRangeMode = .week

    @State private var visibleDayDate: Date = Date()
    @State private var visibleWeekStart: Date = ScheduleCalendarView.startOfWeek(
        containing: Date(),
        startingOn: 1
    )
    @State private var visibleMonthDate: Date = Date()

    @State private var editingRequest: ScheduleEditRequest?
    @State private var editOccurrenceConfirmation: ScheduleOccurrence?
    @State private var deletingOccurrence: ScheduleOccurrence?
    @State private var filteredSeriesID: UUID?

    private let timeColumnWidth: CGFloat = 62
    private let dayHeaderHeight: CGFloat = 74

    private var hourRowHeight: CGFloat {
        CGFloat(storedHourRowHeight)
    }

    private var availableRangeModes: [ScheduleRangeMode] {
        switch selectedPresentationMode {
        case .calendar:
            return [.day, .week, .month]

        case .list:
            return [.day, .month]
        }
    }

    private var weekDays: [Date] {
        days(
            startingAt: visibleWeekStart,
            count: 7
        )
    }

    private var visibleCalendarDays: [Date] {
        switch selectedRangeMode {
        case .day:
            return [Calendar.current.startOfDay(for: visibleDayDate)]

        case .week:
            return weekDays

        case .month:
            return monthCalendarDays.map { $0.date }
        }
    }

    private var visibleListDays: [Date] {
        switch selectedRangeMode {
        case .day:
            return [Calendar.current.startOfDay(for: visibleDayDate)]

        case .week:
            // List View no longer exposes Week as a selectable range.
            // Keep this fallback so a previously selected Week range degrades safely.
            return [Calendar.current.startOfDay(for: visibleDayDate)]

        case .month:
            return actualMonthDays
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

    private var editOccurrenceDialogIsPresented: Binding<Bool> {
        Binding(
            get: {
                editOccurrenceConfirmation != nil
            },
            set: { newValue in
                if newValue == false {
                    editOccurrenceConfirmation = nil
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
                seriesFilterBanner

                switch selectedPresentationMode {
                case .calendar:
                    calendarContent

                case .list:
                    scheduleList
                }
            }
            .padding(20)
        }
        .frame(minWidth: 1220, minHeight: 780)
        .onAppear {
            let now = Date()
            visibleDayDate = now
            visibleWeekStart = Self.startOfWeek(
                containing: now,
                startingOn: appState.weekStartDay
            )
            visibleMonthDate = now
            normalizeRangeForCurrentPresentation()
        }
        .onChange(of: selectedPresentationMode) { _, _ in
            normalizeRangeForCurrentPresentation()
        }
        .onChange(of: appState.weekStartDay) { _, newValue in
            visibleWeekStart = Self.startOfWeek(
                containing: visibleWeekStart,
                startingOn: newValue
            )
        }
        .sheet(item: $editingRequest) { request in
            ScheduleEventEditSheet(
                occurrence: request.occurrence,
                initialScope: request.initialScope
            )
            .environmentObject(appState)
        }
        .confirmationDialog(
            "Edit This Occurrence",
            isPresented: editOccurrenceDialogIsPresented,
            titleVisibility: .visible
        ) {
            if let occurrence = editOccurrenceConfirmation {
                Button("Create Standalone Event") {
                    editingRequest = ScheduleEditRequest(
                        occurrence: occurrence,
                        initialScope: .thisOccurrence
                    )
                    editOccurrenceConfirmation = nil
                }
            }

            Button("Cancel", role: .cancel) {
                editOccurrenceConfirmation = nil
            }
        } message: {
            if let occurrence = editOccurrenceConfirmation {
                Text(editThisOccurrenceWarningText(for: occurrence))
            } else {
                Text("No Event selected.")
            }
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

                Text("Calendar and list views for auditing and managing scheduled Events.")
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
                Picker("View", selection: $selectedPresentationMode) {
                    ForEach(SchedulePresentationMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 220)

                Picker("Range", selection: $selectedRangeMode) {
                    ForEach(availableRangeModes) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 210)

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

            HStack(spacing: 10) {
                if selectedPresentationMode == .calendar && selectedRangeMode != .month {
                    Text("Hour Height")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Slider(value: $storedHourRowHeight, in: 58...150)
                        .frame(width: 220)

                    Text("\(Int(storedHourRowHeight))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }

                Text("Right-click Events for Run, Edit, Delete. Double-click to edit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private var seriesFilterBanner: some View {
        if let filteredSeriesID {
            HStack(spacing: 10) {
                Label(seriesFilterTitle(for: filteredSeriesID), systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .lineLimit(1)

                Spacer()

                Button {
                    self.filteredSeriesID = nil
                } label: {
                    Label("Clear Series Filter", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.blue.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.blue.opacity(0.24), lineWidth: 1)
            )
        }
    }

    private var previousButtonTitle: String {
        "Previous \(selectedRangeMode.rawValue)"
    }

    private var currentButtonTitle: String {
        switch selectedRangeMode {
        case .day:
            return "Today"

        case .week:
            return "This Week"

        case .month:
            return "This Month"
        }
    }

    private var nextButtonTitle: String {
        "Next \(selectedRangeMode.rawValue)"
    }

    private var visibleRangeText: String {
        switch selectedRangeMode {
        case .day:
            return Self.fullDateFormatter.string(from: visibleDayDate)

        case .week:
            return weekRangeText

        case .month:
            return monthRangeText
        }
    }

    // MARK: - Calendar Content

    @ViewBuilder
    private var calendarContent: some View {
        switch selectedRangeMode {
        case .day:
            timeGrid(days: [Calendar.current.startOfDay(for: visibleDayDate)])

        case .week:
            timeGrid(days: weekDays)

        case .month:
            monthGrid
        }
    }

    // MARK: - Time Grid

    private func timeGrid(days: [Date]) -> some View {
        GeometryReader { geometry in
            let columnCount = max(days.count, 1)
            let dayColumnWidth = max((geometry.size.width - timeColumnWidth) / CGFloat(columnCount), 124)
            let gridWidth = timeColumnWidth + (dayColumnWidth * CGFloat(columnCount))
            let gridHeight = hourRowHeight * 24

            VStack(spacing: 0) {
                dayHeaderRow(
                    days: days,
                    dayColumnWidth: dayColumnWidth
                )

                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        timeGridLines(
                            width: gridWidth,
                            height: gridHeight,
                            dayColumnWidth: dayColumnWidth,
                            dayCount: columnCount
                        )

                        HStack(alignment: .top, spacing: 0) {
                            hourLabelColumn

                            HStack(alignment: .top, spacing: 0) {
                                ForEach(days, id: \.self) { day in
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

    private func timeGridLines(
        width: CGFloat,
        height: CGFloat,
        dayColumnWidth: CGFloat,
        dayCount: Int
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0...24, id: \.self) { hour in
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: width, height: 1)
                    .offset(y: CGFloat(hour) * hourRowHeight)
            }

            ForEach(0...dayCount, id: \.self) { column in
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

    private func dayHeaderRow(
        days: [Date],
        dayColumnWidth: CGFloat
    ) -> some View {
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

            ForEach(days, id: \.self) { day in
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
                Text(Self.shortWeekdayFormatter.string(from: day))
                    .font(.headline)

                Spacer()

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Self.dayNumberFormatter.string(from: day))
                    .font(.system(size: 28, weight: .semibold, design: .rounded))

                Text(Self.shortMonthFormatter.string(from: day))
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
                            editAction: { scope in
                                requestEdit(occurrence, scope: scope)
                            },
                            deleteAction: {
                                deletingOccurrence = occurrence
                            },
                            showSeriesAction: {
                                showOnlySeries(for: occurrence)
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

    // MARK: - List View

    private var scheduleList: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(scheduleListGroups) { group in
                    ScheduleListDaySection(
                        group: group,
                        use24HourTime: appState.use24HourTime,
                        runAction: { occurrence in
                            appState.runAction(occurrence.action)
                        },
                        editAction: { occurrence, scope in
                            requestEdit(occurrence, scope: scope)
                        },
                        deleteAction: { occurrence in
                            deletingOccurrence = occurrence
                        },
                        showSeriesAction: { occurrence in
                            showOnlySeries(for: occurrence)
                        }
                    )
                }
            }
            .padding(14)
        }
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var scheduleListGroups: [ScheduleListDayGroup] {
        visibleListDays.map { day in
            ScheduleListDayGroup(
                date: day,
                occurrences: eventOccurrences(on: day)
            )
        }
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
                            showHasDisabledOrOffEvent: showHasDisabledOrOffEvent(on: calendarDay.date),
                            utilityHasDisabledOrOffEvent: utilityHasDisabledOrOffEvent(on: calendarDay.date),
                            showActionsEnabled: appState.showActionsEnabled,
                            utilityActionsEnabled: appState.utilityActionsEnabled,
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
                Text(ScheduleEntryFormatter.shortWeekdayName(for: weekday))
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
        let monthStart = startOfMonth(for: visibleMonthDate)
        let firstVisibleDay = Self.startOfWeek(
            containing: monthStart,
            startingOn: appState.weekStartDay
        )

        return days(startingAt: firstVisibleDay, count: 42).map { date in
            MonthCalendarDay(date: date)
        }
    }

    private var actualMonthDays: [Date] {
        let calendar = Calendar.current
        let monthStart = startOfMonth(for: visibleMonthDate)
        let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<1

        return range.compactMap { dayNumber in
            calendar.date(
                byAdding: .day,
                value: dayNumber - 1,
                to: monthStart
            )
        }
    }

    private var orderedWeekdayNumbers: [Int] {
        let start = min(max(appState.weekStartDay, 1), 7)
        return (0..<7).map { offset in
            ((start - 1 + offset) % 7) + 1
        }
    }

    // MARK: - Edit Handling

    private func requestEdit(
        _ occurrence: ScheduleOccurrence,
        scope: ScheduleEditScope
    ) {
        if occurrence.event.repeatsDaily && scope == .thisOccurrence {
            editOccurrenceConfirmation = occurrence
            return
        }

        editingRequest = ScheduleEditRequest(
            occurrence: occurrence,
            initialScope: scope
        )
    }

    private func editThisOccurrenceWarningText(for occurrence: ScheduleOccurrence) -> String {
        let occurrenceText = Self.fullDateTimeFormatter.string(from: occurrence.occurrenceDate)
        let seriesText = cleanedSeriesName(for: occurrence.event) ?? "Unnamed Series"
        let frequencyText = ScheduleEntryFormatter.repeatSummary(
            for: occurrence.event,
            oneTimeText: "One time",
            includeRepeatUntil: true
        )

        return """
        This will remove the selected Event instance from the recurring series and create a new standalone Event using the same date, time, and Action. You can then edit it independently.

        Occurrence: \(occurrenceText)
        Series: \(seriesText)
        Action: \(occurrence.action.name)
        Frequency: \(frequencyText)

        The rest of the series will remain scheduled.
        """
    }

    // MARK: - Delete Handling

    @ViewBuilder
    private func deleteDialogButtons(for occurrence: ScheduleOccurrence) -> some View {
        if occurrence.event.repeatsDaily {
            Button("Delete This Occurrence", role: .destructive) {
                deleteSingleOccurrence(occurrence)
                deletingOccurrence = nil
            }

            Button(seriesDeleteButtonTitle(for: occurrence), role: .destructive) {
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
            Text(seriesDeleteWarningText(for: occurrence))
        } else {
            Text("This will permanently delete this scheduled Event. This cannot be undone.")
        }
    }

    private func seriesDeleteButtonTitle(for occurrence: ScheduleOccurrence) -> String {
        guard let countText = seriesInstanceCountText(for: occurrence.event) else {
            return "Delete Entire Series"
        }

        return "Delete Entire Series (\(countText))"
    }

    private func seriesDeleteWarningText(for occurrence: ScheduleOccurrence) -> String {
        let event = occurrence.event
        let selectedOccurrenceText = Self.fullDateTimeFormatter.string(from: occurrence.occurrenceDate)
        let seriesNameText = cleanedSeriesName(for: event) ?? "Unnamed Series"
        let frequencyText = ScheduleEntryFormatter.repeatSummary(
            for: event,
            oneTimeText: "One time",
            includeRepeatUntil: false
        )
        let endText = seriesEndSummaryText(for: event)
        let instanceText = seriesInstanceWarningText(for: event)

        return """
        Selected occurrence: \(selectedOccurrenceText)

        Choose “Delete This Occurrence” to permanently remove only this generated Event instance. The rest of the series will remain scheduled. This cannot be undone.

        Choose “Delete Entire Series” to permanently delete the full recurring Event series. This cannot be undone.

        Series: \(seriesNameText)
        Action: \(occurrence.action.name)
        Frequency: \(frequencyText)
        End: \(endText)
        Instances: \(instanceText)
        """
    }

    private func seriesInstanceWarningText(for event: ScheduleEntry) -> String {
        if let countText = seriesInstanceCountText(for: event) {
            return "This will delete \(countText)."
        }

        return "This series has no end date, so the total number of future generated instances cannot be counted. Deleting the series removes all of its generated instances."
    }

    private func seriesInstanceCountText(for event: ScheduleEntry) -> String? {
        guard event.repeatsDaily else {
            return "1 Event"
        }

        guard let endDay = seriesEndDay(for: event) else {
            return nil
        }

        let calendar = Calendar.current
        var currentDay = calendar.startOfDay(for: event.startDate)
        let finalDay = calendar.startOfDay(for: endDay)
        var count = 0
        var guardCount = 0

        while currentDay <= finalDay, guardCount < 3_700 {
            count += ScheduleEntryFormatter.occurrenceDates(
                for: event,
                on: currentDay,
                calendar: calendar
            ).count

            guard let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: currentDay
            ) else {
                break
            }

            currentDay = nextDay
            guardCount += 1
        }

        if guardCount >= 3_700, currentDay <= finalDay {
            return "more than \(count) Events"
        }

        return "\(count) \(count == 1 ? "Event" : "Events")"
    }

    private func seriesEndSummaryText(for event: ScheduleEntry) -> String {
        guard let endDay = seriesEndDay(for: event) else {
            if event.repeatMode == .intervalDuringDay, let intervalEndTime = event.intervalEndTime {
                return "No end date. Daily interval ends at \(Self.timeOnlyFormatter.string(from: intervalEndTime)) when it runs."
            }

            return "No end date."
        }

        let calendar = Calendar.current
        let timeSource: Date

        switch event.repeatMode {
        case .oncePerSelectedDay:
            timeSource = event.startDate

        case .intervalDuringDay:
            timeSource = event.intervalEndTime ?? event.startDate
        }

        let endDateTime = ScheduleEntryFormatter.date(
            on: endDay,
            usingTimeFrom: timeSource,
            calendar: calendar
        ) ?? endDay

        if event.repeatMode == .intervalDuringDay {
            return "\(Self.fullDateTimeFormatter.string(from: endDateTime)). End time is inclusive when it lands exactly on the interval."
        }

        return Self.fullDateTimeFormatter.string(from: endDateTime)
    }

    private func seriesEndDay(for event: ScheduleEntry) -> Date? {
        event.seriesEndDate ?? event.repeatUntil
    }

    private func cleanedSeriesName(for event: ScheduleEntry) -> String? {
        let trimmed = event.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func deleteSingleOccurrence(_ occurrence: ScheduleOccurrence) {
        guard let index = appState.scheduleEntries.firstIndex(where: {
            $0.id == occurrence.event.id
        }) else {
            return
        }

        if occurrence.event.repeatMode == .intervalDuringDay {
            let occurrenceKey = ScheduleEntryFormatter.occurrenceKey(
                eventID: occurrence.event.id,
                occurrenceDate: occurrence.occurrenceDate
            )

            if appState.scheduleEntries[index].excludedOccurrenceKeys.contains(occurrenceKey) == false {
                appState.scheduleEntries[index].excludedOccurrenceKeys.append(occurrenceKey)
            }
        } else {
            let occurrenceDay = Calendar.current.startOfDay(for: occurrence.occurrenceDate)

            let alreadyExcluded = appState.scheduleEntries[index].excludedOccurrenceDates.contains { excludedDate in
                Calendar.current.isDate(excludedDate, inSameDayAs: occurrenceDay)
            }

            if alreadyExcluded == false {
                appState.scheduleEntries[index].excludedOccurrenceDates.append(occurrenceDay)
            }
        }
    }

    private func deleteEntireEventSeries(_ occurrence: ScheduleOccurrence) {
        let removedSeriesID = seriesFilterIdentifier(for: occurrence.event)

        appState.scheduleEntries.removeAll {
            $0.id == occurrence.event.id
        }

        if filteredSeriesID == removedSeriesID {
            filteredSeriesID = nil
        }
    }

    private func showOnlySeries(for occurrence: ScheduleOccurrence) {
        filteredSeriesID = seriesFilterIdentifier(for: occurrence.event)
    }

    private func seriesMatchesFilter(_ event: ScheduleEntry) -> Bool {
        guard let filteredSeriesID else {
            return true
        }

        return seriesFilterIdentifier(for: event) == filteredSeriesID
    }

    private func seriesFilterIdentifier(for event: ScheduleEntry) -> UUID? {
        guard event.repeatsDaily else {
            return nil
        }

        return event.seriesID ?? event.id
    }

    private func seriesFilterTitle(for seriesID: UUID) -> String {
        guard let event = appState.scheduleEntries.first(where: {
            seriesFilterIdentifier(for: $0) == seriesID
        }) else {
            return "Filtering one recurring series"
        }

        let actionName = appState.actionDefinitions.first(where: {
            $0.id == event.actionDefinitionID
        })?.name ?? "Missing Action"

        let trimmedSeriesName = event.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayName = trimmedSeriesName.isEmpty ? actionName : trimmedSeriesName
        let summary = ScheduleEntryFormatter.repeatSummary(
            for: event,
            oneTimeText: "One time",
            includeRepeatUntil: true
        )

        return "Showing series: \(displayName) — \(summary)"
    }

    // MARK: - Occurrence Calculation

    private func eventOccurrences(on day: Date) -> [ScheduleOccurrence] {
        let now = Date()
        let nextID = nextOccurrenceID(now: now)

        let occurrences = appState.scheduleEntries.flatMap { event -> [ScheduleOccurrence] in
            guard seriesMatchesFilter(event) else {
                return []
            }

            let occurrenceDates = ScheduleEntryFormatter.occurrenceDates(
                for: event,
                on: day
            )

            guard occurrenceDates.isEmpty == false else {
                return []
            }

            guard let action = appState.actionDefinitions.first(where: {
                $0.id == event.actionDefinitionID
            }) else {
                return []
            }

            return occurrenceDates.map { occurrenceDate in
                var occurrence = ScheduleOccurrence(
                    event: event,
                    action: action,
                    occurrenceDate: occurrenceDate,
                    isPast: occurrenceDate < now,
                    scheduleCategoryEnabled: scheduleCategoryIsEnabled(for: action),
                    executionRecord: appState.scheduleExecutionRecord(
                        for: event.id,
                        occurrenceDate: occurrenceDate
                    ),
                    isNext: false
                )

                occurrence.isNext = occurrence.id == nextID
                return occurrence
            }
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

    private func showHasDisabledOrOffEvent(on day: Date) -> Bool {
        eventOccurrences(on: day).contains { occurrence in
            occurrence.action.type == .show && occurrence.isEffectivelyScheduled == false
        }
    }

    private func utilityHasDisabledOrOffEvent(on day: Date) -> Bool {
        eventOccurrences(on: day).contains { occurrence in
            occurrence.action.type == .utility && occurrence.isEffectivelyScheduled == false
        }
    }

    private func nextOccurrenceID(now: Date) -> String? {
        let occurrences = visibleCalendarDays.flatMap { day in
            appState.scheduleEntries.flatMap { event -> [ScheduleOccurrence] in
                guard seriesMatchesFilter(event) else {
                    return []
                }

                guard event.enabled else {
                    return []
                }

                let occurrenceDates = ScheduleEntryFormatter.occurrenceDates(
                    for: event,
                    on: day
                )

                guard occurrenceDates.isEmpty == false else {
                    return []
                }

                guard let action = appState.actionDefinitions.first(where: {
                    $0.id == event.actionDefinitionID
                }) else {
                    return []
                }

                guard scheduleCategoryIsEnabled(for: action) else {
                    return []
                }

                return occurrenceDates.map { occurrenceDate in
                    ScheduleOccurrence(
                        event: event,
                        action: action,
                        occurrenceDate: occurrenceDate,
                        isPast: occurrenceDate < now,
                        scheduleCategoryEnabled: true,
                        executionRecord: appState.scheduleExecutionRecord(
                            for: event.id,
                            occurrenceDate: occurrenceDate
                        ),
                        isNext: false
                    )
                }
            }
        }

        return occurrences
            .filter { $0.occurrenceDate >= now }
            .sorted { $0.occurrenceDate < $1.occurrenceDate }
            .first?
            .id
    }

    private func scheduleCategoryIsEnabled(for action: ActionDefinition) -> Bool {
        switch action.type {
        case .show:
            return appState.showActionsEnabled

        case .utility:
            return appState.utilityActionsEnabled
        }
    }

    // MARK: - Navigation / Formatting

    private func normalizeRangeForCurrentPresentation() {
        guard availableRangeModes.contains(selectedRangeMode) == false else {
            return
        }

        selectedRangeMode = .day
    }

    private func moveVisibleRange(by offset: Int) {
        switch selectedRangeMode {
        case .day:
            visibleDayDate = Calendar.current.date(
                byAdding: .day,
                value: offset,
                to: visibleDayDate
            ) ?? visibleDayDate

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
        let now = Date()

        switch selectedRangeMode {
        case .day:
            visibleDayDate = now

        case .week:
            visibleWeekStart = Self.startOfWeek(
                containing: now,
                startingOn: appState.weekStartDay
            )

        case .month:
            visibleMonthDate = now
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

        return "\(Self.mediumDateFormatter.string(from: visibleWeekStart)) – \(Self.mediumDateFormatter.string(from: weekEnd)), \(Self.yearFormatter.string(from: weekEnd))"
    }

    private var monthRangeText: String {
        Self.monthYearFormatter.string(from: visibleMonthDate)
    }

    private func hourLabel(for hour: Int) -> String {
        if appState.use24HourTime {
            return String(format: "%02d:00", hour)
        }

        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        let suffix = hour < 12 ? "AM" : "PM"

        return "\(displayHour) \(suffix)"
    }

    private func days(
        startingAt startDate: Date,
        count: Int
    ) -> [Date] {
        (0..<count).compactMap { offset in
            Calendar.current.date(
                byAdding: .day,
                value: offset,
                to: Calendar.current.startOfDay(for: startDate)
            )
        }
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

    // MARK: - Static Formatters

    private static let shortWeekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()

    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter
    }()

    private static let fullDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

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

// MARK: - Schedule List

private struct ScheduleListDaySection: View {
    let group: ScheduleListDayGroup
    let use24HourTime: Bool
    let runAction: (ScheduleOccurrence) -> Void
    let editAction: (ScheduleOccurrence, ScheduleEditScope) -> Void
    let deleteAction: (ScheduleOccurrence) -> Void
    let showSeriesAction: (ScheduleOccurrence) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayTitle)
                        .font(.headline)

                    Text(daySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(countText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.07))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.44))

            if group.occurrences.isEmpty {
                Text("No scheduled Events.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)
                    .background(Color.white.opacity(0.018))
            } else {
                VStack(spacing: 0) {
                    ForEach(group.occurrences) { occurrence in
                        ScheduleListOccurrenceRow(
                            occurrence: occurrence,
                            use24HourTime: use24HourTime,
                            runAction: {
                                runAction(occurrence)
                            },
                            editAction: { scope in
                                editAction(occurrence, scope)
                            },
                            deleteAction: {
                                deleteAction(occurrence)
                            },
                            showSeriesAction: {
                                showSeriesAction(occurrence)
                            }
                        )

                        if occurrence.id != group.occurrences.last?.id {
                            Divider()
                                .opacity(0.28)
                        }
                    }
                }
                .background(Color.white.opacity(0.018))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var dayTitle: String {
        Self.dayTitleFormatter.string(from: group.date)
    }

    private var daySubtitle: String {
        if Calendar.current.isDateInToday(group.date) {
            return "Today"
        }

        return Self.daySubtitleFormatter.string(from: group.date)
    }

    private var countText: String {
        let count = group.occurrences.count
        return "\(count) \(count == 1 ? "Event" : "Events")"
    }

    private static let dayTitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    private static let daySubtitleFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }()
}

private struct ScheduleListOccurrenceRow: View {
    let occurrence: ScheduleOccurrence
    let use24HourTime: Bool
    let runAction: () -> Void
    let editAction: (ScheduleEditScope) -> Void
    let deleteAction: () -> Void
    let showSeriesAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(timeText(for: occurrence.occurrenceDate))
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(occurrence.isPast ? .secondary : .primary)
                .frame(width: 88, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if occurrence.event.repeatsDaily {
                        Image(systemName: "rectangle.stack")
                            .font(.caption)
                            .foregroundStyle(seriesIconStyle)
                            .help(seriesHelpText)
                    }

                    Text(primaryDisplayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(primaryTextStyle)
                        .lineLimit(1)

                    if occurrence.isNext {
                        statusPill(
                            title: "Next",
                            color: .blue
                        )
                    }
                }

                HStack(spacing: 7) {
                    if hasNamedSeries {
                        Text("Action: \(occurrence.action.name)")
                            .font(.caption)
                            .foregroundStyle(secondaryTextStyle)
                            .lineLimit(1)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Text(repeatSummary)
                        .font(.caption)
                        .foregroundStyle(secondaryTextStyle)
                        .lineLimit(1)

                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(eventStatusText)
                        .font(.caption)
                        .foregroundStyle(eventStatusColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            statusPill(
                title: occurrence.action.type.rawValue,
                color: actionColor
            )

            Button {
                runAction()
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .help("Run Event Action")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .opacity(occurrence.isEffectivelyScheduled ? 1.0 : 0.58)
        .contentShape(Rectangle())
        .help(rowHelpText)
        .onTapGesture(count: 2) {
            editAction(occurrence.event.repeatsDaily ? .thisOccurrence : .entireSeries)
        }
        .contextMenu {
            Button {
                runAction()
            } label: {
                Label("Run Event Action", systemImage: "play.fill")
            }

            if occurrence.event.repeatsDaily {
                Button {
                    editAction(.thisOccurrence)
                } label: {
                    Label("Edit This Occurrence", systemImage: "pencil.and.scribble")
                }

                Button {
                    editAction(.entireSeries)
                } label: {
                    Label("Edit Entire Series", systemImage: "rectangle.stack.badge.pencil")
                }

                Button {
                    showSeriesAction()
                } label: {
                    Label("Show Only This Series", systemImage: "line.3.horizontal.decrease.circle")
                }
            } else {
                Button {
                    editAction(.entireSeries)
                } label: {
                    Label("Edit Event", systemImage: "pencil")
                }
            }

            Divider()

            Button(role: .destructive) {
                deleteAction()
            } label: {
                if occurrence.event.repeatsDaily {
                    Label("Delete…", systemImage: "trash")
                } else {
                    Label("Delete Event", systemImage: "trash")
                }
            }
        }
    }

    private var cleanedSeriesName: String? {
        let trimmed = occurrence.event.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasNamedSeries: Bool {
        cleanedSeriesName != nil
    }

    private var primaryDisplayName: String {
        cleanedSeriesName ?? occurrence.action.name
    }

    private var actionColor: Color {
        switch occurrence.action.type {
        case .show:
            return .blue

        case .utility:
            return .purple
        }
    }

    private var primaryTextStyle: AnyShapeStyle {
        occurrence.isPast ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary)
    }

    private var secondaryTextStyle: AnyShapeStyle {
        occurrence.isPast ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary)
    }

    private var seriesIconStyle: AnyShapeStyle {
        occurrence.isPast ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.blue)
    }

    private var seriesHelpText: String {
        let summary = ScheduleEntryFormatter.repeatSummary(
            for: occurrence.event,
            oneTimeText: "One time",
            includeRepeatUntil: true
        )

        if let cleanedSeriesName {
            return "Part of recurring series: \(cleanedSeriesName) • \(summary)"
        }

        return "Part of a recurring series • \(summary)"
    }
    private var rowHelpText: String {
        let baseText = "\(timeText(for: occurrence.occurrenceDate)) — \(primaryDisplayName)"
        let actionText = hasNamedSeries ? " • Action: \(occurrence.action.name)" : ""

        guard occurrence.event.repeatsDaily else {
            return "\(baseText)\(actionText)"
        }

        return "\(baseText)\(actionText) • \(seriesHelpText)"
    }


    private var eventStatusText: String {
        if occurrence.isPast {
            return pastExecutionStatusText
        }

        if occurrence.event.enabled == false {
            return "Disabled"
        }

        if occurrence.scheduleCategoryEnabled == false {
            switch occurrence.action.type {
            case .show:
                return "Show Actions Off"

            case .utility:
                return "Utility Actions Off"
            }
        }

        return "Enabled"
    }

    private var eventStatusColor: Color {
        if occurrence.isPast {
            return pastExecutionStatusColor
        }

        if occurrence.event.enabled == false || occurrence.scheduleCategoryEnabled == false {
            return .orange
        }

        return .secondary
    }

    private var pastExecutionStatusText: String {
        guard let executionRecord = occurrence.executionRecord else {
            return "No Record"
        }

        switch executionRecord.result {
        case .ran:
            return "Ran"

        case .skipped:
            return "Skipped: \(executionRecord.message)"

        case .failed:
            return "Failed"
        }
    }

    private var pastExecutionStatusColor: Color {
        guard let executionRecord = occurrence.executionRecord else {
            return .secondary
        }

        switch executionRecord.result {
        case .ran:
            return .green

        case .skipped:
            return .orange

        case .failed:
            return .red
        }
    }

    private var repeatSummary: String {
        ScheduleEntryFormatter.repeatSummary(
            for: occurrence.event,
            oneTimeText: "One time",
            includeRepeatUntil: true
        )
    }

    private func statusPill(
        title: String,
        color: Color
    ) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
    }

    private func timeText(for date: Date) -> String {
        let formatter = use24HourTime ? Self.time24Formatter : Self.time12Formatter
        return formatter.string(from: date)
    }

    private static let time24Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let time12Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }()
}

// MARK: - Compact Event Chip

private struct CompactScheduleEventChip: View {
    let occurrence: ScheduleOccurrence
    let use24HourTime: Bool
    let runAction: () -> Void
    let editAction: (ScheduleEditScope) -> Void
    let deleteAction: () -> Void
    let showSeriesAction: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Text(timeText(for: occurrence.occurrenceDate))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(eventTextStyle)
                .layoutPriority(1)

            if occurrence.event.repeatsDaily {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(eventTextStyle)
                    .help(seriesHelpText)
            }

            Text(primaryDisplayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(eventTextStyle)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(2)

            Spacer(minLength: 2)

            if occurrence.isNext {
                compactPill(title: "Next", color: .blue)
            } else if occurrence.isPast {
                compactPill(
                    title: compactExecutionTitle,
                    color: compactExecutionColor
                )
            } else if occurrence.event.enabled == false {
                compactPill(title: "Disabled", color: .orange)
            } else if occurrence.scheduleCategoryEnabled == false {
                compactPill(title: "Off", color: .orange)
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
        .opacity(occurrence.isEffectivelyScheduled ? 1.0 : 0.55)
        .help(helpText)
        .onTapGesture(count: 2) {
            editAction(occurrence.event.repeatsDaily ? .thisOccurrence : .entireSeries)
        }
        .contextMenu {
            Button {
                runAction()
            } label: {
                Label("Run Event Action", systemImage: "play.fill")
            }

            if occurrence.event.repeatsDaily {
                Button {
                    editAction(.thisOccurrence)
                } label: {
                    Label("Edit This Occurrence", systemImage: "pencil.and.scribble")
                }

                Button {
                    editAction(.entireSeries)
                } label: {
                    Label("Edit Entire Series", systemImage: "rectangle.stack.badge.pencil")
                }

                Button {
                    showSeriesAction()
                } label: {
                    Label("Show Only This Series", systemImage: "line.3.horizontal.decrease.circle")
                }
            } else {
                Button {
                    editAction(.entireSeries)
                } label: {
                    Label("Edit Event", systemImage: "pencil")
                }
            }

            Divider()

            Button(role: .destructive) {
                deleteAction()
            } label: {
                if occurrence.event.repeatsDaily {
                    Label("Delete…", systemImage: "trash")
                } else {
                    Label("Delete Event", systemImage: "trash")
                }
            }
        }
    }

    private var helpText: String {
        let baseText = "\(timeText(for: occurrence.occurrenceDate)) — \(primaryDisplayName)"
        let actionText = hasNamedSeries ? " • Action: \(occurrence.action.name)" : ""

        guard occurrence.event.repeatsDaily else {
            return "\(baseText)\(actionText)"
        }

        return "\(baseText)\(actionText) • \(seriesHelpText)"
    }

    private var cleanedSeriesName: String? {
        let trimmed = occurrence.event.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var hasNamedSeries: Bool {
        cleanedSeriesName != nil
    }

    private var primaryDisplayName: String {
        cleanedSeriesName ?? occurrence.action.name
    }

    private var seriesHelpText: String {
        let summary = ScheduleEntryFormatter.repeatSummary(
            for: occurrence.event,
            oneTimeText: "One time",
            includeRepeatUntil: true
        )

        if let cleanedSeriesName {
            return "Part of recurring series: \(cleanedSeriesName) • \(summary)"
        }

        return "Part of a recurring series • \(summary)"
    }

    private var actionColor: Color {
        switch occurrence.action.type {
        case .show:
            return .blue

        case .utility:
            return .purple
        }
    }

    private var calendarDisplayColor: Color {
        occurrence.isEffectivelyScheduled ? actionColor : .orange
    }

    private var eventTextStyle: AnyShapeStyle {
        if occurrence.isPast {
            return AnyShapeStyle(.secondary)
        }

        if occurrence.isEffectivelyScheduled == false {
            return AnyShapeStyle(Color.orange)
        }

        return AnyShapeStyle(.primary)
    }

    private var compactExecutionTitle: String {
        guard let executionRecord = occurrence.executionRecord else {
            return "No Rec"
        }

        switch executionRecord.result {
        case .ran:
            return "Ran"

        case .skipped:
            return "Skipped"

        case .failed:
            return "Failed"
        }
    }

    private var compactExecutionColor: Color {
        guard let executionRecord = occurrence.executionRecord else {
            return .secondary
        }

        switch executionRecord.result {
        case .ran:
            return .green

        case .skipped:
            return .orange

        case .failed:
            return .red
        }
    }

    private var chipBackground: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(calendarDisplayColor.opacity(occurrence.isEffectivelyScheduled ? (occurrence.isPast ? 0.08 : 0.18) : 0.10))
    }

    private var chipBorder: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .strokeBorder(
                occurrence.isNext ? Color.blue.opacity(0.72) : calendarDisplayColor.opacity(0.30),
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
        let formatter = use24HourTime ? Self.time24Formatter : Self.time12Formatter
        return formatter.string(from: date)
    }

    private static let time24Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private static let time12Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()
}

// MARK: - Month Day Cell

private struct MonthDayCell: View {
    let calendarDay: MonthCalendarDay
    let showCount: Int
    let utilityCount: Int
    let showHasDisabledOrOffEvent: Bool
    let utilityHasDisabledOrOffEvent: Bool
    let showActionsEnabled: Bool
    let utilityActionsEnabled: Bool
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
                    color: showCountColor
                )
            }

            if utilityCount > 0 {
                countPill(
                    count: utilityCount,
                    singular: "Utility Event",
                    plural: "Utility Events",
                    color: utilityCountColor
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
        Self.dayNumberFormatter.string(from: calendarDay.date)
    }

    private var showCountColor: Color {
        showHasDisabledOrOffEvent || showActionsEnabled == false ? .orange : .blue
    }

    private var utilityCountColor: Color {
        utilityHasDisabledOrOffEvent || utilityActionsEnabled == false ? .orange : .purple
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

    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
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
    @State private var repeatMode: ScheduleRepeatMode
    @State private var intervalMinutes: Int
    @State private var intervalEndTime: Date
    @State private var seriesName: String

    init(
        occurrence: ScheduleOccurrence,
        initialScope: ScheduleEditScope? = nil
    ) {
        self.occurrence = occurrence

        let initialDate = occurrence.event.repeatsDaily ? occurrence.occurrenceDate : occurrence.event.startDate
        let components = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: initialDate
        )

        _selectedActionID = State(initialValue: occurrence.event.actionDefinitionID)
        _selectedDate = State(initialValue: initialDate)
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
        _editScope = State(
            initialValue: initialScope ?? (occurrence.event.repeatsDaily ? .thisOccurrence : .entireSeries)
        )
        _repeatMode = State(initialValue: occurrence.event.repeatMode)
        _intervalMinutes = State(initialValue: occurrence.event.intervalMinutes ?? 10)
        _intervalEndTime = State(initialValue: occurrence.event.intervalEndTime ?? Self.defaultIntervalEndTime(from: occurrence.event.startDate))
        _seriesName = State(initialValue: occurrence.event.seriesName ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if occurrence.event.repeatsDaily {
                scopePicker
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    actionPicker
                    dateTimeSection

                    if editScope == .entireSeries {
                        repeatSection

                        if editValidationIssues.isEmpty == false {
                            editValidationCard
                        }

                        if repeatsDaily {
                            seriesPreviewCard
                        }
                    } else {
                        singleOccurrenceNote
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .padding(20)
        .frame(width: 620, height: editScope == .entireSeries ? 740 : 500)
        .onChange(of: editScope) { _, newScope in
            if newScope == .entireSeries {
                loadDateAndTime(from: occurrence.event.startDate)
            } else {
                loadDateAndTime(from: occurrence.occurrenceDate)
            }
        }
        .onChange(of: repeatsDaily) { _, isRepeating in
            if isRepeating && repeatWeekdays.isEmpty {
                repeatWeekdays = [Calendar.current.component(.weekday, from: selectedDate)]
            }

            if isRepeating == false {
                repeatMode = .oncePerSelectedDay
            }
        }
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
                editScope == .entireSeries ? "Start Date" : "Date",
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
            .monospacedDigit()
            .onChange(of: value.wrappedValue) { _, newValue in
                value.wrappedValue = min(max(newValue, range.lowerBound), range.upperBound)
            }
        }
    }

    private var singleOccurrenceNote: some View {
        Label(
            "Saving this occurrence only will remove the original generated occurrence and create a new one-time Event.",
            systemImage: "rectangle.stack.badge.minus"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(10)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Repeat", isOn: $repeatsDaily)

            if repeatsDaily {
                seriesNameField
                weekdayGrid
                repeatPatternPicker

                if repeatMode == .intervalDuringDay {
                    intervalSection
                }

                DatePicker(
                    "Series End Date",
                    selection: $repeatUntil,
                    displayedComponents: [.date]
                )
            }
        }
    }

    private var seriesNameField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Series Name")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Optional", text: $seriesName)
                .textFieldStyle(.roundedBorder)

            Text("Optional. The backend uses a hidden series identifier, so this can be left blank.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var repeatPatternPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Time Pattern")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Time Pattern", selection: $repeatMode) {
                Text("Once per selected day").tag(ScheduleRepeatMode.oncePerSelectedDay)
                Text("Repeat during selected days").tag(ScheduleRepeatMode.intervalDuringDay)
            }
            .pickerStyle(.segmented)
        }
    }

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                integerField("Repeat Every (min)", value: $intervalMinutes, range: 1...1_440)

                VStack(alignment: .leading, spacing: 5) {
                    Text("End Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    DatePicker(
                        "End Time",
                        selection: $intervalEndTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                }

                Spacer()
            }

            HStack(spacing: 8) {
                ForEach([5, 10, 15, 30, 60], id: \.self) { preset in
                    Button(preset == 60 ? "Hourly" : "\(preset) min") {
                        intervalMinutes = preset
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Text("End Time is inclusive. If the final Event lands exactly on this time, it will run at this time, then stop.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if intervalCrossesMidnight {
                Label(
                    "Daily repeating Events cannot cross midnight yet. Please create a second Event series for the next day.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private var seriesPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack")
                    .font(.caption)
                    .foregroundStyle(.blue)

                Text("Series Preview")
                    .font(.caption)
                    .bold()

                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                previewSummaryLine("Schedule", previewScheduleDescription)
                previewSummaryLine("Generated Events", previewTotalCountText)
                previewSummaryLine("Selected Days", ScheduleEntryFormatter.weekdaySummary(for: repeatWeekdays))
                previewSummaryLine("Per Selected Day", previewOccurrencesPerActiveDayText)

                if repeatMode == .intervalDuringDay {
                    previewSummaryLine("Daily Final Run", previewDailyFinalRunText)
                }
            }

            Divider()
                .opacity(0.35)

            VStack(alignment: .leading, spacing: 5) {
                Text("Next Generated Events")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(.secondary)

                if previewOccurrences.isEmpty {
                    Text("No occurrences are generated by these settings.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    ForEach(previewOccurrences, id: \.timeIntervalSince1970) { occurrenceDate in
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.stack")
                                .font(.caption2)
                                .foregroundStyle(.blue)

                            Text(Self.previewFormatter.string(from: occurrenceDate))
                                .font(.caption2)
                                .monospacedDigit()

                            Spacer()
                        }
                    }

                    if previewTotalOccurrenceCount > previewOccurrences.count {
                        Text("…and \(previewTotalOccurrenceCount - previewOccurrences.count) more in this series.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func previewSummaryLine(
        _ label: String,
        _ value: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 104, alignment: .leading)

            Text(value)
                .font(.caption2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private var previewScheduleDescription: String {
        guard let previewEvent else {
            return "Incomplete schedule."
        }

        return ScheduleEntryFormatter.repeatSummary(
            for: previewEvent,
            oneTimeText: "One-time",
            includeRepeatUntil: true
        )
    }

    private var previewTotalCountText: String {
        let count = previewTotalOccurrenceCount
        return "\(count) Event\(count == 1 ? "" : "s")"
    }

    private var previewOccurrencesPerActiveDayText: String {
        guard let previewEvent else {
            return "—"
        }

        let count = firstActiveDayOccurrences(for: previewEvent).count
        return "\(count) Event\(count == 1 ? "" : "s")"
    }

    private var previewDailyFinalRunText: String {
        guard let previewEvent,
              let finalRun = firstActiveDayOccurrences(for: previewEvent).last else {
            return "No daily occurrence generated."
        }

        return Self.previewTimeFormatter.string(from: finalRun)
    }

    private var previewOccurrences: [Date] {
        guard let previewEvent else {
            return []
        }

        return generatedPreviewOccurrences(
            for: previewEvent,
            limit: 12
        )
    }

    private var previewTotalOccurrenceCount: Int {
        guard let previewEvent else {
            return 0
        }

        return generatedPreviewOccurrences(
            for: previewEvent,
            limit: 10_000
        ).count
    }

    private var previewEvent: ScheduleEntry? {
        guard let selectedActionID else {
            return nil
        }

        let startDate = composedDate()
        let endDate = endOfDay(for: repeatUntil)

        return ScheduleEntry(
            id: occurrence.event.id,
            seriesID: occurrence.event.seriesID ?? UUID(),
            seriesName: cleanedSeriesName,
            actionDefinitionID: selectedActionID,
            startDate: startDate,
            enabled: occurrence.event.enabled,
            repeatsDaily: true,
            repeatWeekdays: repeatWeekdays,
            repeatUntil: endDate,
            repeatMode: repeatMode,
            intervalMinutes: repeatMode == .intervalDuringDay ? intervalMinutes : nil,
            intervalEndTime: repeatMode == .intervalDuringDay ? intervalEndDateOnSelectedDate : nil,
            seriesEndDate: endDate,
            excludedOccurrenceDates: occurrence.event.excludedOccurrenceDates,
            excludedOccurrenceKeys: occurrence.event.excludedOccurrenceKeys
        )
    }

    private func firstActiveDayOccurrences(for previewEvent: ScheduleEntry) -> [Date] {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: previewEvent.startDate)
        let finalDay = calendar.startOfDay(for: previewEvent.repeatUntil ?? previewEvent.startDate)
        var guardCount = 0

        while day <= finalDay, guardCount < 370 {
            let occurrences = ScheduleEntryFormatter.occurrenceDates(
                for: previewEvent,
                on: day,
                calendar: calendar
            )
            .filter { $0 >= previewEvent.startDate }
            .sorted()

            if occurrences.isEmpty == false {
                return occurrences
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }

            day = nextDay
            guardCount += 1
        }

        return []
    }

    private func generatedPreviewOccurrences(
        for previewEvent: ScheduleEntry,
        limit: Int
    ) -> [Date] {
        let calendar = Calendar.current
        var occurrences: [Date] = []
        var day = calendar.startOfDay(for: previewEvent.startDate)
        let finalDay = calendar.startOfDay(for: previewEvent.repeatUntil ?? previewEvent.startDate)
        var guardCount = 0

        while day <= finalDay, occurrences.count < limit, guardCount < 370 {
            occurrences.append(
                contentsOf: ScheduleEntryFormatter.occurrenceDates(
                    for: previewEvent,
                    on: day,
                    calendar: calendar
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }

            day = nextDay
            guardCount += 1
        }

        return occurrences
            .filter { $0 >= previewEvent.startDate }
            .sorted()
            .prefix(limit)
            .map { $0 }
    }

    private var editValidationIssues: [ScheduleEditValidationIssue] {
        var issues: [ScheduleEditValidationIssue] = []

        if selectedActionID == nil {
            issues.append(.error("Choose an Action before saving this Event."))
        }

        // Editing one generated occurrence detaches it into a standalone Event.
        // Series recurrence checks are intentionally skipped for this scope.
        if occurrence.event.repeatsDaily && editScope == .thisOccurrence {
            return issues
        }

        guard repeatsDaily else {
            return issues
        }

        if repeatWeekdays.isEmpty {
            issues.append(.error("Select at least one repeat day."))
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: composedDate())
        let endDay = calendar.startOfDay(for: repeatUntil)

        if endDay < startDay {
            issues.append(.error("Series End Date must be on or after the Start Date."))
        }

        if repeatMode == .intervalDuringDay {
            if intervalMinutes <= 0 {
                issues.append(.error("Repeat Every must be at least 1 minute."))
            }

            if intervalCrossesMidnight {
                issues.append(.error("Daily repeating Events cannot cross midnight yet. Create a second Event series for the next day."))
            }

            if intervalMinutes < 5 {
                issues.append(.warning("This creates a very frequent schedule. Confirm that the target systems can safely receive Events this often."))
            }
        }

        let generatedCount = previewTotalOccurrenceCount

        if generatedCount == 0 {
            issues.append(.error("These settings do not generate any Events. Adjust the date range, repeat days, or time settings."))
        } else if generatedCount > 500 {
            issues.append(.warning("This series generates \(generatedCount) Events. That may be intentional, but review the preview before saving."))
        }

        return issues
    }

    private var editValidationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Schedule Check")
                    .font(.caption)
                    .bold()

                Text("Warnings are allowed. Errors must be fixed before saving.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(editValidationIssues) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: issue.severity.systemImageName)
                            .font(.caption2)
                            .foregroundStyle(issue.severity.color)
                            .frame(width: 14)

                        Text(issue.message)
                            .font(.caption2)
                            .foregroundStyle(issue.severity.color)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.white.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
            .disabled(canSave == false)
        }
    }

    private var canSave: Bool {
        editValidationIssues.contains { $0.severity == .error } == false
    }

    private var intervalCrossesMidnight: Bool {
        guard repeatsDaily, repeatMode == .intervalDuringDay else {
            return false
        }

        guard let endTime = intervalEndDateOnSelectedDate else {
            return true
        }

        return endTime <= composedDate()
    }

    private var intervalEndDateOnSelectedDate: Date? {
        ScheduleEntryFormatter.date(
            on: selectedDate,
            usingTimeFrom: intervalEndTime
        )
    }

    private var cleanedSeriesName: String? {
        let trimmed = seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
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
        if occurrence.event.repeatMode == .intervalDuringDay {
            let occurrenceKey = ScheduleEntryFormatter.occurrenceKey(
                eventID: occurrence.event.id,
                occurrenceDate: occurrence.occurrenceDate
            )

            if appState.scheduleEntries[originalIndex].excludedOccurrenceKeys.contains(occurrenceKey) == false {
                appState.scheduleEntries[originalIndex].excludedOccurrenceKeys.append(occurrenceKey)
            }
        } else {
            let occurrenceDay = Calendar.current.startOfDay(for: occurrence.occurrenceDate)
            appState.scheduleEntries[originalIndex].excludedOccurrenceDates.append(occurrenceDay)
        }

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

        if repeatsDaily {
            appState.scheduleEntries[index].seriesID = occurrence.event.seriesID ?? UUID()
            appState.scheduleEntries[index].seriesName = cleanedSeriesName
            appState.scheduleEntries[index].repeatMode = repeatMode
            appState.scheduleEntries[index].intervalMinutes = repeatMode == .intervalDuringDay ? intervalMinutes : nil
            appState.scheduleEntries[index].intervalEndTime = repeatMode == .intervalDuringDay ? intervalEndDateOnSelectedDate : nil
            appState.scheduleEntries[index].seriesEndDate = endOfDay(for: repeatUntil)
        } else {
            appState.scheduleEntries[index].seriesID = nil
            appState.scheduleEntries[index].seriesName = nil
            appState.scheduleEntries[index].repeatMode = .oncePerSelectedDay
            appState.scheduleEntries[index].intervalMinutes = nil
            appState.scheduleEntries[index].intervalEndTime = nil
            appState.scheduleEntries[index].seriesEndDate = nil
            appState.scheduleEntries[index].excludedOccurrenceDates.removeAll()
            appState.scheduleEntries[index].excludedOccurrenceKeys.removeAll()
        }
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

    private func loadDateAndTime(from date: Date) {
        selectedDate = date

        let components = Calendar.current.dateComponents(
            [.hour, .minute, .second],
            from: date
        )

        hour = components.hour ?? 0
        minute = components.minute ?? 0
        second = components.second ?? 0
    }

    private func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        return calendar.date(
            byAdding: DateComponents(day: 1, second: -1),
            to: startOfDay
        ) ?? date
    }

    private static func defaultIntervalEndTime(from startDate: Date) -> Date {
        Calendar.current.date(
            byAdding: .hour,
            value: 1,
            to: startDate
        ) ?? startDate
    }

    private static let previewFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm:ss a"
        return formatter
    }()

    private static let previewTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}

// MARK: - Schedule Edit Validation Issue

private struct ScheduleEditValidationIssue: Identifiable, Equatable {
    enum Severity: Equatable {
        case error
        case warning

        var color: Color {
            switch self {
            case .error:
                return .red

            case .warning:
                return .orange
            }
        }

        var systemImageName: String {
            switch self {
            case .error:
                return "xmark.octagon.fill"

            case .warning:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    let severity: Severity
    let message: String

    var id: String {
        "\(severity)-\(message)"
    }

    static func error(_ message: String) -> ScheduleEditValidationIssue {
        ScheduleEditValidationIssue(severity: .error, message: message)
    }

    static func warning(_ message: String) -> ScheduleEditValidationIssue {
        ScheduleEditValidationIssue(severity: .warning, message: message)
    }
}

// MARK: - Models

private enum SchedulePresentationMode: String, CaseIterable, Identifiable {
    case calendar = "Calendar View"
    case list = "List View"

    var id: String {
        rawValue
    }
}

private enum ScheduleRangeMode: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String {
        rawValue
    }
}

private struct ScheduleEditRequest: Identifiable {
    let id = UUID()
    let occurrence: ScheduleOccurrence
    let initialScope: ScheduleEditScope
}

private struct ScheduleOccurrence: Identifiable {
    let event: ScheduleEntry
    let action: ActionDefinition
    let occurrenceDate: Date
    let isPast: Bool
    let scheduleCategoryEnabled: Bool
    let executionRecord: ScheduleExecutionRecord?
    var isNext: Bool

    var isEffectivelyScheduled: Bool {
        event.enabled && scheduleCategoryEnabled
    }

    var id: String {
        ScheduleEntryFormatter.occurrenceKey(
            eventID: event.id,
            occurrenceDate: occurrenceDate
        )
    }
}

private struct ScheduleListDayGroup: Identifiable {
    let date: Date
    let occurrences: [ScheduleOccurrence]

    var id: TimeInterval {
        Calendar.current.startOfDay(for: date).timeIntervalSince1970
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


