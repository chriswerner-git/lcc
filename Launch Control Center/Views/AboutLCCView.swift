//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: AboutLCCView.swift
//  Purpose: Custom About window using LunarKit shared About layout.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI
import LunarKit

struct AboutLaunchControlCenterView: View {
    // MARK: - Constants

    private let supportEmail = "missioncontrol@lunartelephone.com"
    private let websiteDisplayText = "www.lunartelephone.com"
    private let websiteURLString = "https://www.lunartelephone.com"

    private let identity = LTCAppIdentity(
        initials: "LCC",
        displayName: "Launch Control Center",
        headerTitle: "LAUNCH CONTROL CENTER",
        appIconName: "AppIcon",
        companyIconName: "LTCIcon",
        companyLogoName: "LTCLogo"
    )

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: LCCLayout.Spacing.section) {
                LCCWindowTopChrome(
                    title: "About",
                    subtitle: "Version, copyright, and operational context.",
                    systemImage: "paperplane.fill",
                    iconSize: 54,
                    showsHelpButton: false
                )

                LTCAboutShell(
                    identity: identity,
                    version: appVersion,
                    build: buildNumber,
                    copyrightLine: "© \(copyrightYear) Lunar Telephone Company. All rights reserved.",
                    websiteDisplayText: websiteDisplayText,
                    websiteURLString: websiteURLString,
                    supportEmail: supportEmail,
                    noticeTitle: "Launch Control Center Notice",
                    noticeText: launchControlNoticeText,
                    licenseTitle: "License / Terms of Use",
                    licenseText: licenseText
                ) {
                    EmptyView()
                }
            }
            .padding(LCCLayout.Spacing.windowPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .lccWindowPresentation(title: "LCC - About", metrics: LCCLayout.Window.about)
    }

    // MARK: - Metadata

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    private var copyrightYear: String {
        let year = Calendar.current.component(.year, from: Date())
        return "\(year)"
    }

    // MARK: - Notice Text

    private var launchControlNoticeText: String {
        "Launch Control Center is an operator-assist utility for configuring and triggering Actions and scheduled Events. Operators should verify Actions, schedules, network settings, connected systems, venue conditions, and show behavior before rehearsal, public operation, or production use."
    }

    private var licenseText: String {
        "Launch Control Center is provided for authorized configuration, scheduling, and playback support. Use it at your own risk. The software, source code, interface design, workflows, configuration structure, and documentation remain proprietary to Lunar Telephone Company and may not be copied, redistributed, modified, or reused outside authorized work without written permission."
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
