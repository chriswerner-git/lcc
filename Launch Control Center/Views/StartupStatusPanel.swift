//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: StartupStatusPanel.swift
//  Purpose: Non-blocking startup status panel shown briefly after app launch.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This panel is presentation-only.  It must never gate schedule evaluation,
//  Action playback, UDP output, or app startup.  AppState starts the schedule
//  engine before this panel is shown.
//

import AppKit
import SwiftUI

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
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 570),
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
    // MARK: - Environment

    @ObservedObject var appState: AppState

    // MARK: - Actions

    let dismiss: () -> Void

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            header
            StartupStatusDivider()
            centeredLTCLogo
            statusGrid
            footer
        }
        .padding(24)
        .frame(width: 600, height: 570)
        .background(LCCDesign.screenBackground(controlOpacity: 0.72))
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 74, height: 74)
                .accessibilityLabel("Launch Control Center app icon")

            VStack(alignment: .leading, spacing: 7) {
                Text(LCCLayout.appNameDisplay)
                    .font(.system(size: 30, weight: .bold))
                    .tracking(2.0)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("Version \(appVersion)  •  Build \(appBuild)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var centeredLTCLogo: some View {
        ltcLogo
            .frame(height: 88)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
    }

    private var ltcLogo: some View {
        Group {
            if let image = StartupStatusAssets.ltcLogo {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.active)
            }
        }
        .accessibilityLabel("Lunar Telephone Company logo")
    }

    // MARK: - Status Grid

    private var statusGrid: some View {
        VStack(spacing: 0) {
            StartupStatusRow(
                icon: "folder",
                title: "Project",
                value: appState.projectName.isEmpty ? "Untitled Project" : appState.projectName,
                color: LCCDesign.ColorToken.active
            )

            StartupStatusDivider()

            StartupStatusRow(
                icon: scheduleStatusIcon,
                title: "Schedule Status",
                value: scheduleStatusText,
                color: scheduleStatusColor
            )

            StartupStatusDivider()

            StartupStatusRow(
                icon: appState.configurationHealthReport.level.systemImage,
                title: "Configuration Health",
                value: appState.configurationHealthReport.title,
                color: configurationHealthColor
            )

            StartupStatusDivider()

            HStack(spacing: 0) {
                StartupStatusMetric(
                    icon: "play.rectangle",
                    title: "Actions",
                    value: "\(appState.actionDefinitions.count)",
                    color: LCCDesign.ColorToken.active
                )

                StartupStatusDivider(vertical: true)

                StartupStatusMetric(
                    icon: "calendar",
                    title: "Events",
                    value: "\(appState.scheduleEntries.count)",
                    color: LCCDesign.ColorToken.active
                )

                StartupStatusDivider(vertical: true)

                StartupStatusMetric(
                    icon: appState.preventComputerSleepEnabled ? "moon.zzz.fill" : "moon.zzz",
                    title: "Sleep",
                    value: appState.preventComputerSleepEnabled ? "Prevented" : "Normal",
                    color: LCCDesign.ColorToken.active
                )

                StartupStatusDivider(vertical: true)

                StartupStatusMetric(
                    icon: appState.launchAtStartupEnabled ? "power.circle.fill" : "power.circle",
                    title: "Launch at Startup",
                    value: appState.launchAtStartupEnabled ? "On" : "Off",
                    color: LCCDesign.ColorToken.active
                )
            }
        }
        .padding(16)
        .background(
            LCCDesign.cardBackground(
                cornerRadius: LCCDesign.Radius.panel,
                opacity: LCCDesign.Opacity.cardBackground
            )
        )
        .overlay(
            LCCDesign.cardBorder(cornerRadius: LCCDesign.Radius.panel)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(LCCDesign.ColorToken.active)

                Text("Schedule evaluation starts independently of this panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Dismiss") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Text("© 2026 Lunar Telephone Company. All rights reserved.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Spacer()
            }
        }
    }

    // MARK: - Derived Status

    private var scheduleStatusText: String {
        switch (appState.showActionsEnabled, appState.utilityActionsEnabled) {
        case (true, true):
            return "Show and Utility Events enabled"

        case (true, false):
            return "Show Events enabled, Utility Events disabled"

        case (false, true):
            return "Show Events disabled, Utility Events enabled"

        case (false, false):
            return "Scheduled playback disabled"
        }
    }

    private var scheduleStatusIcon: String {
        (appState.showActionsEnabled || appState.utilityActionsEnabled) ? "checkmark.circle.fill" : "pause.circle.fill"
    }

    private var scheduleStatusColor: Color {
        (appState.showActionsEnabled || appState.utilityActionsEnabled) ? LCCDesign.ColorToken.success : LCCDesign.ColorToken.warning
    }

    private var configurationHealthColor: Color {
        switch appState.configurationHealthReport.level {
        case .healthy:
            return LCCDesign.ColorToken.active

        case .warning:
            return LCCDesign.ColorToken.warning

        case .error:
            return LCCDesign.ColorToken.error
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}

// MARK: - Startup Status Row

private struct StartupStatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Startup Status Metric

private struct StartupStatusMetric: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - Startup Status Divider

private struct StartupStatusDivider: View {
    var vertical: Bool = false

    var body: some View {
        Rectangle()
            .fill(LCCDesign.ColorToken.strongBorder)
            .frame(
                width: vertical ? 1 : nil,
                height: vertical ? nil : 1
            )
    }
}

// MARK: - Startup Status Assets

private enum StartupStatusAssets {
    static var ltcLogo: NSImage? {
        NSImage(named: "LTCLogo") ?? NSImage(named: "LTCIcon")
    }
}
