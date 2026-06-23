//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ActionEditorView.swift
//  Purpose: Edits reusable Show and Utility Actions.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI

struct ActionEditorView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Properties

    let actionID: UUID

    // MARK: - Derived State

    private var actionIndex: Int? {
        appState.actionDefinitions.firstIndex {
            $0.id == actionID
        }
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let index = actionIndex {
                VStack(alignment: .leading, spacing: LCCLayout.Actions.editorContentSpacing) {
                    editorHeader(index: index)

                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: LCCLayout.Actions.editorContentSpacing) {
                            actionDetailsCard(index: index)

                            switch appState.actionDefinitions[index].type {
                            case .show:
                                showStepsSection(index: index)

                            case .utility:
                                utilityStepsSection(index: index)
                            }
                        }
                        .padding(.trailing, LCCLayout.Actions.editorScrollTrailingPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                missingActionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private func editorHeader(index: Int) -> some View {
        let action = appState.actionDefinitions[index]

        return HStack(alignment: .top, spacing: 12) {
            LCCSidebarHeader(
                title: "Edit Action",
                subtitle: action.type == .show ? "Show Action · Message steps" : "Utility Action · Dashboard automation",
                systemImage: "pencil",
                iconColor: LCCDesign.ColorToken.active
            )

            Spacer()

            Button {
                appState.runAction(appState.actionDefinitions[index])
            } label: {
                Label("Run Now", systemImage: "play.fill")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(actionHasNoSteps(index: index))
        }
    }

    // MARK: - Action Details

    private func actionDetailsCard(index: Int) -> some View {
        let action = appState.actionDefinitions[index]

        return VStack(alignment: .leading, spacing: 14) {
            stepCardHeader(
                iconName: actionIconName(for: action.type),
                iconColor: actionColor(for: action.type),
                title: "Action",
                subtitle: "Manual runs ignore schedule enable/disable toggles."
            ) {
                EmptyView()
            }

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField(
                        "Action Name",
                        text: $appState.actionDefinitions[index].name
                    )
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker(
                        "",
                        selection: $appState.actionDefinitions[index].type
                    ) {
                        ForEach(ActionType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: LCCLayout.Actions.typePickerWidth)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $appState.actionDefinitions[index].notes)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: 72, maxHeight: 96)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LCCDesign.ColorToken.textBackground.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
                    )

                Text("Optional notes for operators, reminders, or context. Not shown elsewhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            actionRuntimeLimitNotice
        }
        .padding(14)
        .background(editorCardBackground)
        .overlay(editorCardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var actionRuntimeLimitNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text("Reliability limit: total Action runtime cannot exceed 2 minutes. This includes all step delays and any Utility steps that run another Action.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func actionHasNoSteps(index: Int) -> Bool {
        switch appState.actionDefinitions[index].type {
        case .show:
            return appState.actionDefinitions[index].commands.isEmpty

        case .utility:
            return appState.actionDefinitions[index].utilityCommands.isEmpty
        }
    }

    // MARK: - Show / Message Steps

    private func showStepsSection(index: Int) -> some View {
        stepsShell(
            title: "Message Steps",
            subtitle: "\(appState.actionDefinitions[index].commands.count) configured",
            addButtonTitle: "Add Message Step",
            addSystemImage: "plus",
            addAction: {
                addMessageStep(to: index)
            }
        ) {
            if appState.actionDefinitions[index].commands.isEmpty {
                emptyStepsView(
                    systemImage: "network",
                    title: "No Message Steps",
                    message: "Add a Message Step to send Standard UDP or Syslog messages when this Show Action runs."
                )
            } else {
                ForEach(
                    Array($appState.actionDefinitions[index].commands.enumerated()),
                    id: \.element.id
                ) { stepIndex, $command in
                    messageStepCard(
                        actionIndex: index,
                        stepIndex: stepIndex,
                        command: $command
                    )
                }
            }
        }
    }

    private func messageStepCard(
        actionIndex: Int,
        stepIndex: Int,
        command: Binding<UDPCommand>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            stepCardHeader(
                iconName: "paperplane.fill",
                iconColor: LCCDesign.ColorToken.active,
                title: "Message Step \(stepIndex + 1)",
                subtitle: command.wrappedValue.name
            ) {
                HStack(spacing: LCCLayout.Actions.delaySendButtonSpacing) {
                    inlineDelayField(delaySeconds: command.delaySeconds)

                    Button {
                        appState.runSingleCommand(command.wrappedValue)
                    } label: {
                        Label("Send Step", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                labeledTextField(
                    label: "Step Name",
                    placeholder: "Step Name",
                    text: command.name
                )

                messageTypePicker(command: command)
            }

            messageStepConfiguration(command: command)

            stepMoveDeleteControls(
                moveUpDisabled: stepIndex == 0,
                moveDownDisabled: stepIndex == appState.actionDefinitions[actionIndex].commands.count - 1,
                moveUp: {
                    moveMessageStepUp(
                        actionIndex: actionIndex,
                        stepIndex: stepIndex
                    )
                },
                moveDown: {
                    moveMessageStepDown(
                        actionIndex: actionIndex,
                        stepIndex: stepIndex
                    )
                },
                delete: {
                    deleteMessageStep(
                        commandID: command.wrappedValue.id,
                        actionIndex: actionIndex
                    )
                }
            )
        }
        .padding(14)
        .background(stepCardBackground)
        .overlay(stepCardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func messageTypePicker(command: Binding<UDPCommand>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Message Type")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: command.messageType) {
                ForEach(MessageStepType.allCases) { messageType in
                    Text(messageType.rawValue).tag(messageType)
                }
            }
            .labelsHidden()
            .frame(width: 180)
        }
    }

    @ViewBuilder
    private func messageStepConfiguration(command: Binding<UDPCommand>) -> some View {
        switch command.wrappedValue.messageType {
        case .standardUDP:
            standardUDPConfiguration(command: command)

        case .syslog:
            syslogConfiguration(command: command)
        }
    }

    private func standardUDPConfiguration(command: Binding<UDPCommand>) -> some View {
        HStack(alignment: .top, spacing: LCCLayout.Actions.messageFieldSpacing) {
            labeledTextField(
                label: "Destination IP Address",
                placeholder: "127.0.0.1",
                text: command.host
            )
            .frame(width: LCCLayout.Actions.ipAddressFieldWidth)

            labeledIntegerField(
                label: "Port",
                value: command.port,
                width: LCCLayout.Actions.portFieldWidth
            )

            labeledTextField(
                label: "UDP Message",
                placeholder: "UDP Message",
                text: command.message
            )
            .frame(maxWidth: .infinity)
        }
    }

    private func syslogConfiguration(command: Binding<UDPCommand>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: LCCLayout.Actions.messageFieldSpacing) {
                labeledTextField(
                    label: "Destination IP Address",
                    placeholder: "127.0.0.1",
                    text: command.host
                )
                .frame(width: LCCLayout.Actions.ipAddressFieldWidth)

                labeledIntegerField(
                    label: "Port",
                    value: command.port,
                    width: LCCLayout.Actions.portFieldWidth
                )

                syslogSeverityPicker(severity: command.syslogSeverity)

                labeledTextField(
                    label: "Syslog Message",
                    placeholder: "Syslog Message",
                    text: command.message
                )
                .frame(maxWidth: .infinity)
            }

            syslogPreview(command: command.wrappedValue)
        }
    }

    private func syslogSeverityPicker(severity: Binding<SyslogSeverity>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Severity")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: severity) {
                ForEach(SyslogSeverity.allCases) { severity in
                    Text(severity.rawValue).tag(severity)
                }
            }
            .labelsHidden()
            .frame(width: LCCLayout.Actions.severityFieldWidth)
        }
    }

    private func syslogPreview(command: UDPCommand) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Generated Syslog Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                SyslogMessageFormatter.formattedMessage(
                    severity: command.syslogSeverity,
                    deviceName: appState.syslogDeviceName,
                    message: command.message
                )
            )
            .font(.system(.caption, design: .monospaced))
            .lineLimit(2)
            .truncationMode(.middle)
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(insetPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    // MARK: - Utility Steps

    private func utilityStepsSection(index: Int) -> some View {
        stepsShell(
            title: "Utility Steps",
            subtitle: "\(appState.actionDefinitions[index].utilityCommands.count) configured",
            addButtonTitle: "Add Utility Step",
            addSystemImage: "plus",
            addAction: {
                addUtilityStep(to: index)
            }
        ) {
            if appState.actionDefinitions[index].utilityCommands.isEmpty {
                emptyStepsView(
                    systemImage: "bolt",
                    title: "No Utility Steps",
                    message: "Add a Utility Step to control Dashboard functions or run another Action."
                )
            } else {
                ForEach(
                    Array($appState.actionDefinitions[index].utilityCommands.enumerated()),
                    id: \.element.id
                ) { stepIndex, $command in
                    utilityStepCard(
                        actionIndex: index,
                        stepIndex: stepIndex,
                        command: $command
                    )
                }
            }
        }
    }

    private func utilityStepCard(
        actionIndex: Int,
        stepIndex: Int,
        command: Binding<UtilityCommand>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            stepCardHeader(
                iconName: iconName(for: command.wrappedValue.kind),
                iconColor: LCCDesign.ColorToken.utilityAction,
                title: "Utility Step \(stepIndex + 1)",
                subtitle: command.wrappedValue.kind.rawValue
            ) {
                inlineDelayField(delaySeconds: command.delaySeconds)
            }

            HStack(alignment: .top, spacing: 12) {
                labeledTextField(
                    label: "Step Name",
                    placeholder: "Step Name",
                    text: command.name
                )

                compactStepTypePicker(command: command)
            }

            utilityCommandConfiguration(
                parentActionIndex: actionIndex,
                command: command
            )

            stepMoveDeleteControls(
                moveUpDisabled: stepIndex == 0,
                moveDownDisabled: stepIndex == appState.actionDefinitions[actionIndex].utilityCommands.count - 1,
                moveUp: {
                    moveUtilityStepUp(
                        actionIndex: actionIndex,
                        stepIndex: stepIndex
                    )
                },
                moveDown: {
                    moveUtilityStepDown(
                        actionIndex: actionIndex,
                        stepIndex: stepIndex
                    )
                },
                delete: {
                    deleteUtilityStep(
                        commandID: command.wrappedValue.id,
                        actionIndex: actionIndex
                    )
                }
            )
        }
        .padding(14)
        .background(stepCardBackground)
        .overlay(stepCardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func compactStepTypePicker(command: Binding<UtilityCommand>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Step Type")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("", selection: command.kind) {
                ForEach(UtilityCommandKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .labelsHidden()
            .frame(width: 220)
        }
    }

    @ViewBuilder
    private func utilityCommandConfiguration(
        parentActionIndex: Int,
        command: Binding<UtilityCommand>
    ) -> some View {
        switch command.wrappedValue.kind {
        case .setVolume:
            volumeUtilityConfiguration(command: command)

        case .setShowScheduleEnabled:
            schedulePickerPanel(
                title: "Show Schedule",
                subtitle: "Controls scheduled Show Actions only.",
                selection: command.showScheduleEnabled
            )

        case .setUtilityScheduleEnabled:
            schedulePickerPanel(
                title: "Utility Schedule",
                subtitle: "Controls scheduled Utility Actions only.",
                selection: command.utilityScheduleEnabled
            )

        case .runAction:
            runActionPickerPanel(
                parentActionIndex: parentActionIndex,
                command: command
            )

        case .sendUDP:
            utilityUDPConfiguration(command: command)
        }
    }

    // MARK: - Utility Configuration Panels

    private func volumeUtilityConfiguration(command: Binding<UtilityCommand>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Playback Level")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(command.wrappedValue.volumeLevel * 100))%")
                    .font(.headline)
                    .monospacedDigit()
            }

            Slider(
                value: command.volumeLevel,
                in: 0...1
            )

            HStack(spacing: 8) {
                volumePresetButton(
                    title: "Mute",
                    level: 0,
                    command: command
                )

                volumePresetButton(
                    title: "Low",
                    level: appState.lowVolumeLevel,
                    command: command
                )

                volumePresetButton(
                    title: "Normal",
                    level: appState.normalVolumeLevel,
                    command: command
                )

                volumePresetButton(
                    title: "High",
                    level: appState.highVolumeLevel,
                    command: command
                )
            }
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func utilityUDPConfiguration(command: Binding<UtilityCommand>) -> some View {
        HStack(alignment: .top, spacing: LCCLayout.Actions.messageFieldSpacing) {
            labeledTextField(
                label: "Destination IP Address",
                placeholder: "127.0.0.1",
                text: command.udpHost
            )
            .frame(width: LCCLayout.Actions.ipAddressFieldWidth)

            labeledIntegerField(
                label: "Port",
                value: command.udpPort,
                width: LCCLayout.Actions.portFieldWidth
            )

            labeledTextField(
                label: "UDP Message",
                placeholder: "UDP Message",
                text: command.udpMessage
            )
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func volumePresetButton(
        title: String,
        level: Double,
        command: Binding<UtilityCommand>
    ) -> some View {
        let isSelected = abs(command.wrappedValue.volumeLevel - level) < 0.005

        return Button {
            command.wrappedValue.volumeLevel = level
        } label: {
            Text(title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    isSelected
                        ? LCCDesign.ColorToken.active.opacity(0.25)
                        : LCCDesign.ColorToken.textBackground.opacity(0.18)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? LCCDesign.ColorToken.active.opacity(0.5)
                        : LCCDesign.ColorToken.standardBorder,
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func schedulePickerPanel(
        title: String,
        subtitle: String,
        selection: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("", selection: selection) {
                Text("Enable").tag(true)
                Text("Disable").tag(false)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func runActionPickerPanel(
        parentActionIndex: Int,
        command: Binding<UtilityCommand>
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Action to Run")
                    .font(.subheadline)
                    .bold()

                Text("Runs as a manual Action.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Action to Run", selection: command.actionDefinitionID) {
                Text("Choose Action")
                    .tag(Optional<UUID>.none)

                ForEach(runActionChoices(parentActionIndex: parentActionIndex)) { action in
                    Text("\(action.name) — \(action.type.rawValue)")
                        .tag(Optional(action.id))
                }
            }
            .labelsHidden()
            .frame(width: 260)
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func runActionChoices(parentActionIndex: Int) -> [ActionDefinition] {
        let parentActionID = appState.actionDefinitions[parentActionIndex].id

        return appState.actionDefinitions
            .filter {
                $0.id != parentActionID
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    // MARK: - Steps Shell

    private func stepsShell<Content: View>(
        title: String,
        subtitle: String,
        addButtonTitle: String,
        addSystemImage: String,
        addAction: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    addAction()
                } label: {
                    Label(addButtonTitle, systemImage: addSystemImage)
                }
                .buttonStyle(.bordered)
            }

            LazyVStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(.vertical, 2)
        }
    }

    private func emptyStepsView(
        systemImage: String,
        title: String,
        message: String
    ) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .padding(20)
        .background(stepCardBackground)
        .overlay(stepCardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Shared Step Header / Controls

    private func stepCardHeader<Trailing: View>(
        iconName: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(
                        width: LCCLayout.Actions.stepHeaderIconSize,
                        height: LCCLayout.Actions.stepHeaderIconSize
                    )

                Image(systemName: iconName)
                    .font(.system(size: LCCLayout.Actions.stepHeaderIconSymbolSize, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)

                Text(subtitle.isEmpty ? "Unnamed Step" : subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            trailing()
        }
    }

    private func inlineDelayField(delaySeconds: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text("Delay")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "0",
                value: delaySeconds,
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 68)

            Text("sec")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func stepMoveDeleteControls(
        moveUpDisabled: Bool,
        moveDownDisabled: Bool,
        moveUp: @escaping () -> Void,
        moveDown: @escaping () -> Void,
        delete: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Spacer()

            Button {
                moveUp()
            } label: {
                Label("Move Up", systemImage: "chevron.up")
            }
            .labelStyle(.iconOnly)
            .disabled(moveUpDisabled)

            Button {
                moveDown()
            } label: {
                Label("Move Down", systemImage: "chevron.down")
            }
            .labelStyle(.iconOnly)
            .disabled(moveDownDisabled)

            Button(role: .destructive) {
                delete()
            } label: {
                Label("Delete Step", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
        }
    }

    // MARK: - Field Helpers

    private func labeledTextField(
        label: String,
        placeholder: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func labeledIntegerField(
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
        }
    }

    // MARK: - Missing Action

    private var missingActionView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Action Not Found")
                .font(.title2)
                .bold()

            Text("The selected Action may have been deleted.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Colors / Icons

    private func actionColor(for type: ActionType) -> Color {
        LCCDesign.actionColor(for: type)
    }

    private func actionIconName(for type: ActionType) -> String {
        switch type {
        case .show:
            return "play.fill"

        case .utility:
            return "bolt.fill"
        }
    }

    private func iconName(for kind: UtilityCommandKind) -> String {
        switch kind {
        case .setVolume:
            return "speaker.wave.2.fill"

        case .setShowScheduleEnabled:
            return "play.rectangle.fill"

        case .setUtilityScheduleEnabled:
            return "bolt.fill"

        case .runAction:
            return "arrow.triangle.2.circlepath"

        case .sendUDP:
            return "paperplane.fill"
        }
    }

    // MARK: - Styling

    private var editorBackground: some View {
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

    private var editorCardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LCCDesign.ColorToken.controlBackground.opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var editorCardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }

    private var stepCardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LCCDesign.ColorToken.controlBackground.opacity(0.62))
            .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 3)
    }

    private var stepCardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }

    private var insetPanelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LCCDesign.ColorToken.textBackground.opacity(0.18))
    }

    // MARK: - Message Step Actions

    private func addMessageStep(to actionIndex: Int) {
        let step = UDPCommand(
            messageType: .standardUDP,
            name: "New Message Step",
            host: appState.defaultDestinationHost,
            port: appState.defaultDestinationPort,
            message: "",
            syslogSeverity: .info,
            delaySeconds: 0
        )

        appState.actionDefinitions[actionIndex].commands.append(step)
    }

    private func deleteMessageStep(commandID: UUID, actionIndex: Int) {
        appState.actionDefinitions[actionIndex]
            .commands
            .removeAll {
                $0.id == commandID
            }
    }

    private func moveMessageStepUp(actionIndex: Int, stepIndex: Int) {
        guard stepIndex > 0 else {
            return
        }

        appState.actionDefinitions[actionIndex]
            .commands
            .swapAt(stepIndex, stepIndex - 1)
    }

    private func moveMessageStepDown(actionIndex: Int, stepIndex: Int) {
        let lastIndex = appState.actionDefinitions[actionIndex].commands.count - 1

        guard stepIndex < lastIndex else {
            return
        }

        appState.actionDefinitions[actionIndex]
            .commands
            .swapAt(stepIndex, stepIndex + 1)
    }

    // MARK: - Utility Step Actions

    private func addUtilityStep(to actionIndex: Int) {
        var step = UtilityCommand()
        step.name = "New Utility Step"
        step.kind = .setVolume
        step.volumeLevel = appState.volumeLevel
        step.udpHost = appState.defaultDestinationHost
        step.udpPort = appState.defaultDestinationPort
        step.delaySeconds = 0

        appState.actionDefinitions[actionIndex].utilityCommands.append(step)
    }

    private func deleteUtilityStep(commandID: UUID, actionIndex: Int) {
        appState.actionDefinitions[actionIndex]
            .utilityCommands
            .removeAll {
                $0.id == commandID
            }
    }

    private func moveUtilityStepUp(actionIndex: Int, stepIndex: Int) {
        guard stepIndex > 0 else {
            return
        }

        appState.actionDefinitions[actionIndex]
            .utilityCommands
            .swapAt(stepIndex, stepIndex - 1)
    }

    private func moveUtilityStepDown(actionIndex: Int, stepIndex: Int) {
        let lastIndex = appState.actionDefinitions[actionIndex].utilityCommands.count - 1

        guard stepIndex < lastIndex else {
            return
        }

        appState.actionDefinitions[actionIndex]
            .utilityCommands
            .swapAt(stepIndex, stepIndex + 1)
    }
}
