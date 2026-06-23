//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: MenuBarView.swift
//  Purpose: Menu bar interface for quick app navigation and status.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import SwiftUI

struct MenuBarView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerSection

            Divider()

            dashboardSection

            Divider()

            scheduleSection

            Divider()

            testingSection

            Divider()

            supportSection

            Divider()

            systemSection
        }
        .padding()
        .frame(width: 270)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(appState.projectName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(scheduleStatusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var scheduleStatusText: String {
        if appState.showActionsEnabled && appState.utilityActionsEnabled {
            return "Shows and Utilities Enabled"
        } else if appState.showActionsEnabled {
            return "Shows Enabled"
        } else if appState.utilityActionsEnabled {
            return "Utilities Enabled"
        } else {
            return "Schedule Disabled"
        }
    }

    // MARK: - Dashboard

    private var dashboardSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            menuButton(
                title: "Dashboard",
                systemImage: "rectangle.grid.1x2",
                windowID: "Dashboard",
                windowTitle: "LCC - Dashboard"
            )
        }
    }

    // MARK: - Schedule / Actions

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            menuButton(
                title: "Schedule",
                systemImage: "calendar",
                windowID: "schedule-window",
                windowTitle: "LCC - Schedule"
            )

            menuButton(
                title: "Define Actions",
                systemImage: "rectangle.stack.badge.play",
                windowID: "actions-window",
                windowTitle: "LCC - Define Actions"
            )

            menuButton(
                title: "Add Events",
                systemImage: "calendar.badge.plus",
                windowID: "event-editor-window",
                windowTitle: "LCC - Add Events"
            )
        }
    }

    // MARK: - UDP Testing

    private var testingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            menuButton(
                title: "UDP Testing",
                systemImage: "antenna.radiowaves.left.and.right",
                windowID: "testing-window",
                windowTitle: "LCC - UDP Test"
            )
        }
    }

    // MARK: - Preferences / Help / About

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            menuButton(
                title: "Preferences",
                systemImage: "gearshape",
                windowID: "setup-window",
                windowTitle: "LCC - Preferences"
            )

            menuButton(
                title: "Help",
                systemImage: "questionmark.circle",
                windowID: "help-lcc-window",
                windowTitle: "LCC - Help"
            )

            menuButton(
                title: "About LCC",
                systemImage: "info.circle",
                windowID: "about-lcc-window",
                windowTitle: "LCC - About"
            )
        }
    }

    // MARK: - System

    private var systemSection: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit", systemImage: "power")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func menuButton(
        title: String,
        systemImage: String,
        windowID: String,
        windowTitle: String
    ) -> some View {
        Button {
            openWindow(id: windowID)
            LCCWindowActivation.bringWindowToFront(matchingTitle: windowTitle)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
