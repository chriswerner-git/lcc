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

    // MARK: - Body

    var body: some View {
        ZStack {
            setupBackground

            HStack(spacing: 0) {
                sidebar

                Divider()
                    .opacity(0.35)

                contentPanel
            }
        }
        .frame(width: 840, height: 720)
        .onAppear {
            appState.refreshLaunchAtStartupStatus()
            appState.refreshSleepPreventionStatus()
        }
    }

    // MARK: - Background

    private var setupBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color(nsColor: .controlBackgroundColor).opacity(0.58)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
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
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.30)
        )
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 42, height: 42)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Preferences")
                    .font(.title2)
                    .bold()

                Text("Settings and backups.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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

                Text(category.rawValue)
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
                .fill(selectedCategory == category ? Color.blue.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    selectedCategory == category ? Color.blue.opacity(0.35) : Color.clear,
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

                    case .projectPreferences:
                        projectCard
                        projectNotesCard
                        volumeUDPOutputCard
                        volumePresetsCard

                    case .importExport:
                        configurationBackupCard
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
                    .fill(Color.blue.opacity(0.18))
                    .frame(width: 40, height: 40)

                Image(systemName: selectedCategory.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(selectedCategory.rawValue)
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

            Text("Prevent Computer Sleep keeps the Mac awake while Launch Control Center is running. It does not prevent sleep caused by closing a laptop lid, low battery, shutdown, restart, or choosing Sleep manually.")
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
                .foregroundStyle(.blue)
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

    // MARK: - Project Preferences

    private var projectCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Project",
                subtitle: "Name shown across Dashboard and menu bar."
            )

            VStack(alignment: .leading, spacing: 5) {
                Text("Project Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Project Name", text: $appState.projectName)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var projectNotesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(
                title: "Project Notes",
                subtitle: "Internal notes for operators, context, reminders, or handoff details."
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $appState.projectNotes)
                    .font(.body)
                    .frame(minHeight: 110)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor).opacity(0.22))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )

                Text("Stored with this project and included in configuration import/export.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Volume UDP Output

    private var volumeUDPOutputCard: some View {
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

            HStack(alignment: .top, spacing: 12) {
                labeledDoubleField(
                    label: "Output at 0%",
                    value: $appState.volumeOutputMinimum,
                    width: 140
                )

                labeledDoubleField(
                    label: "Output at 100%",
                    value: $appState.volumeOutputMaximum,
                    width: 140
                )

                Spacer()
            }

            volumeOutputPreview
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var volumeOutputPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                previewLine(percent: 0)
                previewLine(percent: 50)
                previewLine(percent: 100)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(insetPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func previewLine(percent: Int) -> some View {
        let level = Double(percent) / 100
        let scaledValue = scaledPreviewValue(for: level)
        let formattedValue = formattedPreviewValue(scaledValue)

        return HStack {
            Text("\(percent)%")
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

    private func scaledPreviewValue(for level: Double) -> Double {
        let clampedLevel = min(max(level, 0), 1)
        let outputRange = appState.volumeOutputMaximum - appState.volumeOutputMinimum

        return appState.volumeOutputMinimum + (clampedLevel * outputRange)
    }

    private func formattedPreviewValue(_ value: Double) -> String {
        let roundedValue = (value * 1000).rounded() / 1000

        if roundedValue.rounded() == roundedValue {
            return String(Int(roundedValue))
        }

        return String(roundedValue)
    }

    // MARK: - Volume Presets

    private var volumePresetsCard: some View {
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
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                        .fill(Color.blue.opacity(0.16))
                        .frame(width: 32, height: 32)

                    Image(systemName: systemImage)
                        .font(.caption)
                        .foregroundStyle(.blue)
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
                    .foregroundStyle(.blue)

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
            return
        }

        let finalURL = urlWithLaunchControlExtension(url)

        do {
            try appState.exportConfiguration(to: finalURL)
            configurationStatus = "Exported configuration to \(finalURL.lastPathComponent)."
        } catch {
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
            return
        }

        guard confirmImportReplacement(fileName: url.lastPathComponent) else {
            configurationStatus = "Import cancelled."
            return
        }

        do {
            try appState.importConfiguration(from: url)
            configurationStatus = "Imported configuration from \(url.lastPathComponent)."
        } catch {
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

    private func reverseDateStamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"

        return formatter.string(from: date)
    }

    private func urlWithLaunchControlExtension(_ url: URL) -> URL {
        if url.pathExtension.lowercased() == "launchcontrol" {
            return url
        }

        return url.deletingPathExtension().appendingPathExtension("launchcontrol")
    }

    private func confirmImportReplacement(fileName: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Replace Current Configuration?"
        alert.informativeText = "Importing \(fileName) will replace the current settings, Actions, and scheduled Events."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Import and Replace")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        return response == .alertFirstButtonReturn
    }

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
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    }

    private var insetPanelBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(nsColor: .textBackgroundColor).opacity(0.18))
    }
}

// MARK: - Setup Category

private enum SetupCategory: String, CaseIterable, Identifiable {
    case appPreferences = "App Preferences"
    case projectPreferences = "Project Preferences"
    case importExport = "Import / Export"

    var id: String {
        rawValue
    }

    var systemImage: String {
        switch self {
        case .appPreferences:
            return "macwindow"

        case .projectPreferences:
            return "slider.horizontal.3"

        case .importExport:
            return "externaldrive.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .appPreferences:
            return "Application behavior and display preferences."

        case .projectPreferences:
            return "Project identity, notes, playback presets, and UDP output."

        case .importExport:
            return "Save or load full Launch Control configurations."
        }
    }
}
