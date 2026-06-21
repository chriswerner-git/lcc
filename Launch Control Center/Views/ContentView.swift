//
//  ContentView.swift
//  Launch Control Center
//
//  Main dashboard view.
//
//  This is the operator's primary interface.
//  It provides:
//  - Current clock
//  - Manual Action trigger buttons
//  - Schedule enable / disable
//  - Volume control
//  - Next / Last Event summary
//  - Today's scheduled Events
//

import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private let outerPadding: CGFloat = 18
    private let sectionSpacing: CGFloat = 18

    var body: some View {
        ZStack {
            dashboardBackground

            VStack(alignment: .leading, spacing: sectionSpacing) {
                DashboardClockView()
                    .environmentObject(appState)

                ManualActionButtonsView()
                    .environmentObject(appState)

                ScheduleStatusView()
                    .environmentObject(appState)

                dashboardDivider

                VolumeControlView()
                    .environmentObject(appState)

                dashboardDivider

                EventSummaryView()
                    .environmentObject(appState)
                    .frame(height: 124)

                TodayScheduleView()
                    .environmentObject(appState)
                    .frame(maxHeight: .infinity)

                Spacer(minLength: 0)
            }
            .padding(outerPadding)
        }
        .frame(minWidth: 900, minHeight: 900)
        .background(DashboardWindowConfigurator())
    }

    private var dashboardBackground: some View {
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

    private var dashboardDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.10))
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}

// MARK: - Manual Action Buttons

private struct ManualActionButtonsView: View {
    @EnvironmentObject var appState: AppState

    private let buttonMinimumWidth: CGFloat = 156
    private let buttonHeight: CGFloat = 32
    private let buttonSpacing: CGFloat = 8
    private let cardPadding: CGFloat = 14
    private let cardHeaderHeight: CGFloat = 24
    private let maximumColumnHeight: CGFloat = 245

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
        GeometryReader { geometry in
            let columnWidth = max((geometry.size.width - 14) / 2, 320)

            let showHeight = columnHeight(
                actionCount: showActions.count,
                columnWidth: columnWidth
            )

            let utilityHeight = columnHeight(
                actionCount: utilityActions.count,
                columnWidth: columnWidth
            )

            let targetHeight = min(
                max(showHeight, utilityHeight),
                maximumColumnHeight
            )

            VStack(alignment: .leading, spacing: 10) {
                sectionHeader

                HStack(alignment: .top, spacing: 14) {
                    actionColumn(
                        title: "Shows",
                        subtitle: "\(showActions.count) defined",
                        actions: showActions,
                        emptyMessage: "No Show Actions defined.",
                        targetHeight: targetHeight
                    )

                    actionColumn(
                        title: "Utilities",
                        subtitle: "\(utilityActions.count) defined",
                        actions: utilityActions,
                        emptyMessage: "No Utility Actions defined.",
                        targetHeight: targetHeight
                    )
                }
            }
        }
        .frame(height: manualSectionHeight)
    }

    private var manualSectionHeight: CGFloat {
        let assumedDashboardWidth: CGFloat = 900
        let columnWidth = max((assumedDashboardWidth - 36 - 14) / 2, 320)

        let showHeight = columnHeight(
            actionCount: showActions.count,
            columnWidth: columnWidth
        )

        let utilityHeight = columnHeight(
            actionCount: utilityActions.count,
            columnWidth: columnWidth
        )

        let targetHeight = min(
            max(showHeight, utilityHeight),
            maximumColumnHeight
        )

        return 28 + 10 + targetHeight
    }

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Manual Actions")
                .font(.headline)

            Text("Run immediately")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(appState.actionDefinitions.count) total")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 1)
    }

    private func actionColumn(
        title: String,
        subtitle: String,
        actions: [ActionDefinition],
        emptyMessage: String,
        targetHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Spacer()

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if actions.isEmpty {
                emptyActionState(emptyMessage)
            } else {
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: buttonMinimumWidth), spacing: buttonSpacing)
                        ],
                        alignment: .leading,
                        spacing: buttonSpacing
                    ) {
                        ForEach(actions) { action in
                            manualActionButton(action)
                        }
                    }
                    .padding(.trailing, 4)
                    .padding(.bottom, 2)
                }
                .scrollIndicators(.visible)
            }

            Spacer(minLength: 0)
        }
        .padding(cardPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: targetHeight,
            maxHeight: targetHeight,
            alignment: .topLeading
        )
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func manualActionButton(_ action: ActionDefinition) -> some View {
        Button {
            appState.runAction(action)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: action.type == .show ? "play.fill" : "bolt.fill")
                    .font(.caption)

                Text(action.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: buttonHeight)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(buttonBackground(for: action.type))
        .overlay(buttonBorder)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .help("Run \(action.name)")
    }

    private func emptyActionState(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.18))
            )
    }

    private func columnHeight(
        actionCount: Int,
        columnWidth: CGFloat
    ) -> CGFloat {
        guard actionCount > 0 else {
            return 112
        }

        let availableButtonWidth = max(
            columnWidth - (cardPadding * 2),
            buttonMinimumWidth
        )

        let columnCount = max(
            Int(availableButtonWidth / (buttonMinimumWidth + buttonSpacing)),
            1
        )

        let rowCount = Int(
            ceil(Double(actionCount) / Double(columnCount))
        )

        let gridHeight = CGFloat(rowCount) * buttonHeight
            + CGFloat(max(rowCount - 1, 0)) * buttonSpacing

        return cardPadding
            + cardHeaderHeight
            + 10
            + gridHeight
            + cardPadding
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    }

    private func buttonBackground(for type: ActionType) -> some View {
        let baseColor: Color = type == .show ? .blue : .purple

        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(baseColor.opacity(0.18))
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
    }
}

// MARK: - Window Configuration

private struct DashboardWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            configureWindow(from: view)
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(from: nsView)
        }
    }

    private func configureWindow(from view: NSView) {
        guard let window = view.window else {
            return
        }

        let configuredIdentifier = "dashboard-window-configured-60w-98h"

        guard window.identifier?.rawValue != configuredIdentifier else {
            return
        }

        window.identifier = NSUserInterfaceItemIdentifier(configuredIdentifier)

        guard let screen = window.screen ?? NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let targetWidth = visibleFrame.width * 0.60
        let targetHeight = visibleFrame.height * 0.98

        let targetOrigin = NSPoint(
            x: visibleFrame.midX - targetWidth / 2,
            y: visibleFrame.midY - targetHeight / 2
        )

        let targetFrame = NSRect(
            x: targetOrigin.x,
            y: targetOrigin.y,
            width: targetWidth,
            height: targetHeight
        )

        window.setFrame(targetFrame, display: true)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
