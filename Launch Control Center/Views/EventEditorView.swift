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
        validationIssues.contains { $0.severity == .error } == false
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

            VStack(alignment: .leading, spacing: 12) {
                header

                if appState.actionDefinitions.isEmpty {
                    emptyActionsCard
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 10) {
                                actionCard
                                whenCard
                                repeatCard
                            }
                            .padding(.trailing, 4)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        ScrollView(.vertical) {
                            VStack(alignment: .leading, spacing: 10) {
                                if validationIssues.isEmpty == false {
                                    validationCard
                                }

                                previewCard
                            }
                            .padding(.trailing, 4)
                        }
                        .frame(width: 340)
                        .frame(maxHeight: .infinity)
                    }

                    footerButtons
                }
            }
            .padding(16)
        }
        .lccWindowPresentation(title: "LCC - Add Events", metrics: LCCLayout.Window.eventEditor)
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
        LCCWindowTopChrome(
            title: "Add Events",
            subtitle: "Schedule an Action to run automatically.",
            systemImage: "calendar.badge.plus",
            iconSize: LCCLayout.Size.smallHeaderIcon,
            titleFont: .title
        )
    }

    // MARK: - Action Card

    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeader(
                title: "Action",
                subtitle: "Choose what this Event will run."
            )

            HStack(alignment: .center, spacing: 12) {
                Picker("Action", selection: $selectedActionID) {
                    ForEach(sortedActions) { action in
                        Text("\(action.name) — \(action.type.rawValue)")
                            .tag(Optional(action.id))
                    }
                }
                .labelsHidden()
                .frame(width: 260, alignment: .leading)

                if let selectedAction {
                    selectedActionSummary(for: selectedAction)
                }

                Spacer(minLength: 0)

                if let selectedAction {
                    actionTypePill(selectedAction.type)
                }
            }
        }
        .padding(10)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func selectedActionSummary(for action: ActionDefinition) -> some View {
        HStack(spacing: 8) {
            Image(systemName: action.type == .show ? "play.fill" : "bolt.fill")
                .font(.caption)
                .foregroundStyle(actionColor(for: action.type))

            Text(actionSummary(for: action))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
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

    // MARK: - When Card

    private var whenCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "When",
                subtitle: repeatsDaily ? "Set the start boundary and the end boundary for this recurring Event." : (appState.use24HourTime ? "Set the date and 24-hour start time." : "Set the date and 12-hour start time.")
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 10) {
                    dateSection
                        .frame(maxWidth: .infinity)

                    timeSection
                        .frame(maxWidth: .infinity)
                }

                if shouldShowRepeatEndControls {
                    Divider()
                        .opacity(0.35)

                    endDateTimeSection
                }
            }
        }
        .padding(10)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var shouldShowRepeatEndControls: Bool {
        repeatsDaily
    }

    private var shouldShowIntervalEndControls: Bool {
        repeatsDaily && repeatMode == .intervalDuringDay
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start Date")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                dateNumberField(
                    label: "Month",
                    value: dateComponentBinding($selectedDate, .month),
                    width: 62
                )

                dateNumberField(
                    label: "Day",
                    value: dateComponentBinding($selectedDate, .day),
                    width: 54
                )

                dateNumberField(
                    label: "Year",
                    value: dateComponentBinding($selectedDate, .year),
                    width: 78
                )

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(dayOfWeekText(for: selectedDate))
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .padding(8)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Time Section

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Start Time")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 10) {
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
        .padding(8)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var endDateTimeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("End Date")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                dateNumberField(
                    label: "Month",
                    value: dateComponentBinding($repeatUntil, .month),
                    width: 62
                )

                dateNumberField(
                    label: "Day",
                    value: dateComponentBinding($repeatUntil, .day),
                    width: 54
                )

                dateNumberField(
                    label: "Year",
                    value: dateComponentBinding($repeatUntil, .year),
                    width: 78
                )

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(dayOfWeekText(for: repeatUntil))
                    .font(.caption)
                    .bold()
                    .foregroundStyle(.secondary)

                Spacer()
            }

            Text("The series may run through the selected End Date.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var intervalEndTimeInput: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("End Time")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 10) {
                timeNumberField(
                    label: "Hour",
                    value: intervalEndHourBinding,
                    range: appState.use24HourTime ? 0...23 : 1...12
                )

                timeNumberField(
                    label: "Minute",
                    value: intervalEndMinuteBinding,
                    range: 0...59
                )

                if appState.use24HourTime == false {
                    meridiemPicker(selection: intervalEndMeridiemBinding)
                }

                Spacer(minLength: 0)
            }

            Text("End Time is inclusive. If the final Event lands exactly on this time, it will run then stop.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(LCCDesign.ColorToken.quietSurface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var meridiemPicker: some View {
        meridiemPicker(selection: $meridiem)
    }

    private func meridiemPicker(selection: Binding<Meridiem>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("AM / PM")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("AM / PM", selection: selection) {
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
            .frame(width: 70)
            .monospacedDigit()
            .onChange(of: value.wrappedValue) { _, newValue in
                value.wrappedValue = clamped(newValue, to: range)
            }
        }
    }

    private func dateNumberField(
        label: String,
        value: Binding<Int>,
        width: CGFloat
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
            .frame(width: width)
            .monospacedDigit()
        }
    }

    private enum DateEditorComponent {
        case month
        case day
        case year
    }

    private func dateComponentBinding(
        _ date: Binding<Date>,
        _ component: DateEditorComponent
    ) -> Binding<Int> {
        Binding<Int> {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day], from: date.wrappedValue)

            switch component {
            case .month:
                return components.month ?? 1
            case .day:
                return components.day ?? 1
            case .year:
                return components.year ?? 2026
            }
        } set: { newValue in
            updateDateComponent(date, component, newValue)
        }
    }

    private func updateDateComponent(
        _ date: Binding<Date>,
        _ component: DateEditorComponent,
        _ newValue: Int
    ) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date.wrappedValue)

        let currentYear = components.year ?? 2026
        let currentMonth = components.month ?? 1

        switch component {
        case .month:
            components.month = clamped(newValue, to: 1...12)
        case .day:
            let maximumDay = daysInMonth(year: currentYear, month: currentMonth)
            components.day = clamped(newValue, to: 1...maximumDay)
        case .year:
            components.year = clamped(newValue, to: 2000...2099)
        }

        let safeYear = components.year ?? currentYear
        let safeMonth = components.month ?? currentMonth
        let maximumDay = daysInMonth(year: safeYear, month: safeMonth)
        components.day = min(max(components.day ?? 1, 1), maximumDay)

        if let updatedDate = calendar.date(from: components) {
            date.wrappedValue = updatedDate
        }
    }

    private func daysInMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month

        let calendar = Calendar.current
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 31
        }

        return range.count
    }

    private var intervalEndHourBinding: Binding<Int> {
        Binding<Int> {
            let hour24 = Calendar.current.component(.hour, from: intervalEndTime)
            return appState.use24HourTime ? hour24 : Self.twelveHour(from: hour24)
        } set: { newValue in
            setIntervalEndTime(hour: newValue)
        }
    }

    private var intervalEndMinuteBinding: Binding<Int> {
        Binding<Int> {
            Calendar.current.component(.minute, from: intervalEndTime)
        } set: { newValue in
            setIntervalEndTime(minute: newValue)
        }
    }

    private var intervalEndMeridiemBinding: Binding<Meridiem> {
        Binding<Meridiem> {
            Calendar.current.component(.hour, from: intervalEndTime) >= 12 ? .pm : .am
        } set: { newValue in
            setIntervalEndTime(meridiem: newValue)
        }
    }

    private func setIntervalEndTime(
        hour: Int? = nil,
        minute: Int? = nil,
        meridiem: Meridiem? = nil
    ) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: intervalEndTime)
        let currentHour24 = components.hour ?? 0
        let selectedMeridiem = meridiem ?? (currentHour24 >= 12 ? .pm : .am)

        if let hour {
            if appState.use24HourTime {
                components.hour = clamped(hour, to: 0...23)
            } else {
                components.hour = Self.twentyFourHour(
                    fromTwelveHour: clamped(hour, to: 1...12),
                    meridiem: selectedMeridiem
                )
            }
        } else if let meridiem {
            components.hour = Self.twentyFourHour(
                fromTwelveHour: Self.twelveHour(from: currentHour24),
                meridiem: meridiem
            )
        }

        if let minute {
            components.minute = clamped(minute, to: 0...59)
        }

        components.second = 0

        if let updatedDate = calendar.date(from: components) {
            intervalEndTime = updatedDate
        }
    }

    private static func twelveHour(from hour24: Int) -> Int {
        let hour = hour24 % 12
        return hour == 0 ? 12 : hour
    }

    private static func twentyFourHour(
        fromTwelveHour hour: Int,
        meridiem: Meridiem
    ) -> Int {
        let normalizedHour = hour == 12 ? 0 : hour
        return meridiem == .pm ? normalizedHour + 12 : normalizedHour
    }

    // MARK: - Repeat Card

    private var repeatCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                sectionHeader(
                    title: "Repeat",
                    subtitle: "Create one Event or a recurring series."
                )

                Toggle("", isOn: $repeatsDaily)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }

            if repeatsDaily {
                repeatOptions
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("This Event will run once at the selected date and time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(12)
                .background(insetPanelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(10)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var repeatOptions: some View {
        VStack(alignment: .leading, spacing: 9) {
            seriesNameField

            repeatSubsection(
                title: "Repeat Days",
                subtitle: "Choose which days can generate Events."
            ) {
                weekdaySelectionGrid
                repeatQuickButtons
                repeatValidationMessage
            }

            repeatSubsection(
                title: "Time Pattern",
                subtitle: "Run once per selected day, or repeat within each selected day."
            ) {
                repeatPatternSection
            }
        }
    }

    private func repeatSubsection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .bold()

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(8)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var seriesNameField: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Series Name")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("ex: Daily Loop or Morning Startup", text: $seriesName)
                .textFieldStyle(.roundedBorder)

            Text("Optional. Can be left blank.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var repeatPatternSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Repeat Every")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        TextField(
                            "Minutes",
                            value: $intervalMinutes,
                            format: .number.grouping(.never)
                        )
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .monospacedDigit()
                        .onChange(of: intervalMinutes) { _, newValue in
                            intervalMinutes = clamped(newValue, to: 1...1_440)
                        }

                        Text("minutes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            intervalPresetButtons
            intervalEndTimeInput

            Text("The End Date is set in the When section above. Daily repeating Events cannot cross midnight in this version.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if intervalCrossesMidnight {
                Label(
                    "Daily repeating Events cannot cross midnight yet. Please create a second Event series for the next day.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(LCCDesign.ColorToken.warning)
            }
        }
        .padding(10)
        .background(LCCDesign.ColorToken.quietSurface)
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
        HStack(spacing: 8) {
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
                .foregroundStyle(LCCDesign.ColorToken.error)
        }
    }

    private var repeatUntilPicker: some View {
        VStack(alignment: .leading, spacing: 7) {
            DatePicker(
                "Series End Date",
                selection: $repeatUntil,
                displayedComponents: [.date]
            )

            Text("The series may run through this date. For interval repeats, the daily End Time controls the last run within each selected day.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
        .foregroundStyle(isSelected ? LCCDesign.ColorToken.active : Color.secondary)
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

    // MARK: - Validation

    private var validationIssues: [EventScheduleValidationIssue] {
        var issues: [EventScheduleValidationIssue] = []

        if selectedActionID == nil {
            issues.append(.error("Choose an Action before saving this Event."))
        }

        guard repeatsDaily else {
            return issues
        }

        if repeatWeekdays.isEmpty {
            issues.append(.error("Select at least one repeat day."))
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: composedStartDate())
        let endDay = calendar.startOfDay(for: repeatUntil)

        if endDay < startDay {
            issues.append(.error("End Date must be on or after the Start Date."))
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

    private var validationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Schedule Check",
                subtitle: "Review warnings and fix errors before saving."
            )

            VStack(alignment: .leading, spacing: 7) {
                ForEach(validationIssues) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: issue.severity.systemImageName)
                            .font(.caption)
                            .foregroundStyle(issue.severity.color)
                            .frame(width: 16)

                        Text(issue.message)
                            .font(.caption)
                            .foregroundStyle(issue.severity.color)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(10)
            .background(insetPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(10)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    previewAuditSummary
                    previewOccurrenceList
                }
            }
        }
        .padding(10)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var previewAuditSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: repeatsDaily ? "rectangle.stack" : "calendar")
                    .font(.caption)
                    .foregroundStyle(repeatsDaily ? LCCDesign.ColorToken.active : .secondary)

                Text(previewSummaryTitle)
                    .font(.caption)
                    .bold()

                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                previewSummaryLine("Schedule", previewScheduleDescription)
                previewSummaryLine("Generated Events", previewTotalCountText)
                previewSummaryLine("First Occurrence", previewFirstOccurrenceText)
                previewSummaryLine("Last Occurrence", previewLastOccurrenceText)

                if repeatsDaily {
                    previewSummaryLine("Selected Days", ScheduleEntryFormatter.weekdaySummary(for: repeatWeekdays))
                    previewSummaryLine("Per Selected Day", previewOccurrencesPerActiveDayText)
                }

                if repeatsDaily && repeatMode == .intervalDuringDay {
                    previewSummaryLine("Daily Final Run", previewDailyFinalRunText)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(insetPanelBackground)
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
                .font(.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private var previewOccurrenceList: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Next Generated Events")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)

            if previewOccurrences.isEmpty {
                Text("No occurrences are generated by these settings.")
                    .font(.caption)
                    .foregroundStyle(LCCDesign.ColorToken.warning)
            } else {
                ForEach(previewOccurrences, id: \.timeIntervalSince1970) { occurrenceDate in
                    HStack(spacing: 8) {
                        Image(systemName: repeatsDaily ? "rectangle.stack" : "calendar")
                            .font(.caption)
                            .foregroundStyle(repeatsDaily ? LCCDesign.ColorToken.active : .secondary)

                        Text(Self.previewFormatter.string(from: occurrenceDate))
                            .font(.caption)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var previewSubtitle: String {
        if repeatsDaily {
            return "Audits the generated series before it is added to the calendar."
        }

        return "This Event will run once."
    }

    private var previewSummaryTitle: String {
        if repeatsDaily {
            return cleanedSeriesName ?? selectedAction?.name ?? "Recurring Series"
        }

        return selectedAction?.name ?? "One-time Event"
    }

    private var previewScheduleDescription: String {
        guard let previewEvent = makePreviewEvent() else {
            return "Incomplete schedule."
        }

        return ScheduleEntryFormatter.repeatSummary(
            for: previewEvent,
            oneTimeText: "One-time",
            includeRepeatUntil: true
        )
    }

    private var previewTotalCountText: String {
        guard let previewEvent = makePreviewEvent() else {
            return "—"
        }

        if previewEvent.repeatsDaily, previewEvent.repeatUntil == nil {
            return "Open-ended; showing upcoming Events"
        }

        let count = previewTotalOccurrenceCount
        return "\(count) Event\(count == 1 ? "" : "s")"
    }

    private var previewFirstOccurrenceText: String {
        guard let previewEvent = makePreviewEvent(),
              let first = generatedPreviewOccurrences(for: previewEvent, limit: 1).first else {
            return "—"
        }

        return Self.previewFormatter.string(from: first)
    }

    private var previewLastOccurrenceText: String {
        guard let previewEvent = makePreviewEvent() else {
            return "—"
        }

        if previewEvent.repeatsDaily, previewEvent.repeatUntil == nil {
            return "Open-ended"
        }

        let occurrences = generatedPreviewOccurrences(for: previewEvent, limit: 10_000)
        guard let last = occurrences.last else {
            return "—"
        }

        return Self.previewFormatter.string(from: last)
    }

    private var previewOccurrencesPerActiveDayText: String {
        guard let previewEvent = makePreviewEvent() else {
            return "—"
        }

        let count = previewOccurrencesPerActiveDay(for: previewEvent)
        return "\(count) Event\(count == 1 ? "" : "s")"
    }

    private var previewDailyFinalRunText: String {
        guard let previewEvent = makePreviewEvent(),
              let finalRun = firstActiveDayOccurrences(for: previewEvent).last else {
            return "No daily occurrence generated."
        }

        return Self.previewTimeFormatter.string(from: finalRun)
    }

    private var previewOccurrences: [Date] {
        guard let previewEvent = makePreviewEvent() else {
            return []
        }

        return generatedPreviewOccurrences(
            for: previewEvent,
            limit: 25
        )
    }

    private var previewTotalOccurrenceCount: Int {
        guard let previewEvent = makePreviewEvent() else {
            return 0
        }

        return generatedPreviewOccurrences(
            for: previewEvent,
            limit: 10_000
        ).count
    }

    private func previewOccurrencesPerActiveDay(for previewEvent: ScheduleEntry) -> Int {
        firstActiveDayOccurrences(for: previewEvent).count
    }

    private func firstActiveDayOccurrences(for previewEvent: ScheduleEntry) -> [Date] {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: previewEvent.startDate)
        let finalDay = calendar.startOfDay(for: previewEvent.repeatUntil ?? Self.previewOpenEndedDate(from: previewEvent.startDate))
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
        if previewEvent.repeatsDaily == false {
            return [previewEvent.startDate]
        }

        let calendar = Calendar.current
        var occurrences: [Date] = []
        var day = calendar.startOfDay(for: previewEvent.startDate)
        let finalDay = calendar.startOfDay(for: previewEvent.repeatUntil ?? Self.previewOpenEndedDate(from: previewEvent.startDate))
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
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private static func previewOpenEndedDate(from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 370, to: date) ?? date
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

    private static let previewTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
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
        LCCDesign.actionColor(for: type)
    }

    // MARK: - Styling

    private var background: some View {
        LinearGradient(
            colors: [
                LCCDesign.ColorToken.windowBackground,
                LCCDesign.ColorToken.controlBackground.opacity(0.58)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LCCDesign.ColorToken.controlBackground.opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }

    private var insetPanelBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LCCDesign.ColorToken.textBackground.opacity(0.18))
    }

    private func weekdayButtonBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(
                isSelected
                    ? LCCDesign.selectedFill()
                    : LCCDesign.ColorToken.textBackground.opacity(0.18)
            )
    }

    private func weekdayButtonBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(
                isSelected
                    ? LCCDesign.selectedStroke()
                    : LCCDesign.ColorToken.standardBorder,
                lineWidth: 1
            )
    }
}

// MARK: - Validation Issue

private struct EventScheduleValidationIssue: Identifiable, Equatable {
    enum Severity: Equatable {
        case error
        case warning

        var color: Color {
            switch self {
            case .error:
                return LCCDesign.ColorToken.error

            case .warning:
                return LCCDesign.ColorToken.warning
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

    static func error(_ message: String) -> EventScheduleValidationIssue {
        EventScheduleValidationIssue(severity: .error, message: message)
    }

    static func warning(_ message: String) -> EventScheduleValidationIssue {
        EventScheduleValidationIssue(severity: .warning, message: message)
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

