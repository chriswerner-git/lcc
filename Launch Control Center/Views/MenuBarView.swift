//
//  MenuBarView.swift
//  Launch Control Center
//
//  Menu bar interface.
//
//  Provides quick access to:
//  - Dashboard
//  - Schedule
//  - Define Actions
//  - Add Events
//  - UDP Tests
//  - Preferences
//  - About
//  - Quit
//

import AppKit
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection

            Divider()

            navigationSection

            Divider()

            aboutSection

            Divider()

            systemSection
        }
        .padding()
        .frame(width: 270)
    }

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

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                openWindow(id: "about-lcc-window")
            } label: {
                Label("About LCC", systemImage: "info.circle")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var systemSection: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Quit", systemImage: "power")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

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
