//
//  Launch_Control_CenterApp.swift
//  Launch Control Center
//
//  Main application entry point.
//
//  Defines all top-level macOS scenes:
//  - Dashboard
//  - Schedule
//  - Actions
//  - Event Editor
//  - Setup
//  - UDP Test
//  - About
//  - Menu Bar item
//
//  Also defines standard macOS menu commands.
//

import AppKit
import SwiftUI

@main
struct Launch_Control_CenterApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        Window("Dashboard", id: "Dashboard") {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 1400, height: 1030)

        Window("Schedule", id: "schedule-window") {
            ScheduleCalendarView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1200, height: 760)

        Window("Actions", id: "actions-window") {
            ActionsView()
                .environmentObject(appState)
        }
        .defaultSize(width: 980, height: 720)

        Window("Add Event", id: "event-editor-window") {
            EventEditorView()
                .environmentObject(appState)
        }
        .defaultSize(width: 680, height: 700)

        Window("Setup", id: "setup-window") {
            SetupView()
                .environmentObject(appState)
        }
        .defaultSize(width: 840, height: 720)

        Window("UDP Test", id: "testing-window") {
            TestingView()
                .environmentObject(appState)
        }
        .defaultSize(width: 660, height: 640)

        Window("About Launch Control Center", id: "about-lcc-window") {
            AboutLaunchControlCenterView()
        }
        .defaultSize(width: 560, height: 760)

        MenuBarExtra(
            "Launch Control Center",
            systemImage: "antenna.radiowaves.left.and.right"
        ) {
            MenuBarView()
                .environmentObject(appState)
        }
        .commands {
            appMenuCommands
            navigationCommands
        }
    }

    // MARK: - Standard macOS App Menu Commands

    private var appMenuCommands: some Commands {
        Group {
            CommandGroup(replacing: .appInfo) {
                Button("About Launch Control Center") {
                    openWindow(id: "about-lcc-window")
                    activateApp()
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    openWindow(id: "setup-window")
                    activateApp()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    // MARK: - Custom Menu Bar Commands

    private var navigationCommands: some Commands {
        CommandMenu("Launch Control") {
            Button("Dashboard") {
                openWindow(id: "Dashboard")
                activateApp()
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Schedule") {
                openWindow(id: "schedule-window")
                activateApp()
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Define Actions") {
                openWindow(id: "actions-window")
                activateApp()
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button("Add Events") {
                openWindow(id: "event-editor-window")
                activateApp()
            }
            .keyboardShortcut("4", modifiers: [.command])

            Button("UDP Tests") {
                openWindow(id: "testing-window")
                activateApp()
            }
            .keyboardShortcut("5", modifiers: [.command])

            Divider()

            Button("Preferences…") {
                openWindow(id: "setup-window")
                activateApp()
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("About Launch Control Center") {
                openWindow(id: "about-lcc-window")
                activateApp()
            }
        }
    }

    // MARK: - App Activation

    private func activateApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
