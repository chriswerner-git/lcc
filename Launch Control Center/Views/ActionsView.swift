//
//  ActionsView.swift
//  Launch Control Center
//
//  Lists reusable Actions.
//  Actions are grouped by type and sorted alphabetically.
//
//  Show Actions contain UDP Steps.
//  Utility Actions contain dashboard-level Utility Steps.
//

import SwiftUI

struct ActionsView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedActionID: UUID?

    private var showActions: [ActionDefinition] {
        appState.actionDefinitions
            .filter { $0.type == .show }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var utilityActions: [ActionDefinition] {
        appState.actionDefinitions
            .filter { $0.type == .utility }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
        } detail: {
            detailView
        }
        .frame(width: 980, height: 720)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ZStack {
            sidebarBackground

            VStack(alignment: .leading, spacing: 16) {
                header

                createButtons

                actionList
            }
            .padding(18)
        }
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.65)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Actions")
                .font(.largeTitle)
                .bold()

            Text("\(appState.actionDefinitions.count) total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var createButtons: some View {
        HStack(spacing: 10) {
            Button {
                addShowAction()
            } label: {
                Label("New Show", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                addUtilityAction()
            } label: {
                Label("New Utility", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

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

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
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
        .background(rowBackground(isSelected: selectedActionID == action.id))
        .overlay(rowBorder(isSelected: selectedActionID == action.id))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button("Delete Action", role: .destructive) {
                deleteAction(action)
            }
        }
    }

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

    private func rowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                isSelected
                    ? Color.accentColor.opacity(0.22)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.62)
            )
    }

    private func rowBorder(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(
                isSelected ? Color.accentColor.opacity(0.45) : Color.white.opacity(0.08),
                lineWidth: 1
            )
    }

    private func actionColor(for action: ActionDefinition) -> Color {
        switch action.type {
        case .show:
            return .blue

        case .utility:
            return .purple
        }
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

    // MARK: - Detail

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
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: "rectangle.stack.badge.play")
                    .font(.system(size: 44, weight: .regular))
                    .foregroundStyle(.secondary)

                Text("Select an Action")
                    .font(.title2)
                    .bold()

                Text("Choose an Action from the sidebar or create a new one.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func eventUsageCount(for action: ActionDefinition) -> Int {
        appState.scheduleEntries.filter {
            $0.actionDefinitionID == action.id
        }
        .count
    }

    private func addShowAction() {
        let command = UDPCommand(
            name: "Primary Command",
            host: appState.defaultDestinationHost,
            port: appState.defaultDestinationPort,
            message: "RUN_SHOW",
            delaySeconds: 0
        )

        let action = ActionDefinition(
            name: "New Show Action",
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
            name: "New Utility Action",
            type: .utility,
            commands: [],
            utilityCommands: [utilityCommand]
        )

        appState.actionDefinitions.append(action)
        selectedActionID = action.id
    }

    private func deleteAction(_ action: ActionDefinition) {
        appState.actionDefinitions.removeAll { $0.id == action.id }

        if selectedActionID == action.id {
            selectedActionID = nil
        }
    }
}
