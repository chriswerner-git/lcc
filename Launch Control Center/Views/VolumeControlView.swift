//
//  VolumeControlView.swift
//  Launch Control Center
//
//  Dashboard volume control.
//
//  The slider stores its value persistently through AppState.
//  Changes send a UDP message using the current project defaults.
//

import SwiftUI

struct VolumeControlView: View {
    @EnvironmentObject var appState: AppState

    private var volumePercent: Int {
        Int(appState.volumeLevel * 100)
    }

    private var volumeStatusText: String {
        appState.isMuted ? "Muted" : "Active"
    }

    private var volumeStatusColor: Color {
        appState.isMuted ? .secondary : .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader

            VStack(alignment: .leading, spacing: 12) {
                topRow

                Slider(
                    value: Binding(
                        get: { appState.volumeLevel },
                        set: { appState.setVolume($0) }
                    ),
                    in: 0...1
                )

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

            Text("\(volumePercent)%")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
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
            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
    }

    private var volumeCardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
    }

    private func buttonBackground(isProminent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isProminent ? Color.blue.opacity(0.26) : Color(nsColor: .textBackgroundColor).opacity(0.18))
    }

    private func buttonBorder(isProminent: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(isProminent ? Color.blue.opacity(0.45) : Color.white.opacity(0.10), lineWidth: 1)
    }
}
