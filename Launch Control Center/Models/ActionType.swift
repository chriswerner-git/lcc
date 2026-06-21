//
//  ActionType.swift
//  Launch Control Center
//
//  Defines the category of an Action.
//  Show Actions obey the Schedule Enabled toggle.
//  Utility Actions may still run even when scheduled shows are disabled.
//

import Foundation

enum ActionType: String, Codable, CaseIterable, Identifiable {
    case show = "Show"
    case utility = "Utility"

    var id: String {
        rawValue
    }
}
