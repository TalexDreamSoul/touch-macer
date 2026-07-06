import Foundation

final class SettingsStore {
    private enum Key {
        static let displayTimeZoneMode = "displayTimeZoneMode"
        static let customDisplayTimeZoneID = "customDisplayTimeZoneID"
        static let showsSystemTimeZone = "showsSystemTimeZone"
        static let selectedTimeZoneIDs = "selectedTimeZoneIDs"
        static let appearanceMode = "appearanceMode"
        static let appearanceTimeZoneID = "appearanceTimeZoneID"
        static let overviewTimeZoneID = "overviewTimeZoneID"
        static let calendarSelectionMode = "calendarSelectionMode"
        static let selectedCalendarIDs = "selectedCalendarIDs"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSettings {
        let systemTimeZoneID = TimeZone.autoupdatingCurrent.identifier
        let legacyMode = TimeZoneMode(rawValue: defaults.string(forKey: Key.displayTimeZoneMode) ?? "") ?? .system
        let legacyCustomTimeZoneID = defaults.string(forKey: Key.customDisplayTimeZoneID) ?? systemTimeZoneID
        let selectedTimeZoneIDs = defaults.stringArray(forKey: Key.selectedTimeZoneIDs) ?? defaultSelectedTimeZoneIDs(
            legacyMode: legacyMode,
            legacyCustomTimeZoneID: legacyCustomTimeZoneID,
            systemTimeZoneID: systemTimeZoneID
        )

        return AppSettings(
            displayTimeZoneMode: legacyMode,
            customDisplayTimeZoneID: legacyCustomTimeZoneID,
            showsSystemTimeZone: loadShowsSystemTimeZone(defaultValue: true),
            selectedTimeZoneIDs: selectedTimeZoneIDs,
            appearanceMode: AppearanceMode(rawValue: defaults.string(forKey: Key.appearanceMode) ?? "") ?? .system,
            appearanceTimeZoneID: defaults.string(forKey: Key.appearanceTimeZoneID) ?? systemTimeZoneID,
            overviewTimeZoneID: defaults.string(forKey: Key.overviewTimeZoneID) ?? systemTimeZoneID,
            calendarSelectionMode: CalendarSelectionMode(rawValue: defaults.string(forKey: Key.calendarSelectionMode) ?? "") ?? .all,
            selectedCalendarIDs: Set(defaults.stringArray(forKey: Key.selectedCalendarIDs) ?? [])
        )
    }

    func save(_ settings: AppSettings) {
        defaults.set(settings.displayTimeZoneMode.rawValue, forKey: Key.displayTimeZoneMode)
        defaults.set(settings.customDisplayTimeZoneID, forKey: Key.customDisplayTimeZoneID)
        defaults.set(settings.showsSystemTimeZone, forKey: Key.showsSystemTimeZone)
        defaults.set(settings.selectedTimeZoneIDs, forKey: Key.selectedTimeZoneIDs)
        defaults.set(settings.appearanceMode.rawValue, forKey: Key.appearanceMode)
        defaults.set(settings.appearanceTimeZoneID, forKey: Key.appearanceTimeZoneID)
        defaults.set(settings.overviewTimeZoneID, forKey: Key.overviewTimeZoneID)
        defaults.set(settings.calendarSelectionMode.rawValue, forKey: Key.calendarSelectionMode)
        defaults.set(Array(settings.selectedCalendarIDs).sorted(), forKey: Key.selectedCalendarIDs)
    }

    private func loadShowsSystemTimeZone(defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: Key.showsSystemTimeZone) != nil else { return defaultValue }
        return defaults.bool(forKey: Key.showsSystemTimeZone)
    }

    private func defaultSelectedTimeZoneIDs(
        legacyMode: TimeZoneMode,
        legacyCustomTimeZoneID: String,
        systemTimeZoneID: String
    ) -> [String] {
        guard legacyMode == .custom, legacyCustomTimeZoneID != systemTimeZoneID else { return [] }
        return TimeZone(identifier: legacyCustomTimeZoneID) == nil ? [] : [legacyCustomTimeZoneID]
    }
}
