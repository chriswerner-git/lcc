//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: EventEditorView.swift
//  Purpose: Creates scheduled Events that trigger saved Actions.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI

struct EventEditorView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    // MARK: - Action Selection

    @State private var selectedActionID: UUID?

    // MARK: - Date / Time

    @State private var selectedDate: Date = EventEditorView.defaultStartDate()
    @State private var hour: Int = 0
    @State private var minute: Int = 0
    @State private var second: Int = 0
    @State private var meridiem: Meridiem = .am

    // MARK: - Repeat Rules

    @State private var repeatsDaily: Bool = false
    @State private var repeatWeekdays: Set<Int> = []
    @State private var repeatUntil: Date = EventEditorView.defaultRepeatUntilDate()
    @State private var repeatMode: ScheduleRepeatMode = .oncePerSelectedDay
    @State private var intervalMinutes: Int = 10
    @State private var intervalEndTime: Date = EventEditorView.defaultIntervalEndTime()
    @State private var seriesName: String = ""

    // MARK: - Derived State

    private var sortedActions: [ActionDefinition] {
        appState.actionDefinitions
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var selectedAction: ActionDefinition? {
        guard let selectedActionID else {
            return nil
        }

        return appState.actionDefinitions.first {
            $0.id == selectedActionID
        }
    }

    private var canAddEvent: Bool {
        selectedActionID != nil && repeatSelectionIsValid && intervalSelectionIsValid
    }

    private var repeatSelectionIsValid: Bool {
        repeatsDaily == false || repeatWeekdays.isEmpty == false
    }

    private var intervalSelectionIsValid: Bool {
        guard repeatsDaily, repeatMode == .intervalDuringDay else {
            return true
        }

        return intervalMinutes > 0 && intervalCrossesMidnight == false
    }

    private var intervalCrossesMidnight: Bool {
        guard repeatsDaily, repeatMode == .intervalDuringDay else {
            return false
        }

        guard let endTime = intervalEndDateOnSelectedDate else {
            return true
        }

        return endTime <= composedStartDate()
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

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 18) {
                header

                if appState.actionDefinitions.isEmpty {
                    emptyActionsCard
                } else {
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 18) {
                            actionCard
                            scheduleCard
                            previewCard
                        }
                        .padding(.trailing, 6)
                    }

                    footerButtons
                }
            }
            .padding(20)
        }
        .frame(width: 720, height: 820)
        .onAppear {
            initializeEditor()
        }
        .onChange(of: appState.use24HourTime) { _, _ in
            let date = composedStartDate()
            loadTimeFields(from: date)
        }
        .onChange(of: selectedDate) { _, newDate in
            if repeatsDaily && repeatWeekdays.isEmpty {
                repeatWeekdays = [weekday(for: newDate)]
            }
        }
        .onChange(of: repeatsDaily) { _, isRepeating in
            if isRepeating {
                if repeatWeekdays.isEmpty {
                    repeatWeekdays = [weekday(for: selectedDate)]
                }
            } else {
                repeatMode = .oncePerSelectedDay
            }
        }
    }

    // MARK: - Initial State

    private func initializeEditor() {
        if selectedActionID == nil {
            selectedActionID = sortedActions.first?.id
        }

        if repeatWeekdays.isEmpty {
            repeatWeekdays = [weekday(for: selectedDate)]
        }

        loadTimeFields(from: selectedDate)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 40, height: 40)

                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Add Event")
                    .font(.largeTitle)
                    .bold()

                Text("Schedule an Action to run automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Action Card

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Action",
                subtitle: "Choose what this Event will run."
            )

            HStack(spacing: 12) {
                Picker("Action", selection: $selectedActionID) {
                    ForEach(sortedActions) { action in
                        Text("\(action.name) — \(action.type.rawValue)")
                            .tag(Optional(action.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                if let selectedAction {
                    actionTypePill(selectedAction.type)
                }
            }

            if let selectedAction {
                selectedActionSummary(for: selectedAction)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func selectedActionSummary(for action: ActionDefinition) -> some View {
        HStack(spacing: 8) {
            Image(systemName: action.type == .show ? "play.fill" : "bolt.fill")
                .foregroundStyle(actionColor(for: action.type))

            Text(actionSummary(for: action))
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(10)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func actionSummary(for action: ActionDefinition) -> String {
        switch action.type {
        case .show:
            return "\(action.commands.count) UDP step\(action.commands.count == 1 ? "" : "s")"

        case .utility:
            return "\(action.utilityCommands.count) utility step\(action.utilityCommands.count == 1 ? "" : "s")"
        }
    }

    private func actionTypePill(_ type: ActionType) -> some View {
        Text(type.rawValue)
            .font(.caption)
            .bold()
            .foregroundStyle(actionColor(for: type))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(actionColor(for: type).opacity(0.16))
            )
    }

    // MARK: - Schedule Card

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(
                title: "Schedule",
                subtitle: appState.use24HourTime ? "Using 24-hour time." : "Using 12-hour time."
            )

            dateSection
            timeSection
            repeatSection
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Date Section

    private var dateSection: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Start Date")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DatePicker(
                    "Start Date",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Day")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(dayOfWeekText(for: selectedDate))
                    .font(.headline)
            }

            Spacer()
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Time")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                timeNumberField(
                    label: "Hour",
                    value: $hour,
                    range: appState.use24HourTime ? 0...23 : 1...12
                )

                timeNumberField(
                    label: "Minute",
                    value: $minute,
                    range: 0...59
                )

                timeNumberField(
                    label: "Second",
                    value: $second,
                    range: 0...59
                )

                if appState.use24HourTime == false {
                    meridiemPicker
                }

                Spacer()
            }
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var meridiemPicker: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("AM / PM")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("AM / PM", selection: $meridiem) {
                ForEach(Meridiem.allCases) { value in
                    Text(value.rawValue).tag(value)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
    }

    private func timeNumberField(
        label: String,
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
            .frame(width: 76)
            .monospacedDigit()
            .onChange(of: value.wrappedValue) { _, newValue in
                value.wrappedValue = clamped(newValue, to: range)
            }

            Stepper(
                "",
                value: value,
                in: range
            )
            .labelsHidden()
            .frame(width: 76)
        }
    }

    // MARK: - Repeat Section

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Repeat", isOn: $repeatsDaily)
                .toggleStyle(.switch)

            if repeatsDaily {
                repeatOptions
            }
        }
    }

    private var repeatOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            seriesNameField

            Divider()
                .opacity(0.45)

            Text("Repeat Days")
                .font(.caption)
                .foregroundStyle(.secondary)

            weekdaySelectionGrid
            repeatQuickButtons
            repeatValidationMessage

            Divider()
                .opacity(0.45)

            repeatPatternSection

            Divider()
                .opacity(0.45)

            repeatUntilPicker
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var seriesNameField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Series Name")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Optional — for example, Daily Loop or Six Times Per Hour", text: $seriesName)
                .textFieldStyle(.roundedBorder)

            Text("Optional. Launch Control Center uses a hidden identifier for the series, so this can be left blank.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var repeatPatternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time Pattern")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Time Pattern", selection: $repeatMode) {
                Text("Once per selected day").tag(ScheduleRepeatMode.oncePerSelectedDay)
                Text("Repeat during selected days").tag(ScheduleRepeatMode.intervalDuringDay)
            }
            .pickerStyle(.segmented)

            if repeatMode == .intervalDuringDay {
                intervalOptions
            }
        }
    }

    private var intervalOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Repeat Every")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Minutes",
                        value: $intervalMinutes,
                        format: .number.grouping(.never)
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .monospacedDigit()
                    .onChange(of: intervalMinutes) { _, newValue in
                        intervalMinutes = clamped(newValue, to: 1...1_440)
                    }
                }

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

            intervalPresetButtons

            Text("End Time is inclusive. If the final Event lands exactly on this time, it will run at this time, then stop. Example: every 10 minutes from 1:10 PM until 8:00 PM includes 8:00 PM.")
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

    private var intervalPresetButtons: some View {
        HStack(spacing: 8) {
            ForEach([5, 10, 15, 30, 60], id: \.self) { preset in
                Button(preset == 60 ? "Hourly" : "\(preset) min") {
                    intervalMinutes = preset
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()
        }
    }

    private var repeatQuickButtons: some View {
        HStack(spacing: 12) {
            Button("Every Day") {
                repeatWeekdays = Set(1...7)
            }

            Button("Weekdays") {
                repeatWeekdays = Set([2, 3, 4, 5, 6])
            }

            Button("Weekends") {
                repeatWeekdays = Set([1, 7])
            }

            Button("Clear") {
                repeatWeekdays.removeAll()
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var repeatValidationMessage: some View {
        if repeatWeekdays.isEmpty {
            Text("Select at least one repeat day.")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var repeatUntilPicker: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Series End Date")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                DatePicker(
                    "Series End Date",
                    selection: $repeatUntil,
                    displayedComponents: [.date]
                )
                .labelsHidden()

                Text("The series may run through this date. For interval repeats, the daily End Time controls the last run within each selected day.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var weekdaySelectionGrid: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 8),
                count: 7
            ),
            spacing: 8
        ) {
            ForEach(WeekdayOption.allCases) { weekday in
                weekdayToggleButton(weekday)
            }
        }
    }

    private func weekdayToggleButton(_ weekday: WeekdayOption) -> some View {
        let isSelected = repeatWeekdays.contains(weekday.calendarValue)

        return Button {
            toggleWeekday(weekday.calendarValue)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.caption)

                Text(weekday.shortName)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.blue : Color.secondary)
        .background(weekdayButtonBackground(isSelected: isSelected))
        .overlay(weekdayButtonBorder(isSelected: isSelected))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func toggleWeekday(_ weekday: Int) {
        if repeatWeekdays.contains(weekday) {
            repeatWeekdays.remove(weekday)
        } else {
            repeatWeekdays.insert(weekday)
        }
    }

    // MARK: - Preview

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Preview",
                subtitle: previewSubtitle
            )

            if canAddEvent == false {
                Text("Complete the schedule settings to preview generated Events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(insetPanelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(previewOccurrences, id: \.timeIntervalSince1970) { occurrenceDate in
                        HStack(spacing: 8) {
                            Image(systemName: repeatsDaily ? "rectangle.stack" : "calendar")
                                .font(.caption)
                                .foregroundStyle(repeatsDaily ? .blue : .secondary)

                            Text(Self.previewFormatter.string(from: occurrenceDate))
                                .font(.caption)
                                .monospacedDigit()

                            Spacer()
                        }
                    }

                    if previewOccurrences.isEmpty {
                        Text("No occurrences are generated by these settings.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(insetPanelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var previewSubtitle: String {
        if repeatsDaily {
            return "Showing up to the next 25 generated Events."
        }

        return "This Event will run once."
    }

    private var previewOccurrences: [Date] {
        guard canAddEvent, let previewEvent = makePreviewEvent() else {
            return []
        }

        if previewEvent.repeatsDaily == false {
            return [previewEvent.startDate]
        }

        let calendar = Calendar.current
        var occurrences: [Date] = []
        var day = calendar.startOfDay(for: previewEvent.startDate)
        let finalDay = calendar.startOfDay(for: previewEvent.repeatUntil ?? previewEvent.startDate)
        var guardCount = 0

        while day <= finalDay, occurrences.count < 25, guardCount < 370 {
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
            .prefix(25)
            .map { $0 }
    }

    private func makePreviewEvent() -> ScheduleEntry? {
        guard let selectedActionID else {
            return nil
        }

        let startDate = composedStartDate()
        let endDate = repeatsDaily ? Self.endOfDay(for: repeatUntil) : nil
        let intervalEndDate = repeatMode == .intervalDuringDay ? intervalEndDateOnSelectedDate : nil

        return ScheduleEntry(
            seriesID: repeatsDaily ? UUID() : nil,
            seriesName: cleanedSeriesName,
            actionDefinitionID: selectedActionID,
            startDate: startDate,
            enabled: true,
            repeatsDaily: repeatsDaily,
            repeatWeekdays: repeatsDaily ? repeatWeekdays : [],
            repeatUntil: endDate,
            repeatMode: repeatsDaily ? repeatMode : .oncePerSelectedDay,
            intervalMinutes: repeatsDaily && repeatMode == .intervalDuringDay ? intervalMinutes : nil,
            intervalEndTime: intervalEndDate,
            seriesEndDate: endDate
        )
    }

    // MARK: - Footer

    private var footerButtons: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }

            Spacer()

            Button {
                addEvent()
            } label: {
                Label("Add Event", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .disabled(canAddEvent == false)
        }
    }

    private var emptyActionsCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.play")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary)

            Text("No Actions Defined")
                .font(.title3)
                .bold()

            Text("Create an Action before scheduling an Event.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding(20)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Add Event

    private func addEvent() {
        guard let selectedActionID else {
            return
        }

        let startDate = composedStartDate()
        let endDate = repeatsDaily ? Self.endOfDay(for: repeatUntil) : nil

        let event = ScheduleEntry(
            seriesID: repeatsDaily ? UUID() : nil,
            seriesName: repeatsDaily ? cleanedSeriesName : nil,
            actionDefinitionID: selectedActionID,
            startDate: startDate,
            enabled: true,
            repeatsDaily: repeatsDaily,
            repeatWeekdays: repeatsDaily ? repeatWeekdays : [],
            repeatUntil: endDate,
            repeatMode: repeatsDaily ? repeatMode : .oncePerSelectedDay,
            intervalMinutes: repeatsDaily && repeatMode == .intervalDuringDay ? intervalMinutes : nil,
            intervalEndTime: repeatsDaily && repeatMode == .intervalDuringDay ? intervalEndDateOnSelectedDate : nil,
            seriesEndDate: endDate
        )

        appState.scheduleEntries.append(event)
        dismiss()
    }

    // MARK: - Time Helpers

    private func loadTimeFields(from date: Date) {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.hour, .minute, .second],
            from: date
        )

        let hour24 = components.hour ?? 0
        minute = components.minute ?? 0
        second = components.second ?? 0

        if appState.use24HourTime {
            hour = hour24
        } else {
            meridiem = hour24 >= 12 ? .pm : .am

            let hour12 = hour24 % 12
            hour = hour12 == 0 ? 12 : hour12
        }
    }

    private func composedStartDate() -> Date {
        let calendar = Calendar.current

        let dateComponents = calendar.dateComponents(
            [.year, .month, .day],
            from: selectedDate
        )

        var composedComponents = DateComponents()
        composedComponents.year = dateComponents.year
        composedComponents.month = dateComponents.month
        composedComponents.day = dateComponents.day
        composedComponents.hour = composedHour24()
        composedComponents.minute = clamped(minute, to: 0...59)
        composedComponents.second = clamped(second, to: 0...59)

        return calendar.date(from: composedComponents) ?? selectedDate
    }

    private func composedHour24() -> Int {
        if appState.use24HourTime {
            return clamped(hour, to: 0...23)
        }

        let safeHour = clamped(hour, to: 1...12)

        switch meridiem {
        case .am:
            return safeHour == 12 ? 0 : safeHour

        case .pm:
            return safeHour == 12 ? 12 : safeHour + 12
        }
    }

    private func clamped(
        _ value: Int,
        to range: ClosedRange<Int>
    ) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: - Date Helpers

    private func weekday(for date: Date) -> Int {
        Calendar.current.component(.weekday, from: date)
    }

    private func dayOfWeekText(for date: Date) -> String {
        Self.dayOfWeekFormatter.string(from: date)
    }

    private static func defaultStartDate() -> Date {
        let now = Date()
        let calendar = Calendar.current

        guard let nextMinute = calendar.date(
            byAdding: .minute,
            value: 1,
            to: now
        ) else {
            return now
        }

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: nextMinute
        )

        return calendar.date(from: components) ?? nextMinute
    }

    private static func defaultRepeatUntilDate() -> Date {
        let calendar = Calendar.current
        let now = Date()

        guard let oneWeekFromNow = calendar.date(
            byAdding: .day,
            value: 7,
            to: now
        ) else {
            return now
        }

        return endOfDay(for: oneWeekFromNow)
    }

    private static func defaultIntervalEndTime() -> Date {
        let calendar = Calendar.current
        let start = defaultStartDate()

        return calendar.date(
            byAdding: .hour,
            value: 1,
            to: start
        ) ?? start
    }

    private static func endOfDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        return calendar.date(
            byAdding: DateComponents(day: 1, second: -1),
            to: startOfDay
        ) ?? date
    }

    private static let dayOfWeekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    private static let previewFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d • h:mm:ss a"
        return formatter
    }()

    // MARK: - Shared UI

    private func sectionHeader(
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    private func actionColor(for type: ActionType) -> Color {
        switch type {
        case .show:
            return .blue

        case .utility:
            return .purple
        }
    }

    // MARK: - Styling

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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    }

    private var insetPanelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(0.18))
    }

    private func weekdayButtonBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                isSelected
                    ? Color.blue.opacity(0.18)
                    : Color(nsColor: .textBackgroundColor).opacity(0.18)
            )
    }

    private func weekdayButtonBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(
                isSelected
                    ? Color.blue.opacity(0.45)
                    : Color.white.opacity(0.08),
                lineWidth: 1
            )
    }
}

// MARK: - Meridiem

private enum Meridiem: String, CaseIterable, Identifiable {
    case am = "AM"
    case pm = "PM"

    var id: String {
        rawValue
    }
}

// MARK: - Weekday Option

private enum WeekdayOption: Int, CaseIterable, Identifiable {
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

    var calendarValue: Int {
        rawValue
    }

    var shortName: String {
        ScheduleEntryFormatter.shortWeekdayName(for: rawValue)
    }
}

