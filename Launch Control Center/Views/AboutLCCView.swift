//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: AboutLCCView.swift
//  Purpose: Custom About window with app metadata, support links, and notices.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import AppKit
import SwiftUI

struct AboutLaunchControlCenterView: View {
    // MARK: - Constants

    private let supportEmail = "missioncontrol@lunartelephone.com"
    private let websiteDisplayText = "www.lunartelephone.com"
    private let websiteURLString = "https://www.lunartelephone.com"

    // MARK: - App Metadata

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

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 18) {
                header
                appInfoCard
                contactCard
                disclaimerCard
                licenseCard
            }
            .padding(22)
        }
        .frame(width: 560, height: 760)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(LCCDesign.selectedFill())
                    .frame(width: 54, height: 54)

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(LCCDesign.ColorToken.active)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Launch Control Center")
                    .font(.largeTitle)
                    .bold()

                Text("by Lunar Telephone Company")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Cards

    private var appInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                title: "Application",
                subtitle: "Build information"
            )

            infoRow(label: "Version", value: appVersion)
            infoRow(label: "Build", value: buildNumber)
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var contactCard: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(
                    title: "Lunar Telephone Company",
                    subtitle: "Mission Control"
                )

                linkedInfoRow(
                    label: "Website",
                    value: websiteDisplayText,
                    systemImage: "safari"
                ) {
                    openWebsite()
                }

                linkedInfoRow(
                    label: "Email",
                    value: supportEmail,
                    systemImage: "envelope"
                ) {
                    openSupportEmail()
                }

                Text("© \(copyrightYear) Lunar Telephone Company. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }

            Spacer(minLength: 8)

            Image("LTCIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .opacity(0.92)
                .accessibilityLabel("Lunar Telephone Company icon")
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var disclaimerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Disclaimer",
                subtitle: "Operational notice"
            )

            Text(disclaimerText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var licenseCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "License / Terms of Use",
                subtitle: "Summary notice"
            )

            ScrollView(.vertical) {
                Text(licenseText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 8)
            }
            .frame(height: 118)
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(LCCDesign.ColorToken.textBackground.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
            )
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Link Actions

    private func openWebsite() {
        guard let url = URL(string: websiteURLString) else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func openSupportEmail() {
        let body = """
        Hello Mission Control,

        I need support with Launch Control Center.

        Version: \(appVersion)
        Build: \(buildNumber)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "LCC Support"),
            URLQueryItem(name: "body", value: body)
        ]

        guard let url = components.url else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    // MARK: - Notice Text

    private var disclaimerText: String {
        """
        Launch Control Center is provided as an operator-assist tool for triggering configured Actions and scheduled Events. Operators remain responsible for verifying system behavior, show conditions, network configuration, timing, and connected equipment before use.

        Lunar Telephone Company is not responsible for unintended operation, missed cues, network failures, equipment behavior, or damages resulting from misconfiguration or use in production environments.
        """
    }

    private var licenseText: String {
        """
        Launch Control Center is licensed for use as an operator-assist configuration and playback utility. Use of this software is at the operator’s own risk.

        This software is provided “as is,” without warranty of any kind, express or implied. Lunar Telephone Company does not warrant that the software will be uninterrupted, error-free, suitable for any specific production environment, or compatible with all networks, control systems, or connected devices.

        Operators are responsible for testing all Actions, scheduled Events, UDP messages, connected systems, and show-control behavior before use in any rehearsal, public operation, or production environment.

        The software, interface design, workflows, configuration structure, documentation, and related materials are the intellectual property of Lunar Telephone Company. No portion may be copied, redistributed, modified, reverse engineered, sublicensed, or used to create derivative software without prior written permission.

        In no event shall Lunar Telephone Company be liable for lost profits, missed cues, show interruption, equipment damage, data loss, network failures, incidental damages, consequential damages, or any other claims arising from use or inability to use this software.

        For questions, support, licensing, or permissions, contact missioncontrol@lunartelephone.com.
        """
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

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.body)
                .textSelection(.enabled)

            Spacer()
        }
    }

    private func linkedInfoRow(
        label: String,
        value: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Button {
                action()
            } label: {
                HStack(spacing: 6) {
                    Text(value)
                        .font(.body)

                    Image(systemName: systemImage)
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(LCCDesign.ColorToken.active)
            .help(value)

            Spacer()
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
