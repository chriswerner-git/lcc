//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: LCCLayout.swift
//  Purpose: Shared SwiftUI layout components and screen chrome for
//           Launch Control Center views.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This file provides lightweight, reusable view components that keep the
//  app's screens visually aligned without moving behavior or scheduling logic
//  into the presentation layer.
//

import AppKit
import SwiftUI
import LunarKit

// MARK: - Shared Layout Constants

enum LCCLayout {
    static let appName = "Launch Control Center"
    static let appNameDisplay = "LAUNCH CONTROL CENTER"

    enum TopChrome {
        static let appNameFontSize: CGFloat = 12
        static let appNameFontWeight: Font.Weight = .semibold
        static let appNameTracking: CGFloat = 1.8
        static let appNameColor = Color.secondary

        static let helpSystemImage = "questionmark.circle"
        static let helpIconFontSize: CGFloat = 15
        static let helpIconFontWeight: Font.Weight = .regular
        static let helpIconColor = Color.secondary
        static let helpButtonSize: CGFloat = 24

        static let dividerHeight: CGFloat = 1
        static let dividerColor = LCCDesign.ColorToken.strongBorder
        static let verticalSpacing: CGFloat = 10
    }


    enum Window {
        struct Metrics {
            let defaultWidth: CGFloat
            let defaultHeight: CGFloat
            let minWidth: CGFloat
            let minHeight: CGFloat
        }

        static let dashboard = Metrics(
            defaultWidth: 1280,
            defaultHeight: 960,
            minWidth: 980,
            minHeight: 840
        )

        static let schedule = Metrics(
            defaultWidth: 1220,
            defaultHeight: 820,
            minWidth: 1040,
            minHeight: 720
        )

        static let actions = Metrics(
            defaultWidth: 1040,
            defaultHeight: 760,
            minWidth: 900,
            minHeight: 640
        )

        static let preferences = Metrics(
            defaultWidth: 900,
            defaultHeight: 760,
            minWidth: 780,
            minHeight: 640
        )

        static let eventEditor = Metrics(
            defaultWidth: 1040,
            defaultHeight: 820,
            minWidth: 900,
            minHeight: 700
        )

        static let actionEditor = Metrics(
            defaultWidth: 900,
            defaultHeight: 820,
            minWidth: 800,
            minHeight: 720
        )

        static let testing = Metrics(
            defaultWidth: 720,
            defaultHeight: 680,
            minWidth: 640,
            minHeight: 560
        )

        static let help = Metrics(
            defaultWidth: 760,
            defaultHeight: 780,
            minWidth: 640,
            minHeight: 560
        )

        static let about = Metrics(
            defaultWidth: 620,
            defaultHeight: 760,
            minWidth: 540,
            minHeight: 620
        )
    }



    enum Schedule {
        static let verticalScrollbarReserve: CGFloat = 18
        static let minimumDayColumnWidth: CGFloat = 124
        static let controlSliderWidth: CGFloat = 240
        static let timeColumnWidth: CGFloat = 62
        static let dayHeaderHeight: CGFloat = 58
        static let dayHeaderHorizontalPadding: CGFloat = 10
        static let dayHeaderVerticalPadding: CGFloat = 5
        static let hourScaleMinimum: Double = 58
        static let hourScaleMaximum: Double = 360
    }

    enum Dashboard {
        static let sectionSpacing: CGFloat = 7
        static let sectionHeaderSpacing: CGFloat = 10
        static let clockPanelHeight: CGFloat = 118
        static let clockPanelVerticalPadding: CGFloat = 4
        static let clockPanelHorizontalPadding: CGFloat = 14
        static let clockProjectNameFontSize: CGFloat = 14
        static let clockProjectNameFontWeight: Font.Weight = .medium
        static let clockTimeFontSize: CGFloat = 44
        static let clockTimeFontWeight: Font.Weight = .semibold
        static let clockDateFont: Font = .subheadline
        static let manualActionsMinimumColumnHeight: CGFloat = 178
        static let manualActionsMaximumColumnHeight: CGFloat = 245
        static let eventSummaryHeight: CGFloat = 124
        static let todayScheduleMinimumHeight: CGFloat = 320
        static let volumeOutputFontSize: CGFloat = 22
        static let volumeOutputFontWeight: Font.Weight = .semibold
    }

