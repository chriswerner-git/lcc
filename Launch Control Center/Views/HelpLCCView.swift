//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: HelpLCCView.swift
//  Purpose: Baseline operating instructions and app help window using
//           LunarKit shared Help layout.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI
import LunarKit

struct HelpLCCView: View {
    // MARK: - Body

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: LCCLayout.Spacing.section) {
                LCCWindowTopChrome(
                    title: "Help",
                    subtitle: "Reference operating notes and workflow guidance.",
                    systemImage: "questionmark.circle.fill",
                    iconSize: 54,
                    showsHelpButton: false
                )

                LTCHelpShell(sections: helpSections)
            }
            .padding(LCCLayout.Spacing.windowPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .lccWindowPresentation(title: "LCC - Help", metrics: LCCLayout.Window.help)
    }

    // MARK: - Help Content

    private var helpSections: [LTCHelpSection] {
        [
            LTCHelpSection(
                title: "Overview",
                body: "Launch Control Center is an operator-assist scheduling and playback utility for themed environments, show systems, and other controlled experiences. The app is organized around reusable Actions, scheduled Events, operator controls, project preferences, and diagnostic tools."
            ),
            LTCHelpSection(
                title: "Recommended Workflow",
                body: "Create Show Actions and Utility Actions first. Test Actions manually before scheduling them. Add Events only after Actions are verified. Review the Dashboard and Schedule windows before relying on playback in rehearsal or production."
            ),
            LTCHelpSection(
                title: "Dashboard",
                body: "The Dashboard provides the main operator view: clock and time-sync information, configuration health, manual Actions, schedule toggles, volume control, upcoming Events, recent Events, and today’s schedule. Manual Actions are intentionally separate from schedule enable/disable toggles."
            ),
            LTCHelpSection(
                title: "Define Actions",
                body: "Actions define what the app can do. Show Actions are intended for show playback steps such as UDP and Syslog messages. Utility Actions are operational helpers such as enabling or disabling schedule categories, setting volume, running another Action, or sending standalone messages."
            ),
            LTCHelpSection(
                title: "Add Events and Schedule",
                body: "Events define when Actions run. Use Add Events for one-time and repeating playback. Use Schedule to review, edit, run, or delete Events and occurrences. Deleting a scheduled item asks for confirmation before removing one Event, one occurrence, or an entire series."
            ),
            LTCHelpSection(
                title: "Preferences",
                body: "Preferences control app behavior, project metadata, volume UDP output, network inventory, time format, week start day, Dock icon visibility, launch-at-login behavior, sleep prevention, import/export, reset tools, and operational log retention."
            ),
            LTCHelpSection(
                title: "Import / Export",
                body: "Import and export tools are used to back up, restore, or move project configuration files. Imports should be reviewed carefully because scheduled Events depend on matching Actions. Automatic backups are created before risky operations when supported."
            ),
            LTCHelpSection(
                title: "UDP and Syslog Testing",
                body: "Use UDP Testing to validate network paths, ports, payloads, and broadcast behavior before building or scheduling Actions. Syslog output can be tested independently before being used in Actions or Utility steps."
            ),
            LTCHelpSection(
                title: "Operating Notes",
                body: "Launch Control Center is not a substitute for commissioning, operator judgment, or a show-control safety process. Confirm clocks, network paths, connected systems, schedules, and venue conditions before production operation."
            )
        ]
    }

    // MARK: - Background

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
}
