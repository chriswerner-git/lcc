//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: SetupView.swift
//  Purpose: App preferences, project settings, volume presets, and backups.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SetupView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - State

    @State private var selectedCategory: SetupCategory = .appPreferences
    @State private var configurationStatus: String = "No configuration import/export yet."
    @State private var configurationAuditSummary: ConfigurationAuditSummary?
    @State private var resetStatus: String = "No reset actions have been performed."
    @State private var networkInterfaces: [NetworkInterfaceSnapshot] = NetworkInventoryService.currentIPv4Interfaces()

    // MARK: - Body

    var body: some View {
        ZStack {
            setupBackground

            VStack(alignment: .leading, spacing: 14) {
                header
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                HStack(spacing: 0) {
                    sidebar

                    Divider()
                        .opacity(0.35)

                    contentPanel
                }
            }
        }
        .lccWindowPresentation(title: "LCC - Preferences", metrics: LCCLayout.Window.preferences)
        .onAppear {
            appState.refreshLaunchAtStartupStatus()
            appState.refreshSleepPreventionStatus()
            refreshNetworkInterfaces()
        }
    }

    // MARK: - Background

    private var setupBackground: some View {
        LinearGradient(
            colors: [
                LCCDesign.ColorToken.windowBackground,
                LCCDesign.ColorToken.controlBackground.opacity(0.58)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Header

    private var header: some View {
        LCCWindowTopChrome(
            title: "Preferences",
            subtitle: "Configure project settings, app preferences, import/export, and reset options.",
            systemImage: "gearshape.fill"
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            sidebarHeader

            VStack(alignment: .leading, spacing: 8) {
                ForEach(SetupCategory.allCases) { category in
                    sidebarButton(category)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 210)
        .background(
            LCCDesign.ColorToken.controlBackground
                .opacity(0.30)
        )
    }

    private var sidebarHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LCCDesign.ColorToken.active.opacity(0.18))
                    .frame(width: 42, height: 42)

                Image(systemName: "sidebar.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.active)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Settings")
                    .font(.title2)
                    .bold()

                Text("Settings and backups.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.bottom, 4)
    }

    private func sidebarButton(_ category: SetupCategory) -> some View {
        Button {
            selectedCategory = category
        } label: {
            HStack(spacing: 10) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 18)

                Text(category.sidebarTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selectedCategory == category ? .primary : .secondary)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(selectedCategory == category ? LCCDesign.selectedFill() : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    selectedCategory == category ? LCCDesign.ColorToken.active.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Content Panel

    private var contentPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            contentHeader

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedCategory {
                    case .appPreferences:
                        appPreferencesCard

                    case .network:
                        networkInventoryCard

                    case .projectPreferences:
                        projectPreferencesCard
                        volumeControlCard

                    case .importExport:
                        configurationBackupCard

                    case .resetDefaults:
                        resetDefaultsCard
                    }
                }
                .padding(.trailing, 6)
                .padding(.bottom, 20)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LCCDesign.selectedFill())
                    .frame(width: 40, height: 40)

                Image(systemName: selectedCategory.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.active)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedCategory.contentTitle)
                    .font(.largeTitle)
                    .bold()

                Text(selectedCategory.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - App Preferences

    private var appPreferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "App Preferences",
                subtitle: "Controls application behavior and display."
            )

            preferenceRow(
                systemImage: "desktopcomputer",
                title: "Device Name",
                subtitle: "Hostname used inside generated Syslog messages."
            ) {
                TextField(
                    "Device Name",
                    text: $appState.syslogDeviceName
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 220)
            }

            setupDivider

            preferenceRow(
                systemImage: "clock.fill",
                title: "Time Format",
                subtitle: appState.use24HourTime ? "Using 24-hour time." : "Using 12-hour time."
            ) {
                Picker("", selection: $appState.use24HourTime) {
                    Text("12-Hour").tag(false)
                    Text("24-Hour").tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            preferenceRow(
                systemImage: "calendar",
                title: "Week Starts On",
                subtitle: "Used by the Schedule weekly and monthly views."
            ) {
                Picker("", selection: $appState.weekStartDay) {
                    Text("Sunday").tag(1)
                    Text("Monday").tag(2)
                    Text("Tuesday").tag(3)
                    Text("Wednesday").tag(4)
                    Text("Thursday").tag(5)
                    Text("Friday").tag(6)
                    Text("Saturday").tag(7)
                }
                .labelsHidden()
                .frame(width: 180)
            }

            setupDivider

            preferenceRow(
                systemImage: "dock.rectangle",
                title: "Dock Icon Visibility",
                subtitle: appState.dockIconVisibilityPreference.preferenceDescription
            ) {
                Picker(
                    "",
                    selection: $appState.dockIconVisibilityPreference
                ) {
                    ForEach(DockIconVisibilityPreference.allCases) { preference in
                        Text(preference.displayName).tag(preference)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 270)
            }

            preferenceRow(
                systemImage: "power.circle.fill",
                title: "Launch App at Startup",
                subtitle: appState.launchAtStartupStatusMessage
            ) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: {
                            appState.launchAtStartupEnabled
                        },
                        set: { newValue in
                            appState.setLaunchAtStartupEnabled(newValue)
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }

            preferenceRow(
                systemImage: "moon.zzz.fill",
                title: "Prevent Computer Sleep",
                subtitle: appState.preventComputerSleepStatusMessage
            ) {
                Toggle(
                    "",
                    isOn: Binding(
                        get: {
                            appState.preventComputerSleepEnabled
                        },
                        set: { newValue in
                            appState.setPreventComputerSleepEnabled(newValue)
                        }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
            }

            setupDivider

            preferenceRow(
                systemImage: "clock.arrow.circlepath",
                title: "Operational Log Retention",
                subtitle: "Old log files are purged on app startup. Default is 90 days."
            ) {
                HStack(spacing: 6) {
                    TextField(
                        "90",
                        value: Binding(
                            get: {
                                appState.operationalLogRetentionDays
                            },
                            set: { newValue in
                                appState.operationalLogRetentionDays = min(max(newValue, 1), 3650)
                            }
                        ),
                        format: .number.grouping(.never)
                    )
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 72)

                    Text("days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            preferenceRow(
                systemImage: "doc.text.magnifyingglass",
                title: "Operational Logs",
                subtitle: "Open the folder containing long-running diagnostic log files."
            ) {
                Button {
                    appState.openLogsFolder()
                } label: {
                    Label("Open Logs Folder", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            setupDivider

            Text("Syslog Device Name and Dock Icon visibility are stored on this Mac and are not included in configuration import/export. This allows each playback or control computer to identify itself independently.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            Text("Prevent Computer Sleep keeps the Mac awake while Launch Control Center is running. It does not prevent sleep caused by closing a laptop lid, low battery, shutdown, restart, or choosing Sleep manually.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            Text("Operational logs are disposable diagnostic files. Project configurations, Actions, and scheduled Events are not purged automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func preferenceRow<Trailing: View>(
        systemImage: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LCCDesign.ColorToken.active)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            trailing()
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Network Inventory

    private var networkInventoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Network Inventory",
                subtitle: "Read-only snapshot of local IPv4 interfaces."
            )

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "network")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.active)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Local IPv4 Interfaces")
                        .font(.subheadline)
                        .bold()

                    Text("This panel reports available local IPv4 addresses only. It does not bind UDP sends, change routing, open ports, or change listener behavior.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button {
                    refreshNetworkInterfaces()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(insetPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if networkInterfaces.isEmpty {
                emptyNetworkInventoryView
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(networkInterfaces) { interface in
                        networkInterfaceRow(interface)
                    }
                }
            }

            setupDivider

            Text("Future network-health features may use this inventory for per-message source hints, broadcast support, and listener-interface selection. Automatic macOS routing remains unchanged in this pass.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var emptyNetworkInventoryView: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LCCDesign.ColorToken.warning)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text("No IPv4 interfaces found")
                    .font(.subheadline)
                    .bold()

                Text("Refresh after connecting a network adapter or assigning an IPv4 address.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func networkInterfaceRow(_ interface: NetworkInterfaceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: interface.availabilitySystemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(networkAvailabilityColor(for: interface))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(interface.displayName)
                        .font(.subheadline)
                        .bold()

                    Text(interface.availabilityText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(interface.ipv4Address)
                    .font(.system(.body, design: .monospaced))
                    .monospacedDigit()
                    .textSelection(.enabled)
            }

            HStack(alignment: .top, spacing: 10) {
                networkInterfaceDetail(label: "Netmask", value: interface.netmask ?? "—")
                networkInterfaceDetail(label: "Broadcast", value: interface.broadcastAddress ?? "—")
                networkInterfaceDetail(label: "Broadcast Capable", value: interface.supportsBroadcastText)
            }
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func networkInterfaceDetail(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func networkAvailabilityColor(for interface: NetworkInterfaceSnapshot) -> Color {
        if interface.isLoopback {
            return LCCDesign.ColorToken.active
        }

        if interface.isUp && interface.isRunning {
            return LCCDesign.ColorToken.success
        }

        if interface.isUp {
            return LCCDesign.ColorToken.warning
        }

        return LCCDesign.ColorToken.error
    }

    private func refreshNetworkInterfaces() {
        networkInterfaces = NetworkInventoryService.currentIPv4Interfaces()
    }

    // MARK: - Project Preferences

    private var projectPreferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Project",
                subtitle: "Identity and operator notes for this project."
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Project Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Project Name", text: $appState.projectName)
                    .textFieldStyle(.roundedBorder)

                Text("Shown across the Dashboard and menu bar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Project Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $appState.projectNotes)
                    .font(.body)
                    .frame(minHeight: 110)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(LCCDesign.ColorToken.textBackground.opacity(0.22))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
                    )

                Text("Internal notes for operators, reminders, or handoff context. Stored with this project and included in configuration import/export.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var volumeControlCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Volume Control",
                subtitle: "UDP output and Dashboard preset levels."
            )

            volumeUDPOutputSection

            setupDivider

            volumePresetsSection
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var volumeUDPOutputSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Volume UDP Output",
                subtitle: "Defines the UDP message sent when playback volume changes."
            )

            HStack(alignment: .top, spacing: 12) {
                labeledTextField(
                    label: "Destination Host",
                    text: $appState.volumeDestinationHost
                )

                labeledIntegerField(
                    label: "Destination Port",
                    value: $appState.volumeDestinationPort,
                    width: 140
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Message Prefix")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Message Prefix", text: $appState.volumeMessagePrefix)
                    .textFieldStyle(.roundedBorder)

                Text("The scaled value is appended directly after this prefix. Include any needed slash, space, comma, or separator.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Dashboard Slider Range")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 12) {
                    labeledDoubleField(
                        label: "Slider Minimum",
                        value: $appState.volumeOutputMinimum,
                        width: 150
                    )

                    labeledDoubleField(
                        label: "Slider Maximum",
                        value: $appState.volumeOutputMaximum,
                        width: 150
                    )

                    labeledDoubleField(
                        label: "Mute Level",
                        value: $appState.volumeMuteLevel,
                        width: 150
                    )

                    Spacer()
                }

                Text("Mute Level may sit outside the slider range. Changes send the current volume message immediately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            volumeOutputPreview
        }
    }

    private var volumeOutputPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                previewLine(label: "Mute", value: appState.volumeMuteLevel)
                previewLine(label: "Min", value: appState.volumeSliderLowerBound)
                previewLine(label: "50%", value: appState.scaledVolumeOutputValue(for: 0.5))
                previewLine(label: "Max", value: appState.volumeSliderUpperBound)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(insetPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func previewLine(label: String, value: Double) -> some View {
        let formattedValue = appState.formattedVolumeOutputValue(value)

        return HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            Text("\(appState.volumeMessagePrefix)\(formattedValue)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()
        }
    }

    private var volumePresetsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Volume Presets",
                subtitle: "Defines Dashboard volume buttons and Utility preset options."
            )

            volumePresetRow(
                title: "Low",
                subtitle: "Quiet playback level",
                systemImage: "speaker.wave.1.fill",
                value: $appState.lowVolumeLevel
            )

            volumePresetRow(
                title: "Normal",
                subtitle: "Standard playback level",
                systemImage: "speaker.wave.2.fill",
                value: $appState.normalVolumeLevel
            )

            volumePresetRow(
                title: "High",
                subtitle: "High playback level",
                systemImage: "speaker.wave.3.fill",
                value: $appState.highVolumeLevel
            )
        }
    }

    private func volumePresetRow(
        title: String,
        subtitle: String,
        systemImage: String,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(LCCDesign.selectedFill(opacity: 0.16))
                        .frame(width: 32, height: 32)

                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(LCCDesign.ColorToken.active)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .bold()

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(Int(value.wrappedValue * 100))%")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            Slider(value: value, in: 0...1)
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Import / Export

    private var configurationBackupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Configuration Backup",
                subtitle: "Export or replace the full project configuration."
            )

            HStack(spacing: 12) {
                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.active)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Full Configuration File")
                        .font(.subheadline)
                        .bold()

                    Text("Includes settings, Actions, scheduled Events, repeats, exclusions, notes, and volume output settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(12)
            .background(insetPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    exportConfiguration()
                } label: {
                    Label("Export Configuration", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    importConfiguration()
                } label: {
                    Label("Import Configuration", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Text(configurationStatus)
                .font(.caption)
                .foregroundStyle(configurationStatusColor)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(insetPanelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let configurationAuditSummary,
               configurationAuditSummary.issues.isEmpty == false {
                configurationAuditCard(for: configurationAuditSummary)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var configurationStatusColor: Color {
        guard let configurationAuditSummary else {
            return .secondary
        }

        if configurationAuditSummary.hasErrors {
            return LCCDesign.ColorToken.error
        }

        if configurationAuditSummary.hasWarnings {
            return LCCDesign.ColorToken.warning
        }

        return LCCDesign.ColorToken.success
    }

    private func configurationAuditCard(for summary: ConfigurationAuditSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: summary.hasErrors ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(summary.hasErrors ? LCCDesign.ColorToken.error : LCCDesign.ColorToken.warning)

                Text("Schedule Check")
                    .font(.subheadline)
                    .bold()

                Text(auditCountSummary(for: summary))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(summary.issues.enumerated()), id: \.offset) { _, issue in
                HStack(alignment: .top, spacing: 8) {
                    Text(issue.severity.displayName)
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(issue.severity == .error ? LCCDesign.ColorToken.error : LCCDesign.ColorToken.warning)
                        .frame(width: 54, alignment: .leading)

                    Text(issue.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(10)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func auditCountSummary(for summary: ConfigurationAuditSummary) -> String {
        let errorCount = summary.issues.filter { $0.severity == .error }.count
        let warningCount = summary.issues.filter { $0.severity == .warning }.count
        var parts: [String] = []

        if errorCount > 0 {
            parts.append("\(errorCount) error\(errorCount == 1 ? "" : "s")")
        }

        if warningCount > 0 {
            parts.append("\(warningCount) warning\(warningCount == 1 ? "" : "s")")
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Reset / Defaults

    private var resetDefaultsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Reset / Defaults",
                subtitle: "Destructive maintenance actions for this Mac and project."
            )

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.warning)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Use these only when you are intentionally clearing or rebuilding setup data.")
                        .font(.subheadline)
                        .bold()

                    Text("Each command asks for confirmation before it runs. Deleted Actions and Events cannot be recovered unless you previously exported a configuration backup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(12)
            .background(insetPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            resetActionRow(
                operation: .appPreferences,
                systemImage: "macwindow",
                title: "Restore Default App Preferences",
                subtitle: "Resets time display, week start, syslog name, Dock icon behavior, startup, sleep prevention, and log retention."
            )

            resetActionRow(
                operation: .projectPreferences,
                systemImage: "slider.horizontal.3",
                title: "Restore Default Project Preferences",
                subtitle: "Resets project identity, notes, UDP defaults, schedule enable messages, volume output, volume presets, and current volume."
            )

            resetActionRow(
                operation: .events,
                systemImage: "calendar.badge.minus",
                title: "Delete All Events",
                subtitle: "Deletes all scheduled Events, recurrence data, exclusions, and schedule execution history. Actions remain untouched."
            )

            resetActionRow(
                operation: .actionsAndEvents,
                systemImage: "trash.fill",
                title: "Delete All Actions & Events",
                subtitle: "Deletes all Actions, scheduled Events, recurrence data, exclusions, and schedule execution history."
            )

            Text(resetStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(insetPanelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func resetActionRow(
        operation: ResetOperation,
        systemImage: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(operation.isDestructive ? LCCDesign.ColorToken.error : LCCDesign.ColorToken.active)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Button {
                performReset(operation)
            } label: {
                Text(operation.buttonTitle)
                    .frame(width: 132)
            }
            .buttonStyle(.bordered)
            .tint(operation.isDestructive ? LCCDesign.ColorToken.error : LCCDesign.ColorToken.active)
            .controlSize(.small)
        }
        .padding(12)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func performReset(_ operation: ResetOperation) {
        guard confirmReset(operation) else {
            resetStatus = "Reset cancelled."
            return
        }

        do {
            switch operation {
            case .appPreferences:
                try appState.restoreDefaultAppPreferences()

            case .projectPreferences:
                try appState.restoreDefaultProjectPreferences()

            case .events:
                try appState.deleteAllEvents()

            case .actionsAndEvents:
                try appState.deleteAllActionsAndEvents()
            }

            resetStatus = operation.successMessage
        } catch {
            resetStatus = "Reset failed: \(error.localizedDescription)"
        }
    }

    private func confirmReset(_ operation: ResetOperation) -> Bool {
        let alert = NSAlert()
        alert.messageText = operation.confirmationTitle
        alert.informativeText = operation.confirmationMessage
        alert.alertStyle = operation.isDestructive ? .critical : .warning
        alert.addButton(withTitle: operation.confirmButtonTitle)
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        return response == .alertFirstButtonReturn
    }

    // MARK: - Export

    private func exportConfiguration() {
        let panel = NSSavePanel()
        panel.title = "Export Launch Control Configuration"
        panel.nameFieldStringValue = defaultConfigurationFileNameWithoutExtension()
        panel.allowedContentTypes = [launchControlFileType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        let response = panel.runModal()

        guard response == .OK,
              let url = panel.url else {
            configurationStatus = "Export cancelled."
            configurationAuditSummary = nil
            return
        }

        let finalURL = urlWithLaunchControlExtension(url)

        do {
            try appState.exportConfiguration(to: finalURL)

            let summary = appState.currentConfigurationAuditSummary()
            configurationAuditSummary = summary
            configurationStatus = "Exported \(finalURL.lastPathComponent). \(summaryLine(for: summary))"
        } catch {
            configurationAuditSummary = nil
            configurationStatus = "Export failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Import

    private func importConfiguration() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Import Launch Control Configuration"
        openPanel.allowedContentTypes = [launchControlFileType, .json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true

        let response = openPanel.runModal()

        guard response == .OK,
              let url = openPanel.url else {
            configurationStatus = "Import cancelled."
            configurationAuditSummary = nil
            return
        }

        do {
            let preview = try appState.previewConfigurationImport(from: url)

            guard confirmImportReplacement(preview: preview) else {
                configurationStatus = "Import cancelled."
                configurationAuditSummary = preview.summary
                return
            }

            try appState.importConfiguration(from: url)
            configurationAuditSummary = preview.summary
            configurationStatus = "Imported \(url.lastPathComponent). \(summaryLine(for: preview.summary))"
        } catch {
            configurationAuditSummary = nil
            configurationStatus = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Configuration File Helpers

    private var launchControlFileType: UTType {
        UTType(filenameExtension: "launchcontrol") ?? .json
    }

    private func defaultConfigurationFileNameWithoutExtension() -> String {
        let project = sanitizedFileName(appState.projectName)
        let dateStamp = reverseDateStamp(Date())

        return "\(project)_\(dateStamp)"
    }

    private static let reverseDateStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private func reverseDateStamp(_ date: Date) -> String {
        SetupView.reverseDateStampFormatter.string(from: date)
    }

    private func urlWithLaunchControlExtension(_ url: URL) -> URL {
        if url.pathExtension.lowercased() == "launchcontrol" {
            return url
        }

        return url.deletingPathExtension().appendingPathExtension("launchcontrol")
    }

    private func confirmImportReplacement(preview: ConfigurationImportPreview) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Replace Current Configuration?"
        alert.informativeText = importConfirmationText(for: preview)
        alert.alertStyle = preview.summary.hasErrors ? .critical : .warning
        alert.addButton(withTitle: "Import and Replace")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        return response == .alertFirstButtonReturn
    }

    private func importConfirmationText(for preview: ConfigurationImportPreview) -> String {
        var lines: [String] = []

        lines.append("Importing \(preview.fileName) will replace the current settings, Actions, and scheduled Events.")
        lines.append("")
        lines.append("Imported Configuration")
        lines.append(configurationSummaryText(for: preview.summary))

        if preview.summary.issues.isEmpty == false {
            lines.append("")
            lines.append("Schedule Check")

            for issue in preview.summary.issues.prefix(8) {
                let prefix = issue.severity == .error ? "Error" : "Warning"
                lines.append("• \(prefix): \(issue.message)")
            }

            if preview.summary.issues.count > 8 {
                lines.append("• …and \(preview.summary.issues.count - 8) more issue(s).")
            }
        }

        lines.append("")
        lines.append("This cannot be undone from within Launch Control Center. Export the current configuration first if you may need to return to it.")

        return lines.joined(separator: "\n")
    }

    private func configurationSummaryText(for summary: ConfigurationAuditSummary) -> String {
        var lines: [String] = []

        lines.append("Project: \(summary.projectName)")
        lines.append("Version: \(summary.version)")
        lines.append("Exported: \(Self.configurationDateFormatter.string(from: summary.exportedAt))")
        lines.append("Actions: \(summary.actionCount)")
        lines.append("Events: \(summary.eventCount) total — \(summary.standaloneEventCount) standalone, \(summary.recurringSeriesCount) recurring series")
        lines.append("Interval Series: \(summary.intervalSeriesCount)")
        lines.append("Disabled Events: \(summary.disabledEventCount)")
        lines.append("Removed Occurrences: \(summary.removedOccurrenceCount)")

        if summary.openEndedSeriesCount > 0 {
            lines.append("Generated Events: \(summary.finiteGeneratedEventCount) finite, plus \(summary.openEndedSeriesCount) open-ended series")
        } else {
            lines.append("Generated Events: \(summary.finiteGeneratedEventCount)")
        }

        lines.append("Schedule Check: \(summary.statusText)")

        return lines.joined(separator: "\n")
    }

    private func summaryLine(for summary: ConfigurationAuditSummary) -> String {
        "Actions: \(summary.actionCount). Events: \(summary.eventCount). Recurring Series: \(summary.recurringSeriesCount). Schedule Check: \(summary.statusText)."
    }

    private static let configurationDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func sanitizedFileName(_ value: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")

        let cleaned = value
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? "Launch-Control-Configuration" : cleaned
    }

    // MARK: - Field Helpers

    private func labeledTextField(
        label: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func labeledIntegerField(
        label: String,
        value: Binding<Int>,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                label,
                value: value,
                format: .number.grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
        }
    }

    private func labeledDoubleField(
        label: String,
        value: Binding<Double>,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                label,
                value: value,
                format: .number
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
        }
    }

    // MARK: - Shared UI

    private var setupDivider: some View {
        Divider()
            .opacity(0.42)
            .padding(.vertical, 2)
    }

    private func sectionHeader(
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Styling

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LCCDesign.ColorToken.controlBackground.opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }

    private var insetPanelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(LCCDesign.ColorToken.textBackground.opacity(0.18))
    }
}

// MARK: - Setup Category

private enum SetupCategory: String, CaseIterable, Identifiable {
    case appPreferences
    case network
    case projectPreferences
    case importExport
    case resetDefaults

    var id: String {
        sidebarTitle
    }

    var sidebarTitle: String {
        switch self {
        case .appPreferences:
            return "App"

        case .network:
            return "Network"

        case .projectPreferences:
            return "Project"

        case .importExport:
            return "Import / Export"

        case .resetDefaults:
            return "Reset / Defaults"
        }
    }

    var contentTitle: String {
        switch self {
        case .appPreferences:
            return "App Preferences"

        case .network:
            return "Network"

        case .projectPreferences:
            return "Project Preferences"

        case .importExport:
            return "Import / Export"

        case .resetDefaults:
            return "Reset / Defaults"
        }
    }

    var systemImage: String {
        switch self {
        case .appPreferences:
            return "macwindow"

        case .network:
            return "network"

        case .projectPreferences:
            return "slider.horizontal.3"

        case .importExport:
            return "externaldrive.fill"

        case .resetDefaults:
            return "exclamationmark.triangle.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .appPreferences:
            return "Application behavior and display preferences."

        case .network:
            return "Read-only local IPv4 interface inventory."

        case .projectPreferences:
            return "Project identity, notes, playback presets, and UDP output."

        case .importExport:
            return "Save or load full Launch Control configurations."

        case .resetDefaults:
            return "Restore defaults or delete stored project data."
        }
    }
}

// MARK: - Reset Operation

private enum ResetOperation {
    case appPreferences
    case projectPreferences
    case events
    case actionsAndEvents

    var isDestructive: Bool {
        switch self {
        case .appPreferences, .projectPreferences:
            return false

        case .events, .actionsAndEvents:
            return true
        }
    }

    var buttonTitle: String {
        switch self {
        case .appPreferences, .projectPreferences:
            return "Restore"

        case .events, .actionsAndEvents:
            return "Delete"
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .appPreferences:
            return "Restore App Defaults"

        case .projectPreferences:
            return "Restore Project Defaults"

        case .events:
            return "Delete Events"

        case .actionsAndEvents:
            return "Delete Actions & Events"
        }
    }

    var confirmationTitle: String {
        switch self {
        case .appPreferences:
            return "Restore Default App Preferences?"

        case .projectPreferences:
            return "Restore Default Project Preferences?"

        case .events:
            return "Delete All Events?"

        case .actionsAndEvents:
            return "Delete All Actions & Events?"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .appPreferences:
            return "This will restore app-level preferences on this Mac, including time display, week start, syslog name, Dock icon behavior, launch-at-startup, sleep prevention, and log retention.\n\nThis cannot be undone."

        case .projectPreferences:
            return "This will restore project preferences to their defaults, including project name, notes, UDP defaults, schedule enable messages, volume output settings, volume presets, and current volume.\n\nActions and scheduled Events will not be deleted. This cannot be undone."

        case .events:
            return "This will permanently delete all scheduled Events, recurrence data, removed occurrences, and schedule execution history.\n\nActions will remain available. This cannot be undone. Export a configuration first if you may need to recover this schedule."

        case .actionsAndEvents:
            return "This will permanently delete all Actions, scheduled Events, recurrence data, removed occurrences, and schedule execution history.\n\nThis cannot be undone. Export a configuration first if you may need to recover this project."
        }
    }

    var successMessage: String {
        switch self {
        case .appPreferences:
            return "Restored default app preferences."

        case .projectPreferences:
            return "Restored default project preferences."

        case .events:
            return "Deleted all Events."

        case .actionsAndEvents:
            return "Deleted all Actions and Events."
        }
    }
}