    enum Spacing {
        static let screenPadding: CGFloat = 18
        static let windowPadding: CGFloat = 22
        static let section: CGFloat = 16
        static let card: CGFloat = 14
        static let compact: CGFloat = 8
        static let topChrome: CGFloat = 12
    }

    enum Size {
        static let headerIcon: CGFloat = 40
        static let smallHeaderIcon: CGFloat = 34
    }


    enum Actions {
        static let libraryColumnWidth: CGFloat = 330
        static let columnSpacing: CGFloat = 18
        static let columnPadding: CGFloat = 18
        static let sectionSpacing: CGFloat = 16
        static let columnCornerRadius: CGFloat = 18
        static let columnBackgroundOpacity: Double = 0.58
        static let columnBorderWidth: CGFloat = 1

        static let editorScrollTrailingPadding: CGFloat = 8
        static let editorContentSpacing: CGFloat = 16

        static let messageFieldSpacing: CGFloat = 12
        static let delaySendButtonSpacing: CGFloat = 16
        static let ipAddressFieldWidth: CGFloat = 160
        static let portFieldWidth: CGFloat = 86
        static let severityFieldWidth: CGFloat = 132
        static let sourcePickerWidth: CGFloat = 270
        static let typePickerWidth: CGFloat = 150
        static let stepHeaderIconSize: CGFloat = 30
        static let stepHeaderIconSymbolSize: CGFloat = 12
    }
}


// MARK: - Window Activation

enum LCCWindowActivation {
    static func bringWindowToFront(matchingTitle title: String) {
        activateApplication()

        // SwiftUI may create or rehydrate the NSWindow shortly after openWindow()
        // returns, so make a few short attempts rather than assuming immediate
        // availability. This is intentionally presentation-only; it does not
        // touch scheduling, playback, or persistence behavior.
        let delays: [TimeInterval] = [0.0, 0.05, 0.18]

        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                guard let window = NSApplication.shared.windows.first(where: {
                    $0.title == title || $0.title.contains(title)
                }) else {
                    return
                }

                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
                activateApplication()
            }
        }
    }

    static func activateApplication() {
        NSApplication.shared.activate()
    }
}

// MARK: - Window Presentation Modifier

private struct LCCWindowPresentationModifier: ViewModifier {
    let title: String
    let metrics: LCCLayout.Window.Metrics

    func body(content: Content) -> some View {
        content
            .frame(
                minWidth: metrics.minWidth,
                idealWidth: metrics.defaultWidth,
                minHeight: metrics.minHeight,
                idealHeight: metrics.defaultHeight
            )
            .onAppear {
                LCCWindowActivation.bringWindowToFront(matchingTitle: title)
            }
    }
}

extension View {
    func lccWindowPresentation(
        title: String,
        metrics: LCCLayout.Window.Metrics
    ) -> some View {
        modifier(LCCWindowPresentationModifier(title: title, metrics: metrics))
    }
}



private extension LTCAppIdentity {
    static let launchControlCenter = LTCAppIdentity(
        initials: "LCC",
        displayName: LCCLayout.appName,
        headerTitle: LCCLayout.appNameDisplay,
        appIconName: "AppIcon",
        companyIconName: "LTCIcon",
        companyLogoName: "LTCLogo"
    )
}

// MARK: - Compact Brand

struct LCCCompactAppBrand: View {
    var body: some View {
        Text(LCCLayout.appNameDisplay)
            .font(.system(size: 11, weight: .semibold, design: .default))
            .tracking(1.4)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .accessibilityLabel(LCCLayout.appName)
    }
}

// MARK: - Global Top Brand

struct LCCGlobalAppHeader: View {
    @Environment(\.openWindow) private var openWindow

    let showsHelpButton: Bool

    init(showsHelpButton: Bool = true) {
        self.showsHelpButton = showsHelpButton
    }

