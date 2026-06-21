//
//  ScheduledEventType.swift
//  Launch Control Center
//
//  Created by Chris Werner on 6/20/2026.
//

import Foundation

enum ScheduledEventType: String, Codable, CaseIterable, Identifiable {
    case show = "Show"
    case utility = "Utility"

    var id: String { rawValue }
}
