//
//  ScheduleEntry.swift
//  Launch Control Center
//
//  A scheduled Event.
//  Events reference an ActionDefinition and determine when that Action runs.
//
//  Weekdays use Calendar weekday values:
//  - 1 = Sunday
//  - 2 = Monday
//  - 3 = Tuesday
//  - 4 = Wednesday
//  - 5 = Thursday
//  - 6 = Friday
//  - 7 = Saturday
//

import Foundation

struct ScheduleEntry: Identifiable, Codable {
    var id: UUID = UUID()

    var actionDefinitionID: UUID
    var startDate: Date
    var enabled: Bool = true

    var repeatsDaily: Bool = false
    var repeatWeekdays: Set<Int> = []
    var repeatUntil: Date?

    // Used when editing/deleting a single occurrence from a recurring series.
    // Dates are compared by calendar day, not exact time.
    var excludedOccurrenceDates: [Date] = []

    init(
        id: UUID = UUID(),
        actionDefinitionID: UUID,
        startDate: Date,
        enabled: Bool = true,
        repeatsDaily: Bool = false,
        repeatWeekdays: Set<Int> = [],
        repeatUntil: Date? = nil,
        excludedOccurrenceDates: [Date] = []
    ) {
        self.id = id
        self.actionDefinitionID = actionDefinitionID
        self.startDate = startDate
        self.enabled = enabled
        self.repeatsDaily = repeatsDaily
        self.repeatWeekdays = repeatWeekdays
        self.repeatUntil = repeatUntil
        self.excludedOccurrenceDates = excludedOccurrenceDates
    }

    enum CodingKeys: String, CodingKey {
        case id
        case actionDefinitionID
        case startDate
        case enabled
        case repeatsDaily
        case repeatWeekdays
        case repeatUntil
        case excludedOccurrenceDates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        actionDefinitionID = try container.decode(UUID.self, forKey: .actionDefinitionID)
        startDate = try container.decode(Date.self, forKey: .startDate)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        repeatsDaily = try container.decodeIfPresent(Bool.self, forKey: .repeatsDaily) ?? false
        repeatWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .repeatWeekdays) ?? []
        repeatUntil = try container.decodeIfPresent(Date.self, forKey: .repeatUntil)
        excludedOccurrenceDates = try container.decodeIfPresent([Date].self, forKey: .excludedOccurrenceDates) ?? []
    }
}
