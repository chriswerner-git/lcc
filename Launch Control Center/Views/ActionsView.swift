//
//  EventDefinitionEditorView.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//

import SwiftUI

struct EventDefinitionEditorView: View {
    @EnvironmentObject var appState: AppState

    let definitionID: UUID

    private var definitionIndex: Int? {
        appState.eventDefinitions.firstIndex { $0.id == definitionID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Edit Event Definition")
                .font(.largeTitle)
                .bold()

            if let index = definitionIndex {
                GroupBox("Event") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Name", text: $appState.eventDefinitions[index].name)
                            .textFieldStyle(.roundedBorder)

                        Picker("Type", selection: $appState.eventDefinitions[index].type) {
                            ForEach(ScheduledEventType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("UDP Commands") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach($appState.eventDefinitions[index].commands) { $command in
                            GroupBox(command.name.isEmpty ? "UDP Command" : command.name) {
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField("Command Name", text: $command.name)
                                        .textFieldStyle(.roundedBorder)

                                    HStack {
                                        TextField("Host", text: $command.host)
                                            .textFieldStyle(.roundedBorder)

                                        TextField("Port", value: $command.port, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 120)
                                    }

                                    TextField("Message", text: $command.message)
                                        .textFieldStyle(.roundedBorder)

                                    HStack {
                                        TextField("Delay Seconds", value: $command.delaySeconds, format: .number)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 160)

                                        Spacer()

                                        Button("Delete Command") {
                                            appState.eventDefinitions[index].commands.removeAll { $0.id == command.id }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Button("Add UDP Command") {
                            let command = UDPCommand(
                                name: "New Command",
                                host: appState.defaultDestinationHost,
                                port: appState.defaultDestinationPort,
                                message: "",
                                delaySeconds: 0
                            )

                            appState.eventDefinitions[index].commands.append(command)
                        }
                    }
                }

                Spacer()
            } else {
                Text("Event definition not found.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 720, height: 720)
    }
}
