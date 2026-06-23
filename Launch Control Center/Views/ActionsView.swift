//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: ActionsView.swift
//  Purpose: Lists reusable Show and Utility Actions for editing.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI

struct ActionsView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - State

    @State private var selectedActionID: UUID?

    // MARK: - Filtered Actions

    private var showActions: [ActionDefinition] {
        appState.actionDefinitions
            .filter { $0.type == .show }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private var utilityActions: [ActionDefinition] {
        appState.actionDefinitions
            .filter { $0.type == .utility }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            sidebarBackground

            VStack(alignment: .leading, spacing: 14) {
                header
                    .padding(.horizontal, 18)
                    .padding(.top, 16)

                HStack(alignment: .top, spacing: LCCLayout.Actions.columnSpacing) {
                    sidebar
                        .frame(width: LCCLayout.Actions.libraryColumnWidth)

                    detailPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .lccWindowPresentation(title: "LCC - Define Actions", metrics: LCCLayout.Window.actions)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: LCCLayout.Actions.sectionSpacing) {
            sidebarHeader
            createButtons
            actionList
                .frame(maxHeight: .infinity)
        }
        .padding(LCCLayout.Actions.columnPadding)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: LCCLayout.Actions.columnCornerRadius, style: .continuous)
                .fill(LCCDesign.ColorToken.controlBackground.opacity(LCCLayout.Actions.columnBackgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: LCCLayout.Actions.columnCornerRadius, style: .continuous)
                .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: LCCLayout.Actions.columnBorderWidth)
        )
    }

    private var header: some View {
        LCCWindowTopChrome(
            title: "Define Actions",
            subtitle: "Create Show and Utility Actions for manual or scheduled playback.",
            systemImage: "rectangle.stack.badge.play"
        )
    }

    private var sidebarHeader: some View {
        LCCSidebarHeader(
            title: "Action Library",
            subtitle: "\(appState.actionDefinitions.count) total",
            systemImage: "filemenu.and.selection",
            iconColor: LCCDesign.ColorToken.active
        )
    }

    private var createButtons: some View {
        HStack(spacing: 10) {
            Button {
                addShowAction()
            } label: {
                Label("New Show", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                addUtilityAction()
            } label: {
                Label("New Utility", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Action List

    private var actionList: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 16) {
                actionSection(
                    title: "Shows",
                    subtitle: "\(showActions.count) defined",
                    actions: showActions,
                    emptyMessage: "No Show Actions defined."
                )

                actionSection(
                    title: "Utilities",
                    subtitle: "\(utilityActions.count) defined",
                    actions: utilityActions,
                    emptyMessage: "No Utility Actions defined."
                )
            }
            .padding(.vertical, 2)
        }
    }

    private func actionSection(
        title: String,
        subtitle: String,
        actions: [ActionDefinition],
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)

                Spacer()

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if actions.isEmpty {
                emptyState(emptyMessage)
            } else {
                VStack(spacing: 8) {
                    ForEach(actions) { action in
                        actionRow(action)
                    }
                }
            }
        }
    }

    private func actionRow(_ action: ActionDefinition) -> some View {
        Button {
            selectedActionID = action.id
        } label: {
            HStack(alignment: .center, spacing: 12) {
                actionIcon(for: action)

                VStack(alignment: .leading, spacing: 4) {
                    Text(action.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(stepCountText(for: action))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Text(usageText(for: action))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if selectedActionID == action.id {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            rowBackground(isSelected: selectedActionID == action.id)
        )
        .overlay(
            rowBorder(isSelected: selectedActionID == action.id)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button("Delete Action", role: .destructive) {
                deleteAction(action)
            }
        }
    }

    // MARK: - Detail

    private var detailPanel: some View {
        detailView
            .padding(LCCLayout.Actions.columnPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: LCCLayout.Actions.columnCornerRadius, style: .continuous)
                    .fill(LCCDesign.ColorToken.controlBackground.opacity(LCCLayout.Actions.columnBackgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: LCCLayout.Actions.columnCornerRadius, style: .continuous)
                    .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: LCCLayout.Actions.columnBorderWidth)
            )
            .clipShape(RoundedRectangle(cornerRadius: LCCLayout.Actions.columnCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var detailView: some View {
        if let selectedActionID {
            ActionEditorView(actionID: selectedActionID)
                .environmentObject(appState)
        } else {
            emptyDetailView
        }
    }

    private var emptyDetailView: some View {
        ZStack {
            LCCEmptyStateView(
                title: "Select an Action",
                message: "Choose an Action from the Action Library or create a new one.",
                systemImage: "pencil"
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Create Actions

    private func addShowAction() {
        let command = UDPCommand(
            name: "Primary Command",
            host: appState.defaultDestinationHost,
            port: appState.defaultDestinationPort,
            message: "RUN_SHOW",
            delaySeconds: 0
        )

        let action = ActionDefinition(
            name: "Show Action",
            type: .show,
            commands: [command],
            utilityCommands: []
        )

        appState.actionDefinitions.append(action)
        selectedActionID = action.id
    }

    private func addUtilityAction() {
        var utilityCommand = UtilityCommand()
        utilityCommand.name = "Set Playback Level"
        utilityCommand.kind = .setVolume
        utilityCommand.volumeLevel = appState.volumeLevel
        utilityCommand.delaySeconds = 0

        let action = ActionDefinition(
            name: "Utility Action",
            type: .utility,
            commands: [],
            utilityCommands: [utilityCommand]
        )

        appState.actionDefinitions.append(action)
        selectedActionID = action.id
    }

    // MARK: - Delete Actions

    private func deleteAction(_ action: ActionDefinition) {
        appState.actionDefinitions.removeAll {
            $0.id == action.id
        }

        if selectedActionID == action.id {
            selectedActionID = nil
        }
    }

    // MARK: - Action Metadata

    private func eventUsageCount(for action: ActionDefinition) -> Int {
        appState.scheduleEntries
            .filter {
                $0.actionDefinitionID == action.id
            }
            .count
    }

    private func stepCountText(for action: ActionDefinition) -> String {
        switch action.type {
        case .show:
            return "\(action.commands.count) UDP step\(action.commands.count == 1 ? "" : "s")"

        case .utility:
            return "\(action.utilityCommands.count) utility step\(action.utilityCommands.count == 1 ? "" : "s")"
        }
    }

    private func usageText(for action: ActionDefinition) -> String {
        let count = eventUsageCount(for: action)
        return "Used by \(count) Event\(count == 1 ? "" : "s")"
    }

    // MARK: - Icons

    private func actionIcon(for action: ActionDefinition) -> some View {
        ZStack {
            Circle()
                .fill(actionColor(for: action).opacity(0.18))
                .frame(width: 32, height: 32)

            Image(systemName: action.type == .show ? "play.fill" : "bolt.fill")
                .font(.caption)
                .foregroundStyle(actionColor(for: action))
        }
    }

    private func actionColor(for action: ActionDefinition) -> Color {
        LCCDesign.actionColor(for: action.type)
    }

    // MARK: - Empty State

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LCCDesign.ColorToken.controlBackground.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
            )
    }

    // MARK: - Styling

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                LCCDesign.ColorToken.windowBackground,
                LCCDesign.ColorToken.controlBackground.opacity(0.65)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected
                    ? LCCDesign.ColorToken.active.opacity(0.22)
                    : LCCDesign.ColorToken.controlBackground.opacity(0.62)
            )
    }

    private func rowBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                isSelected
                    ? LCCDesign.selectedStroke()
                    : LCCDesign.ColorToken.standardBorder,
                lineWidth: 1
            )
    }
}