    var body: some View {
        VStack(spacing: LCCLayout.TopChrome.verticalSpacing) {
            ZStack(alignment: .center) {
                Text(LCCLayout.appNameDisplay)
                    .font(.system(
                        size: LCCLayout.TopChrome.appNameFontSize,
                        weight: LCCLayout.TopChrome.appNameFontWeight,
                        design: .default
                    ))
                    .tracking(LCCLayout.TopChrome.appNameTracking)
                    .foregroundStyle(LCCLayout.TopChrome.appNameColor)
                    .lineLimit(1)
                    .accessibilityLabel(LCCLayout.appName)

                if showsHelpButton {
                    HStack {
                        Spacer()

                        Button {
                            openWindow(id: "help-lcc-window")
                            LCCWindowActivation.bringWindowToFront(matchingTitle: "LCC - Help")
                        } label: {
                            Image(systemName: LCCLayout.TopChrome.helpSystemImage)
                                .font(.system(
                                    size: LCCLayout.TopChrome.helpIconFontSize,
                                    weight: LCCLayout.TopChrome.helpIconFontWeight
                                ))
                                .foregroundStyle(LCCLayout.TopChrome.helpIconColor)
                                .frame(
                                    width: LCCLayout.TopChrome.helpButtonSize,
                                    height: LCCLayout.TopChrome.helpButtonSize
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help("Open Launch Control Center Help")
                        .accessibilityLabel("Open Launch Control Center Help")
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(LCCLayout.TopChrome.dividerColor)
                .frame(height: LCCLayout.TopChrome.dividerHeight)
        }
    }
}

// MARK: - Window Top Chrome

struct LCCWindowTopChrome<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let iconColor: Color
    let iconSize: CGFloat
    let titleFont: Font
    let showsHelpButton: Bool
    let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        iconColor: Color = LCCDesign.ColorToken.active,
        iconSize: CGFloat = LCCLayout.Size.headerIcon,
        titleFont: Font = .title,
        showsHelpButton: Bool? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.titleFont = titleFont
        self.showsHelpButton = showsHelpButton ?? (title != "Help")
        self.trailing = trailing
    }

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        LTCWindowHeader(
            identity: .launchControlCenter,
            heading: title,
            description: subtitle,
            iconSystemName: systemImage,
            showsHelpButton: showsHelpButton,
            helpAction: showsHelpButton ? {
                openWindow(id: "help-lcc-window")
                LCCWindowActivation.bringWindowToFront(matchingTitle: "LCC - Help")
            } : nil,
            trailing: trailing
        )
    }
}

extension LCCWindowTopChrome where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        iconColor: Color = LCCDesign.ColorToken.active,
        iconSize: CGFloat = LCCLayout.Size.headerIcon,
        titleFont: Font = .title,
        showsHelpButton: Bool? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.titleFont = titleFont
        self.showsHelpButton = showsHelpButton ?? (title != "Help")
        self.trailing = { EmptyView() }
    }
}

// MARK: - Screen Header

struct LCCScreenHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let iconColor: Color
    let iconSize: CGFloat
    let titleFont: Font
    let trailing: () -> Trailing

    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        iconColor: Color = LCCDesign.ColorToken.active,
        iconSize: CGFloat = LCCLayout.Size.headerIcon,
        titleFont: Font = .title,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.titleFont = titleFont
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(width: iconSize, height: iconSize)

                Image(systemName: systemImage)
                    .font(.system(size: iconSize * 0.40, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(titleFont)
                    .bold()

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
    }
}

extension LCCScreenHeader where Trailing == EmptyView {
    init(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        iconColor: Color = LCCDesign.ColorToken.active,
        iconSize: CGFloat = LCCLayout.Size.headerIcon,
        titleFont: Font = .title
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.iconSize = iconSize
        self.titleFont = titleFont
        self.trailing = { EmptyView() }
    }
}

// MARK: - Sidebar Header

struct LCCSidebarHeader: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var iconColor: Color = LCCDesign.ColorToken.active

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 42, height: 42)

                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.title2)
                    .bold()

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 4)
    }
}

// MARK: - Standard Empty State

struct LCCEmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.title2)
                .bold()

            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}
