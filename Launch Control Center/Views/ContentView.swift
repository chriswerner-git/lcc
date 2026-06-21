//
//  ContentView.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var testMessage: String = "Hello from Launch Control Center"

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Launch Control Center")
                .font(.largeTitle)
                .bold()

            Toggle("System Active", isOn: $appState.isSystemActive)

            Divider()

            Text("UDP Settings")
                .font(.headline)

            TextField("Host", text: $appState.udpHost)

            TextField("Port", value: $appState.udpPort, format: .number)

            HStack {
                Button("Start Listening") {
                    appState.udpService.startListening(port: UInt16(appState.udpPort))
                }

                Button("Stop Listening") {
                    appState.udpService.stopListening()
                }
            }

            Divider()

            Text("Send Test Message")
                .font(.headline)

            TextField("Message", text: $testMessage)

            Button("Send UDP Message") {
                appState.udpService.send(
                    message: testMessage,
                    host: appState.udpHost,
                    port: UInt16(appState.udpPort)
                )
            }

            Divider()

            Text("Last UDP Message")
                .font(.headline)

            Text(appState.udpService.lastReceivedMessage)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(width: 560, height: 460)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
