//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: TestingView.swift
//  Purpose: UDP testing and diagnostics window.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import SwiftUI

struct TestingView: View {
    // MARK: - Environment

    @EnvironmentObject var appState: AppState

    // MARK: - Body

    var body: some View {
        TestingContentView(
            appState: appState,
            udpService: appState.udpService
        )
    }
}

// MARK: - Testing Content

private struct TestingContentView: View {
    // MARK: - Observed Objects

    @ObservedObject var appState: AppState
    @ObservedObject var udpService: UDPService

    // MARK: - State

    @State private var testMessage: String = "Hello World!"

    // MARK: - Body

    var body: some View {
        ZStack {
            background

            VStack(alignment: .leading, spacing: 12) {
                header
                statusCard
                sendCard
                listenerCard

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .lccWindowPresentation(title: "LCC - UDP Test", metrics: LCCLayout.Window.testing)
        .alert(
            "UDP Listener Stopped",
            isPresented: automaticStopAlertIsPresented
        ) {
            Button("OK") {
                udpService.clearAutomaticStopMessage()
            }
        } message: {
            Text(udpService.listenerAutomaticStopMessage ?? "")
        }
    }

    private var automaticStopAlertIsPresented: Binding<Bool> {
        Binding(
            get: {
                udpService.listenerAutomaticStopMessage != nil
            },
            set: { isPresented in
                if isPresented == false {
                    udpService.clearAutomaticStopMessage()
                }
            }
        )
    }

    // MARK: - Header

    private var header: some View {
        LCCWindowTopChrome(
            title: "UDP Test",
            subtitle: "Send and receive test UDP messages using the current project defaults.",
            systemImage: "antenna.radiowaves.left.and.right",
            iconSize: LCCLayout.Size.smallHeaderIcon,
            titleFont: .title
        )
    }

    // MARK: - Listener

    private var listenerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Listener",
                subtitle: "Receives UDP messages for loopback testing."
            )

            HStack(alignment: .bottom, spacing: 12) {
                labeledNumberField(
                    label: "Incoming / Listen Port",
                    value: $appState.incomingUDPPort,
                    width: 150
                )

                Spacer()

                listenerStatusPill
            }

            HStack(spacing: 10) {
                Button {
                    startListening()
                } label: {
                    Label("Start Listening", systemImage: "dot.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(startListeningDisabled)

                Button {
                    udpService.stopListening()
                } label: {
                    Label("Stop Listening", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(stopListeningDisabled)
            }

            listenerTimeoutNotice
            listenerDetailLine
        }
        .padding(12)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var listenerTimeoutNotice: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "timer")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 1)

            Text("Diagnostic listener automatically stops after 10 minutes. This prevents the UDP test listener from remaining open during long unattended operation.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var listenerStatusPill: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(listenerStatusColor)
                .frame(width: 8, height: 8)

            Text(udpService.listenerState.rawValue)
                .font(.caption)
                .bold()
        }
        .foregroundStyle(listenerStatusTextColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(listenerStatusBackgroundColor)
        )
    }

    private var listenerDetailLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "number")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let listeningPort = udpService.listeningPort {
                Text("Active Port: \(String(describing: listeningPort))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Active Port: None")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(insetPanelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Listener State

    private var listenerStatusColor: Color {
        switch udpService.listenerState {
        case .listening:
            return LCCDesign.ColorToken.active

        case .starting:
            return LCCDesign.ColorToken.active.opacity(0.7)

        case .failed:
            return LCCDesign.ColorToken.error

        case .stopped:
            return .secondary
        }
    }

    private var listenerStatusBackgroundColor: Color {
        switch udpService.listenerState {
        case .listening:
            return LCCDesign.ColorToken.active.opacity(0.20)

        case .starting:
            return LCCDesign.ColorToken.active.opacity(0.12)

        case .failed:
            return LCCDesign.ColorToken.error.opacity(0.18)

        case .stopped:
            return LCCDesign.ColorToken.textBackground.opacity(0.18)
        }
    }

    private var listenerStatusTextColor: Color {
        switch udpService.listenerState {
        case .listening, .starting:
            return LCCDesign.ColorToken.active

        case .failed:
            return LCCDesign.ColorToken.error

        case .stopped:
            return .secondary
        }
    }

    private var startListeningDisabled: Bool {
        switch udpService.listenerState {
        case .starting, .listening:
            return true

        case .stopped, .failed:
            return false
        }
    }

    private var stopListeningDisabled: Bool {
        switch udpService.listenerState {
        case .stopped:
            return true

        case .starting, .listening, .failed:
            return false
        }
    }

    // MARK: - Send

    private var sendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: "Send Test Message",
                subtitle: "Sends one UDP packet to the destination below."
            )

            HStack(alignment: .top, spacing: 12) {
                labeledTextField(
                    label: "Destination IP Address",
                    text: $appState.defaultDestinationHost
                )
                .frame(width: 165)

                labeledNumberField(
                    label: "Port",
                    value: $appState.defaultDestinationPort,
                    width: 92
                )

                labeledTextField(
                    label: "Message",
                    text: $testMessage
                )
                .frame(maxWidth: .infinity)
            }

            Button {
                sendTestMessage()
            } label: {
                Label("Send UDP Message", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text("For loopback testing, use destination host 127.0.0.1 and send to the same port the listener is using.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(12)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusSection(
                title: "Last UDP Message Sent",
                systemImage: "paperplane",
                text: udpService.lastSendStatus
            )

            Divider()
                .overlay(LCCDesign.ColorToken.standardBorder)

            statusSection(
                title: "Last UDP Message Received",
                systemImage: "tray.and.arrow.down",
                text: udpService.lastReceivedMessage
            )
        }
        .padding(12)
        .background(cardBackground)
        .overlay(cardBorder)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statusSection(
        title: String,
        systemImage: String,
        text: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(LCCDesign.ColorToken.active)

                Text(title)
                    .font(.headline)

                Spacer()
            }

            Text(text)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(insetPanelBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    // MARK: - Field Helpers

    private func labeledTextField(
        label: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func labeledNumberField(
        label: String,
        value: Binding<Int>,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                label,
                value: value,
                format: .number.grouping(.never)
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: width)
        }
    }

    // MARK: - Actions

    private func startListening() {
        guard let port = validPort(appState.incomingUDPPort) else {
            udpService.lastReceivedMessage = "Invalid listen port"
            return
        }

        udpService.startListening(port: port)
    }

    private func sendTestMessage() {
        guard let port = validPort(appState.defaultDestinationPort) else {
            udpService.lastSendStatus = "Invalid destination port"
            return
        }

        udpService.send(
            message: testMessage,
            host: appState.defaultDestinationHost,
            port: port
        )
    }

    private func validPort(_ value: Int) -> UInt16? {
        guard value >= 0,
              value <= Int(UInt16.max) else {
            return nil
        }

        return UInt16(value)
    }

    // MARK: - Shared UI

    private func sectionHeader(
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Styling

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
            .shadow(color: .black.opacity(0.14), radius: 7, x: 0, y: 3)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(LCCDesign.ColorToken.standardBorder, lineWidth: 1)
    }

    private var insetPanelBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LCCDesign.ColorToken.textBackground.opacity(0.18))
    }
}
