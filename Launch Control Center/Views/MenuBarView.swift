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
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            Divider()

            navigationSection

            Divider()

            helpSection

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

    // MARK: - Navigation

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            menuButton(
                title: "Dashboard",
                systemImage: "rectangle.grid.1x2",
                windowID: "Dashboard"
            )

            menuButton(
                title: "Schedule",
                systemImage: "calendar",
                windowID: "schedule-window"
            )

            menuButton(
                title: "Define Actions",
                systemImage: "rectangle.stack.badge.play",
                windowID: "actions-window"
            )

            menuButton(
                title: "Add Events",
                systemImage: "calendar.badge.plus",
                windowID: "event-editor-window"
            )

            menuButton(
                title: "UDP Tests",
                systemImage: "network",
                windowID: "testing-window"
            )

            menuButton(
                title: "Preferences",
                systemImage: "gearshape",
                windowID: "setup-window"
            )
        }
    }

    // MARK: - Help / About

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            menuButton(
                title: "Help",
                systemImage: "questionmark.circle",
                windowID: "help-lcc-window"
            )

            menuButton(
                title: "About LCC",
                systemImage: "info.circle",
                windowID: "about-lcc-window"
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
        windowID: String
    ) -> some View {
        Button {
            openWindow(id: windowID)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
