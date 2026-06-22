//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: LCCDesignSystem.swift
//  Purpose: Centralized visual design tokens for Launch Control Center.
//
//  Created by Chris Werner / Lunar Telephone Company.
//  © 2026 Lunar Telephone Company. All rights reserved.
//
//  This file acts like the app's SwiftUI equivalent of a small CSS variables
//  layer.  Views should use these named tokens instead of hard-coded colors
//  where a value represents a shared Launch Control Center visual convention.
//

import SwiftUI

enum LCCDesign {
    // MARK: - Color Tokens

    enum ColorToken {
        // System-adaptive foundations.
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
        static let controlBackground = Color(nsColor: .controlBackgroundColor)
        static let textBackground = Color(nsColor: .textBackgroundColor)

        // App semantics.
        static let active = Color.blue
        static let good = Color.blue
        static let warning = Color.orange
        static let error = Color.red
        static let success = Color.green

        // Action categories.
        static let showAction = Color.green
        static let utilityAction = Color.purple

        // Shared overlays and strokes.
        static let standardBorder = Color.white.opacity(0.08)
        static let strongBorder = Color.white.opacity(0.16)
        static let quietSurface = Color.primary.opacity(0.06)
        static let veryQuietSurface = Color.primary.opacity(0.035)
    }

    // MARK: - Layout Tokens

    enum Radius {
        static let panel: CGFloat = 16
        static let card: CGFloat = 14
        static let inset: CGFloat = 12
        static let small: CGFloat = 10
        static let chip: CGFloat = 7
    }

    enum Opacity {
        static let screenControlBackground = 0.58
        static let dashboardControlBackground = 0.65
        static let cardBackground = 0.72
        static let stepCardBackground = 0.62
        static let insetBackground = 0.18
        static let selectedFill = 0.18
        static let selectedStroke = 0.45
        static let subtleStroke = 0.08
    }

    enum Shadow {
        static let cardColor = Color.black.opacity(0.16)
        static let cardRadius: CGFloat = 8
        static let cardY: CGFloat = 4

        static let stepColor = Color.black.opacity(0.12)
        static let stepRadius: CGFloat = 6
        static let stepY: CGFloat = 3
    }

    // MARK: - Semantic Helpers

    static func actionColor(for type: ActionType) -> Color {
        switch type {
        case .show:
            return ColorToken.showAction

        case .utility:
            return ColorToken.utilityAction
        }
    }

    static func statusColor(for status: ControlStatus) -> Color {
        switch status {
        case .idle:
            return .secondary

        case .listening, .sending:
            return ColorToken.active

        case .error:
            return ColorToken.error
        }
    }

    static func executionColor(for result: ScheduleExecutionResult?) -> Color {
        guard let result else {
            return .secondary
        }

        switch result {
        case .ran:
            return ColorToken.success

        case .skipped:
            return ColorToken.warning

        case .failed:
            return ColorToken.error
        }
    }

    // MARK: - Shared Surfaces

    static func screenBackground(controlOpacity: Double = Opacity.screenControlBackground) -> LinearGradient {
        LinearGradient(
            colors: [
                ColorToken.windowBackground,
                ColorToken.controlBackground.opacity(controlOpacity)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    static func cardBackground(
        cornerRadius: CGFloat = Radius.panel,
        opacity: Double = Opacity.cardBackground,
        shadowColor: Color = Shadow.cardColor,
        shadowRadius: CGFloat = Shadow.cardRadius,
        shadowY: CGFloat = Shadow.cardY
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ColorToken.controlBackground.opacity(opacity))
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }

    static func cardBorder(
        cornerRadius: CGFloat = Radius.panel,
        opacity: Double = Opacity.subtleStroke
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(Color.white.opacity(opacity), lineWidth: 1)
    }

    static func insetPanel(
        cornerRadius: CGFloat = Radius.inset,
        opacity: Double = Opacity.insetBackground
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ColorToken.textBackground.opacity(opacity))
    }

    static func selectedFill(opacity: Double = Opacity.selectedFill) -> Color {
        ColorToken.active.opacity(opacity)
    }

    static func selectedStroke(opacity: Double = Opacity.selectedStroke) -> Color {
        ColorToken.active.opacity(opacity)
    }
}
