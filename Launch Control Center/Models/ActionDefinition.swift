//
//  EventDefinition.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//

import Foundation

struct EventDefinition: Identifiable, Codable {
    var id: UUID = UUID()

    var name: String
    var type: ScheduledEventType
    var commands: [UDPCommand] = []
}
