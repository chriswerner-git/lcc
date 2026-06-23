//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: VolumeControlView.swift
//  Purpose: Dashboard playback volume control and preset buttons.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation
import SwiftUI

struct VolumeControlView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Derived State

    private var outputValueText: String {
        String(format: "%.2f", appState.currentVolumeOutputValue)
    }

    private var volumePercent: Int {
        Int(appState.volumeLevel * 100)
    }

    private var volumeStatusText: String {
        appState.isMuted ? "Muted" : "Active"
    }

    private var volumeStatusColor: Color {
        appState.isMuted ? .secondary : LCCDesign.ColorToken.active
    }

    private var sliderRange: ClosedRange<Double> {
        appState.volumeSliderLowerBound...appState.volumeSliderUpperBound
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader

            VStack(alignment: .leading, spacing: 12) {
                topRow

                volumeSliderArea

                presetButtons
            }
            .padding(14)
            .background(volumeCardBackground)
            .overlay(volumeCardBorder)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Header

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Volume")
                .font(.headline)

            Text("Playback Level")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.bottom, 1)
    }

    // MARK: - Main Controls

    private var topRow: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                Image(systemName: appState.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundStyle(volumeStatusColor)

                Text(volumeStatusText)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(volumeStatusColor)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(outputValueText)
                    .font(.system(
                        size: LCCLayout.Dashboard.volumeOutputFontSize,
                        weight: LCCLayout.Dashboard.volumeOutputFontWeight,
                        design: .default
                    ))
                    .monospacedDigit()

                Text(appState.isMuted ? "Mute level" : "Slider \(volumePercent)%")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var volumeSliderArea: some View {
        VStack(alignment: .leading, spacing: 5) {
            if appState.isMuted {
                mutedSliderPlaceholder
            } else {
                Slider(
                    value: Binding(
                        get: {
                            appState.scaledVolumeOutputValue(for: appState.volumeLevel)
                        },
                        set: { newValue in
                            appState.setVolumeOutputLevel(newValue)
                        }
                    ),
                    in: sliderRange
                )
                .frame(height: 22)
            }

            HStack {
                Text(appState.formattedVolumeOutputValue(appState.volumeSliderLowerBound))
                Spacer()
                Text(appState.formattedVolumeOutputValue(appState.volumeSliderUpperBound))
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .frame(height: 43)
    }

    private var mutedSliderPlaceholder: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(LCCDesign.ColorToken.textBackground.opacity(0.22))
                .frame(height: 6)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.35))
                .frame(height: 6)

            HStack(spacing: 6) {
                Image(systemName: "speaker.slash.fill")
                    .font(.caption2)

                Text("Muted at \(appState.formattedVolumeOutputValue(appState.volumeMuteLevel))")
                    .font(.caption)
                    .monospacedDigit()

                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
        }
        .frame(height: 22)
        .accessibilityLabel("Muted at \(appState.formattedVolumeOutputValue(appState.volumeMuteLevel))")
    }

    private var presetButtons: some View {
        HStack(spacing: 10) {
            volumeButton(
                title: appState.isMuted ? "Unmute" : "Mute",
                systemImage: appState.isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill",
                isProminent: appState.isMuted
            ) {
                appState.toggleMute()
            }

            volumeButton(
                title: "Low",
                systemImage: "speaker.wave.1.fill",
                isProminent: isCurrentPreset(appState.lowVolumeLevel)
            ) {
                appState.applyVolumePreset(appState.lowVolumeLevel)
            }

            volumeButton(
                title: "Normal",
                systemImage: "speaker.wave.2.fill",
                isProminent: isCurrentPreset(appState.normalVolumeLevel)
            ) {
                appState.applyVolumePreset(appState.normalVolumeLevel)
            }

            volumeButton(
                title: "High",
                systemImage: "speaker.wave.3.fill",
                isProminent: isCurrentPreset(appState.highVolumeLevel)
            ) {
                appState.applyVolumePreset(appState.highVolumeLevel)
            }
        }
    }

    // MARK: - Buttons

    private func volumeButton(
        title: String,
        systemImage: String,
        isProminent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Spacer(minLength: 0)

                Image(systemName: systemImage)
                    .font(.caption)

                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .background(buttonBackground(isProminent: isProminent))
        .overlay(buttonBorder(isProminent: isProminent))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func isCurrentPreset(_ presetLevel: Double) -> Bool {
        guard appState.isMuted == false else {
            return false
        }

        return abs(appState.volumeLevel - presetLevel) < 0.005
    }

    // MARK: - Styling

    private var volumeCardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(LCCDesign.ColorToken.controlBackground.opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var volumeCardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }

    private func buttonBackground(isProminent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                isProminent
                    ? LCCDesign.ColorToken.active.opacity(0.26)
                    : LCCDesign.ColorToken.textBackground.opacity(0.18)
            )
    }

    private func buttonBorder(isProminent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(
                isProminent
                    ? LCCDesign.selectedStroke()
                    : LCCDesign.ColorToken.strongBorder,
                lineWidth: 1
            )
    }
}

