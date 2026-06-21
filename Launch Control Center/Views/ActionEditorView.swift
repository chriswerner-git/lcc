//
//  EventDefinitionView.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//

import SwiftUI

struct EventDefinitionsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedDefinitionID: UUID?

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Event Definitions")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)

                List(selection: $selectedDefinitionID) {
                    ForEach(appState.eventDefinitions) { definition in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(definition.name)
                                    .font(.headline)

                                Text("\(definition.type.rawValue) • \(definition.commands.count) command(s)")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Delete") {
                                appState.eventDefinitions.removeAll { $0.id == definition.id }

                                if selectedDefinitionID == definition.id {
                                    selectedDefinitionID = nil
                                }
                            }
                        }
                        .tag(definition.id)
                    }
                }

                Button("Add Event Definition") {
                    let command = UDPCommand(
                        name: "Primary Command",
                        host: appState.defaultDestinationHost,
                        port: appState.defaultDestinationPort,
                        message: "RUN_SHOW",
                        delaySeconds: 0
                    )

                    let definition = EventDefinition(
                        name: "New Event",
                        type: .show,
                        commands: [command]
                    )

                    appState.eventDefinitions.append(definition)
                    selectedDefinitionID = definition.id
                }
                .padding()
            }
        } detail: {
            if let selectedDefinitionID {
                EventDefinitionEditorView(definitionID: selectedDefinitionID)
                    .environmentObject(appState)
            } else {
                Text("Select an event definition.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 900, height: 640)
    }
}

