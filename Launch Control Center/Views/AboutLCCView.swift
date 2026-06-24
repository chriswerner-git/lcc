//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: AboutLCCView.swift
//  Purpose: Custom About window using LunarKit shared About layout with
//           Launch Control Center-specific contact and operational notices.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
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
                    copyrightLine: "© \(copyrightYear) Lunar Telephone Company. All rights reserved."
                ) {
                    contactCard
                    launchControlNoticeCard
                    licenseCard
                }
            }
            .padding(LCCLayout.Spacing.windowPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .lccWindowPresentation(title: "LCC - About", metrics: LCCLayout.Window.about)
    }

    // MARK: - Cards

    private var contactCard: some View {
        LTCCard(title: "Mission Control", systemImage: "paperplane") {
            VStack(alignment: .leading, spacing: 10) {
                linkedInfoRow(label: "Website", value: websiteDisplayText, systemImage: "safari") {
                    openWebsite()
                }

                linkedInfoRow(label: "Email", value: supportEmail, systemImage: "envelope") {
                    openSupportEmail()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var launchControlNoticeCard: some View {
        LTCCard(title: "Launch Control Center Notice", systemImage: "exclamationmark.triangle") {
            Text(disclaimerText)
                .font(LTCDesign.FontToken.cardCaption)
                .foregroundStyle(LTCDesign.ColorToken.secondaryText)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var licenseCard: some View {
        LTCCard(title: "License / Terms of Use", systemImage: "doc.text") {
            ScrollView(.vertical) {
                Text(licenseText)
                    .font(LTCDesign.FontToken.cardCaption)
                    .foregroundStyle(LTCDesign.ColorToken.secondaryText)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
            }
            .frame(height: 118)
        }
    }

    // MARK: - Reusable Rows

    private func linkedInfoRow(label: String, value: String, systemImage: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(LTCDesign.FontToken.cardCaption)
                .foregroundStyle(LTCDesign.ColorToken.secondaryText)
                .frame(width: 72, alignment: .leading)

            Button(action: action) {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.body.weight(.semibold))
                    Image(systemName: systemImage)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(LTCDesign.ColorToken.accent)
            .help(value)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Link Actions

    private func openWebsite() {
        guard let url = URL(string: websiteURLString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openSupportEmail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "LCC Support"),
            URLQueryItem(
                name: "body",
                value: "Hello Mission Control,\n\nI need support with Launch Control Center.\n\nVersion: \(appVersion)\nBuild: \(buildNumber)\n"
            )
        ]

        guard let url = components.url else { return }
        NSWorkspace.shared.open(url)
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

    private var disclaimerText: String {
        """
        Launch Control Center is an operator-assist tool for configuring and triggering Actions and scheduled Events. Operators are responsible for verifying all Actions, schedules, network settings, connected systems, venue conditions, and show behavior before rehearsal, public operation, or production use.

        Lunar Telephone Company is not responsible for unintended operation, missed cues, incorrect timing, network failures, equipment behavior, data loss, show interruption, or damages resulting from configuration errors, connected-system behavior, or use in production environments.
        """
    }

    private var licenseText: String {
        """
        Launch Control Center is licensed for use as an operator-assist configuration, scheduling, and playback utility. Use of this software is at the operator’s own risk.

        This software is provided “as is,” without warranty of any kind, express or implied. Lunar Telephone Company does not warrant that the software will be uninterrupted, error-free, suitable for any specific production environment, or compatible with all networks, control systems, connected devices, or operating conditions.

        Operators are responsible for testing all Actions, scheduled Events, UDP messages, configuration files, connected systems, and show-control behavior before use in rehearsal, public operation, or production environments.

        The software, interface design, workflows, configuration structure, documentation, and related materials are the intellectual property of Lunar Telephone Company. No portion may be copied, redistributed, modified, reverse engineered, sublicensed, or used to create derivative software without prior written permission.

        For questions, support, licensing, or permissions, contact missioncontrol@lunartelephone.com.
        """
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
