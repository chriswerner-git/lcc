//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: DiagnosticsView.swift
//  Purpose: Operator-facing diagnostics summary using LunarKit's shared
//           diagnostics shell while keeping LCC-specific data local.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import Foundation
import SwiftUI
import LunarKit

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState

    @State private var networkInterfaces: [NetworkInterfaceSnapshot] = NetworkInventoryService.currentIPv4Interfaces()
    @State private var statusMessage: String = "Diagnostics ready."

    var body: some View {
        VStack(alignment: .leading, spacing: LCCLayout.Spacing.section) {
            LCCWindowTopChrome(
                title: "Diagnostics",
                subtitle: "Runtime status, configuration health, network inventory, and support tools.",
                systemImage: "stethoscope"
            )

            LTCDiagnosticsShell(
                summaryTitle: summaryTitle,
                summaryDescription: summaryDescription,
                level: summaryLevel
            ) {
                runtimeSection
                configurationSection
                networkSection
                servicesSection
                storageLoggingSection
                actionsSection
            }
        }
        .padding(LCCLayout.Spacing.windowPadding)
        .background(LCCDesign.ColorToken.windowBackground.ignoresSafeArea())
        .onAppear {
            refreshNetworkInterfaces()
        }
    }

    // MARK: - Summary

    private var healthReport: ConfigurationHealthReport {
        appState.configurationHealthReport
    }

    private var summaryLevel: LTCStatusLevel {
        statusLevel(for: healthReport.level)
    }

    private var summaryTitle: String {
        switch healthReport.level {
        case .healthy:
            return "Launch Control Center Ready"
        case .warning:
            return "Diagnostics Report Warnings"
        case .error:
            return "Diagnostics Report Issues"
        }
    }

    private var summaryDescription: String {
        if healthReport.issues.isEmpty {
            return "No configuration health issues are currently reported."
        }

        return healthReport.summary
    }

    // MARK: - Sections

    private var runtimeSection: some View {
        LTCDiagnosticsSection(
            category: .runtime,
            subtitle: "Local runtime preferences and current application state."
        ) {
            LTCDiagnosticRows([
                LTCDiagnosticItem(
                    title: "Project",
                    detail: appState.projectName,
                    level: .info
                ),
                LTCDiagnosticItem(
                    title: "Window Title Standard",
                    detail: LTCAppIdentity.windowTitle(initials: "LCC", windowName: "Diagnostics"),
                    level: .info,
                    monospacedDetail: true
                ),
                LTCDiagnosticItem(
                    title: "Launch at Startup",
                    detail: appState.launchAtStartupStatusMessage,
                    level: appState.launchAtStartupEnabled ? .good : .inactive
                ),
                LTCDiagnosticItem(
                    title: "Prevent Sleep",
                    detail: appState.preventComputerSleepStatusMessage,
                    level: appState.preventComputerSleepEnabled ? .good : .inactive
                ),
                LTCDiagnosticItem(
                    title: "Operational Log Retention",
                    detail: "\(appState.operationalLogRetentionDays) day\(appState.operationalLogRetentionDays == 1 ? "" : "s")",
                    level: .info
                )
            ])
        }
    }

    private var configurationSection: some View {
        LTCDiagnosticsSection(
            category: .configuration,
            subtitle: "Configuration health and project object counts."
        ) {
            LTCDiagnosticRows(configurationItems)
        }
    }

    private var networkSection: some View {
        LTCDiagnosticsSection(
            category: .network,
            subtitle: "Current local IPv4 interface inventory and NTP status."
        ) {
            LTCDiagnosticRows(networkItems)

            Divider()
                .overlay(LTCDesign.ColorToken.divider)
                .padding(.vertical, 6)

            LTCDiagnosticsActionRow(
                title: "Refresh Interfaces",
                description: "Re-read the local IPv4 interface inventory used by LCC network preferences and diagnostics.",
                buttonTitle: "Refresh",
                systemImage: "arrow.clockwise",
                action: refreshNetworkInterfaces
            )
        }
    }

    private var servicesSection: some View {
        LTCDiagnosticsSection(
            category: .services,
            subtitle: "Schedule toggles, running actions, and operator-facing execution state."
        ) {
            LTCDiagnosticRows([
                LTCDiagnosticItem(
                    title: "Show Actions",
                    detail: appState.showActionsEnabled ? "Scheduled show playback enabled" : "Scheduled show playback disabled",
                    level: appState.showActionsEnabled ? .good : .warning
                ),
                LTCDiagnosticItem(
                    title: "Utility Actions",
                    detail: appState.utilityActionsEnabled ? "Scheduled utility macros enabled" : "Scheduled utility macros disabled",
                    level: appState.utilityActionsEnabled ? .good : .warning
                ),
                LTCDiagnosticItem(
                    title: "Running Actions",
                    detail: "\(appState.runningActionCount)",
                    level: appState.runningActionCount > 0 ? .info : .inactive
                ),
                LTCDiagnosticItem(
                    title: "Last Message",
                    detail: appState.lastMessage,
                    level: .info
                ),
                LTCDiagnosticItem(
                    title: "Last Event",
                    detail: appState.lastEventMessage,
                    level: .info
                )
            ])
        }
    }

    private var storageLoggingSection: some View {
        LTCDiagnosticsSection(
            category: .logging,
            subtitle: "Local logs, configuration backups, and diagnostic bundle support."
        ) {
            LTCDiagnosticRows([
                LTCDiagnosticItem(
                    title: "Operational Logs",
                    detail: "Retention set to \(appState.operationalLogRetentionDays) day\(appState.operationalLogRetentionDays == 1 ? "" : "s")",
                    level: .info
                ),
                LTCDiagnosticItem(
                    title: "Configuration Export",
                    detail: "Available from Preferences → Import / Export",
                    level: .info
                ),
                LTCDiagnosticItem(
                    title: "Automatic Backups",
                    detail: "Available from Preferences → Restore",
                    level: .info
                )
            ])

            Divider()
                .overlay(LTCDesign.ColorToken.divider)
                .padding(.vertical, 6)

            HStack(spacing: 12) {
                LTCDiagnosticsActionRow(
                    title: "Open Logs Folder",
                    description: "Open the folder containing Launch Control Center operational logs.",
                    buttonTitle: "Open",
                    systemImage: "folder",
                    action: appState.openLogsFolder
                )

                LTCDiagnosticsActionRow(
                    title: "Status",
                    description: statusMessage,
                    buttonTitle: "Copy",
                    systemImage: "doc.on.doc",
                    action: copySummary
                )
            }
        }
    }

    private var actionsSection: some View {
        LTCDiagnosticsSection(
            title: "Project Inventory",
            systemImage: "rectangle.stack.fill",
            subtitle: "Current in-memory project object counts."
        ) {
            LTCDiagnosticRows([
                LTCDiagnosticItem(
                    title: "Defined Actions",
                    detail: "\(appState.actionDefinitions.count)",
                    level: appState.actionDefinitions.isEmpty ? .warning : .good
                ),
                LTCDiagnosticItem(
                    title: "Schedule Entries",
                    detail: "\(appState.scheduleEntries.count)",
                    level: appState.scheduleEntries.isEmpty ? .warning : .good
                ),
                LTCDiagnosticItem(
                    title: "Scheduled Events",
                    detail: "\(appState.scheduledEvents.count)",
                    level: appState.scheduledEvents.isEmpty ? .inactive : .info
                ),
                LTCDiagnosticItem(
                    title: "Execution History",
                    detail: "\(appState.scheduleExecutionHistory.count) record\(appState.scheduleExecutionHistory.count == 1 ? "" : "s")",
                    level: appState.scheduleExecutionHistory.isEmpty ? .inactive : .info
                )
            ])
        }
    }

    // MARK: - Diagnostic Items

    private var configurationItems: [LTCDiagnosticItem] {
        var items: [LTCDiagnosticItem] = [
            LTCDiagnosticItem(
                title: "Configuration Health",
                detail: healthReport.summary,
                level: summaryLevel
            )
        ]

        if healthReport.issues.isEmpty {
            items.append(
                LTCDiagnosticItem(
                    title: "Issues",
                    detail: "No configuration issues reported",
                    level: .good
                )
            )
        } else {
            items.append(contentsOf: healthReport.issues.prefix(8).map { issue in
                LTCDiagnosticItem(
                    title: issue.title,
                    detail: issue.detail,
                    level: statusLevel(for: issue.level)
                )
            })
        }

        return items
    }

    private var networkItems: [LTCDiagnosticItem] {
        var items: [LTCDiagnosticItem] = [
            LTCDiagnosticItem(
                title: "IPv4 Interfaces",
                detail: "\(networkInterfaces.count)",
                level: networkInterfaces.isEmpty ? .warning : .good
            )
        ]

        items.append(contentsOf: networkInterfaces.prefix(8).map { interface in
            LTCDiagnosticItem(
                title: interface.displayName,
                detail: interfaceDetail(interface),
                level: interface.isUp && interface.isRunning ? .good : .warning,
                monospacedDetail: true
            )
        })

        if let result = appState.ntpResult {
            items.append(
                LTCDiagnosticItem(
                    title: "NTP",
                    detail: "\(result.server) · offset \(String(format: "%.1f", result.offsetMilliseconds)) ms · RTT \(String(format: "%.1f", result.roundTripMilliseconds)) ms",
                    level: .good
                )
            )
        } else if let error = appState.ntpErrorMessage, !error.isEmpty {
            items.append(
                LTCDiagnosticItem(
                    title: "NTP",
                    detail: error,
                    level: .warning
                )
            )
        } else {
            items.append(
                LTCDiagnosticItem(
                    title: "NTP",
                    detail: "No NTP comparison has completed yet",
                    level: .inactive
                )
            )
        }

        return items
    }

    // MARK: - Helpers

    private func refreshNetworkInterfaces() {
        networkInterfaces = NetworkInventoryService.currentIPv4Interfaces()
        statusMessage = "Network interface inventory refreshed."
    }

    private func copySummary() {
        let summary = [
            "Launch Control Center Diagnostics",
            "Project: \(appState.projectName)",
            "Configuration: \(healthReport.summary)",
            "Actions: \(appState.actionDefinitions.count)",
            "Schedule Entries: \(appState.scheduleEntries.count)",
            "Scheduled Events: \(appState.scheduledEvents.count)",
            "IPv4 Interfaces: \(networkInterfaces.count)",
            "Show Actions Enabled: \(appState.showActionsEnabled)",
            "Utility Actions Enabled: \(appState.utilityActionsEnabled)"
        ].joined(separator: "\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
        statusMessage = "Diagnostics summary copied to clipboard."
    }

    private func interfaceDetail(_ interface: NetworkInterfaceSnapshot) -> String {
        var parts = [interface.ipv4Address]

        if let netmask = interface.netmask, !netmask.isEmpty {
            parts.append("mask \(netmask)")
        }

        parts.append(interface.availabilityText)
        return parts.joined(separator: " · ")
    }

    private func statusLevel(for level: ConfigurationHealthLevel) -> LTCStatusLevel {
        switch level {
        case .healthy:
            return .good
        case .warning:
            return .warning
        case .error:
            return .critical
        }
    }
}
