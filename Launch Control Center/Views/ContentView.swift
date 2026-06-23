//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ContentView.swift
//  Purpose: Main Dashboard shell and manual Action trigger layout.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import SwiftUI

struct ContentView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Layout Constants

    private let outerPadding: CGFloat = LCCLayout.Spacing.screenPadding
    private let sectionSpacing: CGFloat = LCCLayout.Dashboard.sectionSpacing

    // MARK: - Body

    var body: some View {
        ZStack {
            dashboardBackground

            VStack(alignment: .leading, spacing: sectionSpacing) {
                dashboardHeader

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

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: sectionSpacing) {
                        EventSummaryView()
                            .environmentObject(appState)
                            .frame(height: LCCLayout.Dashboard.eventSummaryHeight)

                        TodayScheduleView()
                            .environmentObject(appState)
                            .frame(minHeight: LCCLayout.Dashboard.todayScheduleMinimumHeight)
                    }
                    .padding(.trailing, 4)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(outerPadding)
        }
        .lccWindowPresentation(title: "LCC - Dashboard", metrics: LCCLayout.Window.dashboard)
        .background(DashboardWindowConfigurator())
    }

    // MARK: - Header

    private var dashboardHeader: some View {
        LCCWindowTopChrome(
            title: "Dashboard",
            subtitle: "Monitor status, run Actions manually, and review upcoming Events.",
            systemImage: "rectangle.3.group.fill"
        )
    }

    // MARK: - Styling

    private var dashboardBackground: some View {
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

    private var dashboardDivider: some View {
        Rectangle()
            .fill(LCCDesign.ColorToken.strongBorder)
            .frame(height: 1)
            .padding(.vertical, 2)
    }
}

// MARK: - Manual Action Buttons

private struct ManualActionButtonsView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Layout Constants

    private let buttonMinimumWidth: CGFloat = 156
    private let buttonHeight: CGFloat = 32
    private let buttonSpacing: CGFloat = 8
    private let cardPadding: CGFloat = 14
    private let cardHeaderHeight: CGFloat = 24
    private let minimumColumnHeight: CGFloat = LCCLayout.Dashboard.manualActionsMinimumColumnHeight
    private let maximumColumnHeight: CGFloat = LCCLayout.Dashboard.manualActionsMaximumColumnHeight

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
                max(showHeight, utilityHeight, minimumColumnHeight),
                maximumColumnHeight
            )

            VStack(alignment: .leading, spacing: LCCLayout.Dashboard.sectionHeaderSpacing) {
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

    // MARK: - Section Layout

    private var manualSectionHeight: CGFloat {
        let assumedDashboardContentWidth = LCCLayout.Window.dashboard.defaultWidth - (LCCLayout.Spacing.screenPadding * 2)
        let columnWidth = max((assumedDashboardContentWidth - 14) / 2, 320)

        let showHeight = columnHeight(
            actionCount: showActions.count,
            columnWidth: columnWidth
        )

        let utilityHeight = columnHeight(
            actionCount: utilityActions.count,
            columnWidth: columnWidth
        )

        let targetHeight = min(
            max(showHeight, utilityHeight, minimumColumnHeight),
            maximumColumnHeight
        )

        return 28 + LCCLayout.Dashboard.sectionHeaderSpacing + targetHeight
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

    // MARK: - Action Columns

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
                            GridItem(
                                .adaptive(minimum: buttonMinimumWidth),
                                spacing: buttonSpacing
                            )
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

    // MARK: - Action Buttons

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
                    .fill(LCCDesign.ColorToken.textBackground.opacity(0.18))
            )
    }

    // MARK: - Layout Helpers

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

    // MARK: - Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LCCDesign.ColorToken.controlBackground.opacity(0.72))
            .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }

    private func buttonBackground(for type: ActionType) -> some View {
        let baseColor = LCCDesign.actionColor(for: type)

        return RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(baseColor.opacity(0.18))
    }

    private var buttonBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.strongBorder, lineWidth: 1)
    }
}

// MARK: - Window Configuration

private struct DashboardWindowConfigurator: NSViewRepresentable {
    // MARK: - NSViewRepresentable

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

    // MARK: - Window Sizing

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
