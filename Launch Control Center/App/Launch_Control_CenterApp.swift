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

    @StateObject private var appState: AppState

    // MARK: - Init

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)

        // Show a non-blocking startup status panel shortly after launch.
        // The schedule engine is started inside AppState.init(), before this
        // presentation-only panel is displayed, so scheduled Events are not
        // blocked by the startup UI.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            StartupStatusPanelController.shared.show(appState: state)
        }
    }

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
        Window("LCC - Dashboard", id: "Dashboard") {
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
        .defaultSize(
            width: LCCLayout.Window.dashboard.defaultWidth,
            height: LCCLayout.Window.dashboard.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }

    private var scheduleWindow: some Scene {
        Window("LCC - Schedule", id: "schedule-window") {
            ScheduleCalendarView()
                .environmentObject(appState)
        }
        .defaultSize(
            width: LCCLayout.Window.schedule.defaultWidth,
            height: LCCLayout.Window.schedule.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }

    private var actionsWindow: some Scene {
        Window("LCC - Define Actions", id: "actions-window") {
            ActionsView()
                .environmentObject(appState)
        }
        .defaultSize(
            width: LCCLayout.Window.actions.defaultWidth,
            height: LCCLayout.Window.actions.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }

    private var eventEditorWindow: some Scene {
        Window("LCC - Add Events", id: "event-editor-window") {
            EventEditorView()
                .environmentObject(appState)
        }
        .defaultSize(
            width: LCCLayout.Window.eventEditor.defaultWidth,
            height: LCCLayout.Window.eventEditor.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }

    private var setupWindow: some Scene {
        Window("LCC - Preferences", id: "setup-window") {
            SetupView()
                .environmentObject(appState)
        }
        .defaultSize(
            width: LCCLayout.Window.preferences.defaultWidth,
            height: LCCLayout.Window.preferences.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }

    private var testingWindow: some Scene {
        Window("LCC - UDP Test", id: "testing-window") {
            TestingView()
                .environmentObject(appState)
        }
        .defaultSize(
            width: LCCLayout.Window.testing.defaultWidth,
            height: LCCLayout.Window.testing.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }

    private var aboutWindow: some Scene {
        Window("LCC - About", id: "about-lcc-window") {
            AboutLaunchControlCenterView()
        }
        .defaultSize(
            width: LCCLayout.Window.about.defaultWidth,
            height: LCCLayout.Window.about.defaultHeight
        )
        .windowResizability(.contentMinSize)
    }

    private var helpWindow: some Scene {
        Window("LCC - Help", id: "help-lcc-window") {
            HelpLCCView()
        }
        .defaultSize(
            width: LCCLayout.Window.help.defaultWidth,
            height: LCCLayout.Window.help.defaultHeight
        )
        .windowResizability(.contentMinSize)
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
                    openAppWindow(id: "about-lcc-window", title: "LCC - About")
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Preferences…") {
                    openAppWindow(id: "setup-window", title: "LCC - Preferences")
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            // Remove the standard macOS Quit command from the app menu.
            // Launch Control Center is intended to remain running as a
            // menu-bar-first scheduler, so the operator-facing quit path lives
            // only in MenuBarView.
            CommandGroup(replacing: .appTermination) { }
        }
    }

    // MARK: - Launch Control Menu Commands

    private var navigationCommands: some Commands {
        CommandMenu("Launch Control") {
            // Keep this menu aligned with the menu bar extra.
            // The standard macOS Window menu still lists open windows, but this
            // menu gives operators a predictable command/navigation list even
            // when a window has been closed or hidden behind other apps.
            Button("Dashboard") {
                openAppWindow(id: "Dashboard", title: "LCC - Dashboard")
            }
            .keyboardShortcut("1", modifiers: [.command])

            Divider()

            Button("Schedule") {
                openAppWindow(id: "schedule-window", title: "LCC - Schedule")
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Define Actions") {
                openAppWindow(id: "actions-window", title: "LCC - Define Actions")
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button("Add Events") {
                openAppWindow(id: "event-editor-window", title: "LCC - Add Events")
            }
            .keyboardShortcut("4", modifiers: [.command])

            Divider()

            Button("UDP Testing") {
                openAppWindow(id: "testing-window", title: "LCC - UDP Test")
            }
            .keyboardShortcut("5", modifiers: [.command])

            Divider()

            Button("Preferences…") {
                openAppWindow(id: "setup-window", title: "LCC - Preferences")
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Help") {
                openAppWindow(id: "help-lcc-window", title: "LCC - Help")
            }
            .keyboardShortcut("/", modifiers: [.command])

            Button("About LCC") {
                openAppWindow(id: "about-lcc-window", title: "LCC - About")
            }

            Divider()

            Button("Open Logs Folder") {
                appState.openLogsFolder()
                activateApp()
            }
        }
    }

    // MARK: - Help Menu Commands

    private var helpCommands: some Commands {
        CommandGroup(replacing: .help) {
            Button("Launch Control Center Help") {
                openAppWindow(id: "help-lcc-window", title: "LCC - Help")
            }
            .keyboardShortcut("/", modifiers: [.command])
        }
    }

    // MARK: - App Activation

    private func openAppWindow(id: String, title: String) {
        openWindow(id: id)
        LCCWindowActivation.bringWindowToFront(matchingTitle: title)
    }

    private func activateApp() {
        LCCWindowActivation.activateApplication()
    }
}


