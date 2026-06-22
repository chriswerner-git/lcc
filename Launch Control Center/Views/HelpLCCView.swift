//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
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
                        dashboardCard
                        actionsCard
                        scheduleCard
                        preferencesCard
                        importExportCard
                        udpTestCard
                        operatingNotesCard
                    }
                    .padding(.trailing, 8)
                    .padding(.bottom, 20)
                }
            }
            .padding(22)
        }
        .frame(width: 680, height: 760)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(LCCDesign.selectedFill())
                    .frame(width: 54, height: 54)

                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.active)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Launch Control Center Help")
                    .font(.largeTitle)
                    .bold()

                Text("Baseline operating instructions")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Help Cards

    private var overviewCard: some View {
        helpCard(
            title: "Overview",
            systemImage: "paperplane.fill"
        ) {
            helpParagraph(
                "Launch Control Center is an operator-assist tool for defining Actions, scheduling Events, sending UDP messages, and managing show or utility playback behavior."
            )

            helpParagraph(
                "The app is organized around three core ideas: Actions, Events, and Preferences."
            )

            helpBullets([
                "Actions define what the app can do.",
                "Events define when Actions should run.",
                "Preferences define app behavior, project settings, volume presets, startup behavior, computer sleep prevention, and configuration backups."
            ])
        }
    }

    private var dashboardCard: some View {
        helpCard(
            title: "Dashboard",
            systemImage: "rectangle.grid.1x2"
        ) {
            helpParagraph(
                "The Dashboard is the primary operator view."
            )

            helpBullets([
                "Use Manual Action buttons to run Actions immediately.",
                "Manual Actions are not affected by schedule enable/disable toggles.",
                "Use Show Actions and Utility Actions toggles to enable or disable scheduled Events only.",
                "Use the Volume section to set playback level or apply presets.",
                "The Events section shows the next scheduled Event and the most recent Event run.",
                "Today’s Events shows the current day’s schedule, with past Events dimmed."
            ])
        }
    }

    private var actionsCard: some View {
        helpCard(
            title: "Actions",
            systemImage: "rectangle.stack.badge.play"
        ) {
            helpParagraph(
                "Actions are reusable commands that can be run manually from the Dashboard or triggered by scheduled Events."
            )

            helpBullets([
                "Show Actions send UDP command steps.",
                "Utility Actions perform app-level operations such as setting volume, enabling/disabling schedules, running another Action, or sending UDP.",
                "Use Action notes to document intent, dependencies, or operator reminders.",
                "Test Actions before relying on them in a live environment."
            ])
        }
    }

    private var scheduleCard: some View {
        helpCard(
            title: "Schedule",
            systemImage: "calendar"
        ) {
            helpParagraph(
                "Scheduled Events trigger Actions at defined dates and times."
            )

            helpBullets([
                "One-time Events run once at the selected date and time.",
                "Repeating Events can run daily or on selected weekdays.",
                "Schedule views can be shown weekly or monthly.",
                "Deleting a repeating Event may remove one occurrence or the entire series, depending on the selected option.",
                "Scheduled Show Actions and Utility Actions can be enabled or disabled independently from the Dashboard.",
                "Schedule timing depends on the Mac remaining awake. Use Prevent Computer Sleep when the app must remain active."
            ])
        }
    }

    private var preferencesCard: some View {
        helpCard(
            title: "Preferences",
            systemImage: "gearshape.fill"
        ) {
            helpBullets([
                "App Preferences include time format, week start day, Launch App at Startup, and Prevent Computer Sleep.",
                "Launch App at Startup asks macOS to open Launch Control Center when the user logs in.",
                "Prevent Computer Sleep keeps the Mac from idle-sleeping while Launch Control Center is running.",
                "Prevent Computer Sleep does not prevent sleep caused by closing a laptop lid, low battery, shutdown, restart, or choosing Sleep manually.",
                "Project Preferences include project name, project notes, volume UDP output, and volume presets.",
                "Volume presets are Low, Normal, and High.",
                "Launch App at Startup and Prevent Computer Sleep are app/user/machine preferences and are not included in project configuration exports."
            ])
        }
    }

    private var importExportCard: some View {
        helpCard(
            title: "Import / Export",
            systemImage: "externaldrive.fill"
        ) {
            helpParagraph(
                "Configuration backups allow the full project configuration to be saved or restored."
            )

            helpBullets([
                "Export Configuration saves the current project settings, Actions, scheduled Events, repeats, exclusions, notes, and volume output settings.",
                "Import Configuration replaces the current project configuration.",
                "Review imported configurations before live use.",
                "Keep backup files in a safe project folder or version-controlled archive.",
                "App/user preferences such as Launch App at Startup and Prevent Computer Sleep are not exported with project configurations."
            ])
        }
    }

    private var udpTestCard: some View {
        helpCard(
            title: "UDP Tests",
            systemImage: "network"
        ) {
            helpBullets([
                "Use UDP Tests to verify network connectivity and message formatting.",
                "Confirm host, port, and message syntax before programming scheduled Events.",
                "UDP delivery is connectionless; receiving equipment may not report errors back to the app.",
                "Always confirm behavior at the controlled device or system."
            ])
        }
    }

    private var operatingNotesCard: some View {
        helpCard(
            title: "Operating Notes",
            systemImage: "exclamationmark.triangle.fill"
        ) {
            helpBullets([
                "Before show use, test all Actions from the Dashboard.",
                "Verify all UDP destinations, ports, and connected equipment.",
                "Confirm the computer clock and timezone are correct.",
                "Enable Prevent Computer Sleep when scheduled Events must continue running unattended.",
                "For critical operation, also confirm macOS battery, power adapter, display, lid, and Energy/Battery settings.",
                "Confirm scheduled Events are enabled and appear at the expected time.",
                "Keep a recent exported configuration backup before making major changes.",
                "Operators remain responsible for verifying system behavior before live operation."
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
