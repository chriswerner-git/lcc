//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: Launch_Control_CenterApp.swift
//  Purpose: Main application entry point, windows, menu bar, and app commands.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import SwiftUI

final class LaunchControlCenterAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        OperationalLogService.shared.info("Application will terminate.")
        OperationalLogService.shared.flushAndClose()
    }
}

@main
struct Launch_Control_CenterApp: App {
    // MARK: - App Delegate

    @NSApplicationDelegateAdaptor(LaunchControlCenterAppDelegate.self) private var appDelegate

    // MARK: - App State

    @StateObject private var appState = AppState()

    // MARK: - Environment

    @Environment(\.openWindow) private var openWindow

    // MARK: - Scenes

    var body: some Scene {
        dashboardWindow
        scheduleWindow
        actionsWindow
        eventEditorWindow
        setupWindow
        testingWindow
        aboutWindow
        helpWindow
        menuBarExtra
    }

    private var dashboardWindow: some Scene {
        Window("Dashboard", id: "Dashboard") {
            ContentView()
                .environmentObject(appState)
                .onAppear {
                    appState.setDashboardWindowIsOpen(true)
                    activateApp()
                }
                .onDisappear {
                    appState.setDashboardWindowIsOpen(false)
                }
        }
        .defaultSize(width: 1400, height: 1030)
    }

    private var scheduleWindow: some Scene {
        Window("Schedule", id: "schedule-window") {
            ScheduleCalendarView()
                .environmentObject(appState)
        }
        .defaultSize(width: 1200, height: 760)
    }

    private var actionsWindow: some Scene {
        Window("Actions", id: "actions-window") {
            ActionsView()
                .environmentObject(appState)
        }
        .defaultSize(width: 980, height: 720)
    }

    private var eventEditorWindow: some Scene {
        Window("Add Event", id: "event-editor-window") {
            EventEditorView()
                .environmentObject(appState)
        }
        .defaultSize(width: 680, height: 700)
    }

    private var setupWindow: some Scene {
        Window("Setup", id: "setup-window") {
            SetupView()
                .environmentObject(appState)
        }
        .defaultSize(width: 840, height: 720)
    }

    private var testingWindow: some Scene {
        Window("UDP Test", id: "testing-window") {
            TestingView()
                .environmentObject(appState)
        }
        .defaultSize(width: 660, height: 640)
    }

    private var aboutWindow: some Scene {
        Window("About Launch Control Center", id: "about-lcc-window") {
            AboutLaunchControlCenterView()
        }
        .defaultSize(width: 560, height: 760)
    }

    private var helpWindow: some Scene {
        Window("Launch Control Center Help", id: "help-lcc-window") {
            HelpLCCView()
        }
        .defaultSize(width: 680, height: 760)
    }

    private var menuBarExtra: some Scene {
        MenuBarExtra(
            "Launch Control Center",
            image: menuBarIconAssetName
        ) {
            MenuBarView()
                .environmentObject(appState)
        }
        .commands {
            appMenuCommands
            navigationCommands
            helpCommands
        }
    }

    // MARK: - Menu Bar Icon State

    private var scheduleIsActive: Bool {
        appState.showActionsEnabled || appState.utilityActionsEnabled
    }

    private var menuBarIconAssetName: String {
        scheduleIsActive ? "MenuBarIconActive" : "MenuBarIconInactive"
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

    // MARK: - Launch Control Menu Commands

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

            Button("Open Logs Folder") {
                appState.openLogsFolder()
                activateApp()
            }

            Button("About Launch Control Center") {
                openWindow(id: "about-lcc-window")
                activateApp()
            }

            Button("Launch Control Center Help") {
                openWindow(id: "help-lcc-window")
                activateApp()
            }
            .keyboardShortcut("/", modifiers: [.command])
        }
    }

    // MARK: - Help Menu Commands

    private var helpCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button("Launch Control Center Help") {
                openWindow(id: "help-lcc-window")
                activateApp()
            }
            .keyboardShortcut("/", modifiers: [.command])
        }
    }

    // MARK: - App Activation

    private func activateApp() {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

