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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            Text("Volume")
                .font(.headline)

            HStack {
                Slider(
                    value: Binding(
                        get: {
                            appState.volumeLevel
                        },
                        set: { newValue in
                            appState.volumeLevel = newValue
                            appState.sendVolumeLevel()
                        }
                    ),
                    in: 0...1
                )

                Text("\(Int(appState.volumeLevel * 100))%")
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }
}
