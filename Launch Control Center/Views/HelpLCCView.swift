//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: HelpLCCView.swift
//  Purpose: Baseline operating instructions and app help window.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI

struct HelpLCCView: View {
    // MARK: - Body

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 18) {
                header

                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 16) {
                        overviewCard
                        workflowCard
                        dashboardCard
                        defineActionsCard
                        addEventsCard
                        scheduleCard
                        preferencesCard
                        importExportCard
                        resetDefaultsCard
                        udpAndSyslogCard
                        operatingNotesCard
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 20)
                }
            }
            .padding(22)
        }
        .lccWindowPresentation(title: "LCC - Help", metrics: LCCLayout.Window.help)
    }

    // MARK: - Header

    private var header: some View {
        LCCWindowTopChrome(
            title: "Help",
            subtitle: "Reference operating notes and workflow guidance.",
            systemImage: "questionmark.circle.fill",
            iconSize: 54
        )
    }

    // MARK: - Help Cards

    private var overviewCard: some View {
        helpCard(
            title: "Overview",
            systemImage: "paperplane.fill"
        ) {
            helpParagraph(
                "Launch Control Center is an operator-assist scheduling and playback utility for themed environments, show systems, and other controlled experiences."
            )

            helpParagraph(
                "The app is organized around reusable Actions, scheduled Events, operator controls, and project configuration tools."
            )

            helpBullets([
                "Actions define what the app can do.",
                "Events define when Actions should run.",
                "The Dashboard provides live operator controls and schedule status.",
                "Preferences control app behavior, project metadata, volume output, import/export, and reset tools."
            ])
        }
    }

    private var workflowCard: some View {
        helpCard(
            title: "Recommended Workflow",
            systemImage: "list.bullet.rectangle"
        ) {
            helpBullets([
                "Start in Define Actions and create the Show Actions and Utility Actions your project needs.",
                "Test Actions manually before scheduling them.",
                "Use Add Events to schedule one-time or repeating playback.",
                "Review the generated Events before adding them to the calendar.",
                "Use Schedule to inspect, filter, run, edit, or delete Events.",
                "Use Dashboard during operation for manual playback, schedule toggles, volume control, and today’s Events.",
                "Export a configuration backup after major setup changes."
            ])
        }
    }

    private var dashboardCard: some View {
        helpCard(
            title: "Dashboard",
            systemImage: "rectangle.grid.1x2"
        ) {
            helpParagraph(
                "The Dashboard is the primary operator view during playback."
            )

            helpBullets([
                "Manual Action buttons run Actions immediately.",
                "Manual Actions are not affected by the Show Actions or Utility Actions schedule toggles.",
                "Show Actions and Utility Actions toggles affect scheduled Events only.",
                "The Volume section controls the configured volume UDP output and applies Mute, Low, Normal, and High presets.",
                "The Events section shows the next scheduled Event and the most recent Event run.",
                "Today’s Events shows the current day’s Events, with past Events dimmed and the next Event highlighted."
            ])
        }
    }

    private var defineActionsCard: some View {
        helpCard(
            title: "Define Actions",
            systemImage: "rectangle.stack.badge.play"
        ) {
            helpParagraph(
                "Actions are reusable command sequences that can be run manually from the Dashboard or triggered by scheduled Events."
            )

            helpBullets([
                "Show Actions contain message steps such as Standard UDP or Syslog messages.",
                "Utility Actions perform app-level operations such as setting volume, enabling or disabling scheduled Show or Utility Events, running another Action, or sending UDP.",
                "Each step can include a delay. A delay of 0 runs the next step as quickly as the app and network can process it.",
                "Use Duplicate Action to copy an existing Action and safely generate new Action and step IDs.",
                "Deleting an Action asks for confirmation and warns when scheduled Events currently use it.",
                "Use notes to document operator reminders, dependencies, or intent.",
                "The Action runtime safety limit prevents a single Action from running longer than two minutes."
            ])
        }
    }

    private var addEventsCard: some View {
        helpCard(
            title: "Add Events",
            systemImage: "calendar.badge.plus"
        ) {
            helpParagraph(
                "Add Events creates one-time Events or generated repeating Event series from an existing Action."
            )

            helpBullets([
                "Choose the Action first, then set the start date and 24-hour start time.",
                "With Repeat off, the app creates one Event at the selected date and time.",
                "With Repeat on, choose the end date, selected weekdays, and time pattern.",
                "Use Once per selected day for one Event on each selected day.",
                "Use Repeat during selected days to generate multiple Events at a fixed minute interval until the daily final run time.",
                "The Preview panel audits generated Events before they are added to the schedule."
            ])
        }
    }

    private var scheduleCard: some View {
        helpCard(
            title: "Schedule",
            systemImage: "calendar"
        ) {
            helpParagraph(
                "Schedule is used to review, filter, run, edit, and delete scheduled Event occurrences."
            )

            helpBullets([
                "Calendar View supports Day, Week, and Month views.",
                "List View provides a tabular view for review and management.",
                "Use the filter menu to focus on all Events, Show Events, Utility Events, repeating Events, standalone Events, past Events, or future Events.",
                "Use Scale to adjust calendar vertical spacing.",
                "Right-click Events for Run, Edit, or Delete options. Double-click an Event to edit it.",
                "Deleting from Schedule asks for confirmation before removing a one-time Event, one occurrence, or an entire series.",
                "Deleting from Today’s Events also asks for confirmation."
            ])
        }
    }

    private var preferencesCard: some View {
        helpCard(
            title: "Preferences",
            systemImage: "gearshape.fill"
        ) {
            helpBullets([
                "App Preferences control Device Name, time format, week start day, Dock icon visibility, startup behavior, sleep prevention, and operational log retention.",
                "Project Preferences control project name, project notes, volume UDP output, and volume presets.",
                "Device Name is used inside generated Syslog messages.",
                "Dock Icon Visibility controls when the macOS Dock icon appears.",
                "Launch App at Startup asks macOS to open Launch Control Center when the user logs in.",
                "Prevent Computer Sleep keeps the Mac from idle-sleeping while Launch Control Center is running, but does not override laptop lid closure, low battery, shutdown, restart, or manual Sleep."
            ])
        }
    }

    private var importExportCard: some View {
        helpCard(
            title: "Import / Export",
            systemImage: "externaldrive.fill"
        ) {
            helpParagraph(
                "Import and export tools are used to back up or restore project configuration files."
            )

            helpBullets([
                "Export Configuration saves app settings, project settings, Actions, scheduled Events, repeats, exclusions, notes, volume output settings, volume presets, and current volume state.",
                "Import Configuration opens a selective import dialog so you can merge with the current show, replace selected categories, or import into a new blank show.",
                "Events can only be imported when Actions are also imported, which avoids creating abandoned Events.",
                "Automatic backups are created before import, restore, and reset operations.",
                "Restore from Automatic Backup can recover a recent pre-import or pre-reset configuration.",
                "Export Diagnostic Bundle creates a ZIP with the current configuration, schedule check, configuration health report, network inventory, app/system information, and recent operational logs.",
                "Import, restore, and reset operations are blocked while an Action is running to avoid changing configuration during playback."
            ])
        }
    }

    private var resetDefaultsCard: some View {
        helpCard(
            title: "Reset / Defaults",
            systemImage: "exclamationmark.triangle.fill"
        ) {
            helpParagraph(
                "Reset tools remove stored data or restore default settings. These actions cannot be undone."
            )

            helpBullets([
                "Restore Default App Preferences resets app-level preferences stored on this Mac.",
                "Restore Default Project Preferences resets project metadata, volume output settings, volume presets, and current volume state.",
                "Delete All Events removes scheduled Events, recurrence data, exclusions, and schedule execution history.",
                "Delete All Actions & Events removes all Actions and scheduled Events.",
                "Reset and delete operations are blocked while an Action is running."
            ])
        }
    }

    private var udpAndSyslogCard: some View {
        helpCard(
            title: "UDP and Syslog Messages",
            systemImage: "network"
        ) {
            helpBullets([
                "Standard UDP steps send a message to a configured host and port.",
                "Syslog steps send generated Syslog messages using the configured Device Name and selected severity.",
                "Volume controls send UDP messages using the configured volume host, port, prefix, minimum, maximum, and mute level.",
                "UDP delivery is connectionless; receiving equipment may not report errors back to the app.",
                "Use IP addresses when practical to avoid DNS delays during show playback.",
                "Always confirm behavior at the receiving device or system."
            ])
        }
    }

    private var operatingNotesCard: some View {
        helpCard(
            title: "Operating Notes",
            systemImage: "checklist"
        ) {
            helpBullets([
                "Before show use, run and verify every Action that may be triggered manually or by schedule.",
                "Confirm all UDP destinations, ports, message syntax, and connected equipment behavior.",
                "Confirm the computer clock, date, timezone, and time format before relying on scheduled Events.",
                "Enable Prevent Computer Sleep when scheduled Events must continue unattended.",
                "For critical operation, also verify macOS Battery/Energy settings, power adapter, display settings, laptop lid behavior, and network stability.",
                "Keep the Dashboard visible during operation when practical.",
                "Keep a recent exported configuration backup before major edits.",
                "Export a Diagnostic Bundle when troubleshooting behavior or preparing support handoff.",
                "Operators remain responsible for confirming show conditions and connected system behavior before live operation."
            ])
        }
    }

    // MARK: - Shared Help UI

    private func helpCard<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.active)
                    .frame(width: 22)

                Text(title)
                    .font(.headline)

                Spacer()
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func helpParagraph(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
    }

    private func helpBullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(LCCDesign.ColorToken.active)

                    Text(item)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var background: some View {
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

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LCCDesign.ColorToken.controlBackground.opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }
}
