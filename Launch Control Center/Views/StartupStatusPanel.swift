//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: StartupStatusPanel.swift
//  Purpose: Non-blocking startup status panel shown briefly after app launch,
//           using LunarKit shared startup panel layout.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This panel is presentation-only. It must never gate schedule evaluation,
//  Action playback, UDP output, or app startup.
//

import AppKit
import SwiftUI
import LunarKit

// MARK: - Startup Status Panel Controller

final class StartupStatusPanelController {
    // MARK: - Shared Instance

    static let shared = StartupStatusPanelController()

    // MARK: - Private State

    private var panel: NSPanel?
    private var autoDismissWorkItem: DispatchWorkItem?

    // MARK: - Init

    private init() { }

    // MARK: - Presentation

    func show(appState: AppState, duration: TimeInterval = 7.5) {
        DispatchQueue.main.async {
            self.showOnMain(appState: appState, duration: duration)
        }
    }

    func dismiss() {
        DispatchQueue.main.async {
            self.autoDismissWorkItem?.cancel()
            self.autoDismissWorkItem = nil
            self.panel?.close()
            self.panel = nil
        }
    }

    private func showOnMain(appState: AppState, duration: TimeInterval) {
        autoDismissWorkItem?.cancel()

        let contentView = StartupStatusPanelView(appState: appState) { [weak self] in
            self?.dismiss()
        }

        let hostingView = NSHostingView(rootView: contentView)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.title = "LCC Startup Status"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        panel.center()

        self.panel = panel

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        LCCWindowActivation.activateApplication()

        let dismissWorkItem = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }

        autoDismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: dismissWorkItem)
    }
}

// MARK: - Startup Status Panel View

private struct StartupStatusPanelView: View {
    // MARK: - Observed State

    @ObservedObject var appState: AppState

    // MARK: - Actions

    let dismiss: () -> Void

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LTCStartupPanelShell(
                identity: identity,
                version: appVersion,
                build: appBuild,
                projectName: appState.projectName,
                statusItems: statusItems
            )

            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LTCDesign.ColorToken.secondaryText)
            }
            .buttonStyle(.plain)
            .padding(16)
            .help("Dismiss startup status")
        }
        .background(LCCDesign.screenBackground(controlOpacity: 0.72))
    }

    // MARK: - Startup Data

    private var statusItems: [LTCStartupStatusItem] {
        [
            LTCStartupStatusItem(
                title: "Project",
                value: appState.projectName.isEmpty ? "Untitled Project" : appState.projectName,
                severity: .unknown
            ),
            LTCStartupStatusItem(
                title: "Schedule",
                value: scheduleStatusText,
                severity: scheduleSeverity
            ),
            LTCStartupStatusItem(
                title: "Configuration Health",
                value: appState.configurationHealthReport.title,
                severity: .unknown
            ),
            LTCStartupStatusItem(
                title: "Actions",
                value: "\(appState.actionDefinitions.count)",
                severity: .unknown
            ),
            LTCStartupStatusItem(
                title: "Events",
                value: "\(appState.scheduleEntries.count)",
                severity: .unknown
            ),
            LTCStartupStatusItem(
                title: "Sleep Prevention",
                value: appState.preventComputerSleepEnabled ? "Enabled" : "Disabled",
                severity: appState.preventComputerSleepEnabled ? .healthy : .disabled
            ),
            LTCStartupStatusItem(
                title: "Launch at Startup",
                value: appState.launchAtStartupEnabled ? "Enabled" : "Disabled",
                severity: appState.launchAtStartupEnabled ? .healthy : .disabled
            )
        ]
    }

    private var scheduleStatusText: String {
        if appState.showActionsEnabled && appState.utilityActionsEnabled {
            return "Show + Utility enabled"
        }

        if appState.showActionsEnabled {
            return "Show enabled"
        }

        if appState.utilityActionsEnabled {
            return "Utility enabled"
        }

        return "Disabled"
    }

    private var scheduleSeverity: LTCStatusSeverity {
        (appState.showActionsEnabled || appState.utilityActionsEnabled) ? .healthy : .disabled
    }

    private var identity: LTCAppIdentity {
        LTCAppIdentity(
            initials: "LCC",
            displayName: "Launch Control Center",
            headerTitle: "LAUNCH CONTROL CENTER",
            appIconName: "AppIcon",
            companyIconName: "LTCIcon",
            companyLogoName: "LTCLogo"
        )
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
}
