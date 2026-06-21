//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  Lunar Telephone Company                                   │
//  │  Launch Control Center                                     │
//  └─────────────────────────────────────────────────────────────┘
//
//  File: ActionType.swift
//  Purpose: Defines the primary categories of operator Actions.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

enum ActionType: String, Codable, CaseIterable, Identifiable {
    case show = "Show"
    case utility = "Utility"

    var id: String {
        rawValue
    }
}
