//
//  MenuBarView.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Launch Control Center")
                .font(.headline)

            Toggle("System Active", isOn: $appState.isSystemActive)

            Divider()

            Button("Open Control Window") {
                openWindow(id: "main-window")
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 240)
    }
}
