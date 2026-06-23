//
// ┌─────────────────────────────────────────────────────────────┐
// │  Lunar Telephone Company                                    │
// │  Launch Control Center                                      │
// └─────────────────────────────────────────────────────────────┘
//
//  File: ScheduleEntry.swift
//  Purpose: Defines scheduled Events that trigger saved Actions.
//
//  © 2026 Lunar Telephone Company. All rights reserved.
//

import Foundation

// MARK: - Schedule Repeat Mode

/// Describes how a repeating Event should generate occurrences on each selected day.
///
/// `oncePerSelectedDay` preserves the original Launch Control Center behavior:
/// one occurrence is generated on each selected repeat day at `startDate`'s time.
///
/// `intervalDuringDay` is reserved for the upcoming same-day recurrence editor:
/// occurrences are generated from `startDate`'s time through `intervalEndTime`,
/// at `intervalMinutes` spacing. The end time is inclusive when it lands exactly
/// on the interval. Daily interval repeats are intentionally same-day only.
enum ScheduleRepeatMode: String, Codable {
    case oncePerSelectedDay
    case intervalDuringDay
}

struct ScheduleEntry: Identifiable, Codable {
    // MARK: - Identity

    var id: UUID = UUID()

    // Stable identifier for a recurring series. Individual, one-time Events may
    // leave this nil until/unless they become part of a generated series.
    var seriesID: UUID?

    // Optional operator-facing series name. Backend logic must never depend on
    // this being populated; unnamed series are identified by seriesID and
    // described using their Action name and schedule summary.
    var seriesName: String?

    // MARK: - Action Reference

    // The ActionDefinition to run when this Event occurs.
    var actionDefinitionID: UUID

    // MARK: - Timing

    // Date and time for one-time Events, or first occurrence time for repeats.
    var startDate: Date

    var enabled: Bool = true

    // MARK: - Repeat Rules

    var repeatsDaily: Bool = false

    // Calendar weekday values:
    // 1 = Sunday, 2 = Monday, 3 = Tuesday, 4 = Wednesday,
    // 5 = Thursday, 6 = Friday, 7 = Saturday.
    //
    // Empty set means every day when repeatsDaily is true.
    var repeatWeekdays: Set<Int> = []

    var repeatUntil: Date?

    // Repeat mode for this Event. Existing saved Events default to the original
    // once-per-selected-day behavior.
    var repeatMode: ScheduleRepeatMode = .oncePerSelectedDay

    // Same-day interval repeat settings used when repeatMode is
    // .intervalDuringDay. These are intentionally optional so legacy and
    // one-time Events remain lightweight.
    var intervalMinutes: Int?
    var intervalEndTime: Date?

    // Optional end date for a series. In the current UI, repeatUntil remains the
    // active field; this alias prepares the model for a clearer future editor.
    var seriesEndDate: Date?

    // MARK: - Occurrence Exceptions

    // Used when editing or deleting a single occurrence from a recurring series.
    // Dates are compared by calendar day, not exact time.
    var excludedOccurrenceDates: [Date] = []

    // Exact occurrence exclusions for generated series instances. This supports
    // deleting one interval occurrence without deleting the whole day. Existing
    // date-only exclusions remain supported for backward compatibility.
    var excludedOccurrenceKeys: [String] = []

    // MARK: - Init

    init(
        id: UUID = UUID(),
        seriesID: UUID? = nil,
        seriesName: String? = nil,
        actionDefinitionID: UUID,
        startDate: Date,
        enabled: Bool = true,
        repeatsDaily: Bool = false,
        repeatWeekdays: Set<Int> = [],
        repeatUntil: Date? = nil,
        repeatMode: ScheduleRepeatMode = .oncePerSelectedDay,
        intervalMinutes: Int? = nil,
        intervalEndTime: Date? = nil,
        seriesEndDate: Date? = nil,
        excludedOccurrenceDates: [Date] = [],
        excludedOccurrenceKeys: [String] = []
    ) {
        self.id = id
        self.seriesID = seriesID
        self.seriesName = seriesName
        self.actionDefinitionID = actionDefinitionID
        self.startDate = startDate
        self.enabled = enabled
        self.repeatsDaily = repeatsDaily
        self.repeatWeekdays = repeatWeekdays
        self.repeatUntil = repeatUntil
        self.repeatMode = repeatMode
        self.intervalMinutes = intervalMinutes
        self.intervalEndTime = intervalEndTime
        self.seriesEndDate = seriesEndDate
        self.excludedOccurrenceDates = excludedOccurrenceDates
        self.excludedOccurrenceKeys = excludedOccurrenceKeys
    }

    // MARK: - Codable Compatibility

    enum CodingKeys: String, CodingKey {
        case id
        case seriesID
        case seriesName
        case actionDefinitionID
        case startDate
        case enabled
        case repeatsDaily
        case repeatWeekdays
        case repeatUntil
        case repeatMode
        case intervalMinutes
        case intervalEndTime
        case seriesEndDate
        case excludedOccurrenceDates
        case excludedOccurrenceKeys
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        seriesID = try container.decodeIfPresent(UUID.self, forKey: .seriesID)
        seriesName = try container.decodeIfPresent(String.self, forKey: .seriesName)
        actionDefinitionID = try container.decode(UUID.self, forKey: .actionDefinitionID)
        startDate = try container.decode(Date.self, forKey: .startDate)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        repeatsDaily = try container.decodeIfPresent(Bool.self, forKey: .repeatsDaily) ?? false
        repeatWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .repeatWeekdays) ?? []
        repeatUntil = try container.decodeIfPresent(Date.self, forKey: .repeatUntil)
        repeatMode = try container.decodeIfPresent(ScheduleRepeatMode.self, forKey: .repeatMode) ?? .oncePerSelectedDay
        intervalMinutes = try container.decodeIfPresent(Int.self, forKey: .intervalMinutes)
        intervalEndTime = try container.decodeIfPresent(Date.self, forKey: .intervalEndTime)
        seriesEndDate = try container.decodeIfPresent(Date.self, forKey: .seriesEndDate)
        excludedOccurrenceDates = try container.decodeIfPresent([Date].self, forKey: .excludedOccurrenceDates) ?? []
        excludedOccurrenceKeys = try container.decodeIfPresent([String].self, forKey: .excludedOccurrenceKeys) ?? []
    }
}

// MARK: - Generated Schedule Occurrence

/// Lightweight generated occurrence used by shared schedule calculations.
/// This is not persisted; it is derived from ScheduleEntry rules.
struct ScheduleEntryOccurrence: Identifiable {
    let event: ScheduleEntry
    let occurrenceDate: Date

    var id: String {
        ScheduleEntryFormatter.occurrenceKey(
            eventID: event.id,
            occurrenceDate: occurrenceDate
        )
    }
}


