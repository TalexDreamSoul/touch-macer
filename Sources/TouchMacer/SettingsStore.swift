import Foundation

final class SettingsStore {
    private enum Key {
        static let displayTimeZoneMode = "displayTimeZoneMode"
        static let customDisplayTimeZoneID = "customDisplayTimeZoneID"
        static let showsSystemTimeZone = "showsSystemTimeZone"
        static let selectedTimeZoneIDs = "selectedTimeZoneIDs"
        static let statusBarSwitchIntervalSeconds = "statusBarSwitchIntervalSeconds"
        static let appearanceMode = "appearanceMode"
        static let appearanceTimeZoneID = "appearanceTimeZoneID"
        static let appliesSystemAppearance = "appliesSystemAppearance"
        static let overviewTimeZoneID = "overviewTimeZoneID"
        static let calendarWeekStartDay = "calendarWeekStartDay"
        static let calendarSelectionMode = "calendarSelectionMode"
        static let selectedCalendarIDs = "selectedCalendarIDs"
        static let pinnedQuickActions = "pinnedQuickActions"
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

        let statusBarSwitchIntervalSeconds = loadStatusBarSwitchIntervalSeconds(defaultValue: 5)
        return AppSettings(
            displayTimeZoneMode: legacyMode,
            customDisplayTimeZoneID: legacyCustomTimeZoneID,
            showsSystemTimeZone: loadShowsSystemTimeZone(defaultValue: true),
            selectedTimeZoneIDs: selectedTimeZoneIDs,
            statusBarSwitchIntervalSeconds: statusBarSwitchIntervalSeconds,
            appearanceMode: AppearanceMode(rawValue: defaults.string(forKey: Key.appearanceMode) ?? "") ?? .system,
            appearanceTimeZoneID: defaults.string(forKey: Key.appearanceTimeZoneID) ?? systemTimeZoneID,
            appliesSystemAppearance: defaults.bool(forKey: Key.appliesSystemAppearance),
            overviewTimeZoneID: defaults.string(forKey: Key.overviewTimeZoneID) ?? systemTimeZoneID,
            calendarWeekStartDay: loadCalendarWeekStartDay(defaultValue: .monday),
            calendarSelectionMode: CalendarSelectionMode(rawValue: defaults.string(forKey: Key.calendarSelectionMode) ?? "") ?? .all,
            selectedCalendarIDs: Set(defaults.stringArray(forKey: Key.selectedCalendarIDs) ?? []),
            pinnedQuickActions: loadPinnedQuickActions()
        )
    }

    func save(_ settings: AppSettings) {
        defaults.set(settings.displayTimeZoneMode.rawValue, forKey: Key.displayTimeZoneMode)
        defaults.set(settings.customDisplayTimeZoneID, forKey: Key.customDisplayTimeZoneID)
        defaults.set(settings.showsSystemTimeZone, forKey: Key.showsSystemTimeZone)
        defaults.set(settings.selectedTimeZoneIDs, forKey: Key.selectedTimeZoneIDs)
        defaults.set(settings.statusBarSwitchIntervalSeconds, forKey: Key.statusBarSwitchIntervalSeconds)
        defaults.set(settings.appearanceMode.rawValue, forKey: Key.appearanceMode)
        defaults.set(settings.appearanceTimeZoneID, forKey: Key.appearanceTimeZoneID)
        defaults.set(settings.appliesSystemAppearance, forKey: Key.appliesSystemAppearance)
        defaults.set(settings.overviewTimeZoneID, forKey: Key.overviewTimeZoneID)
        defaults.set(settings.calendarWeekStartDay.rawValue, forKey: Key.calendarWeekStartDay)
        defaults.set(settings.calendarSelectionMode.rawValue, forKey: Key.calendarSelectionMode)
        defaults.set(Array(settings.selectedCalendarIDs).sorted(), forKey: Key.selectedCalendarIDs)
        defaults.set(settings.pinnedQuickActions.map(\.storageValue), forKey: Key.pinnedQuickActions)
    }

    private func loadShowsSystemTimeZone(defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: Key.showsSystemTimeZone) != nil else { return defaultValue }
        return defaults.bool(forKey: Key.showsSystemTimeZone)
    }

    private func loadStatusBarSwitchIntervalSeconds(defaultValue: TimeInterval) -> TimeInterval {
        guard defaults.object(forKey: Key.statusBarSwitchIntervalSeconds) != nil else { return defaultValue }
        return min(30, max(2, defaults.double(forKey: Key.statusBarSwitchIntervalSeconds)))
    }

    private func loadCalendarWeekStartDay(defaultValue: WeekStartDay) -> WeekStartDay {
        guard defaults.object(forKey: Key.calendarWeekStartDay) != nil else { return defaultValue }
        return WeekStartDay(rawValue: defaults.integer(forKey: Key.calendarWeekStartDay)) ?? defaultValue
    }

    private func loadPinnedQuickActions() -> [QuickActionReference] {
        guard defaults.object(forKey: Key.pinnedQuickActions) != nil else {
            return BuiltInQuickActionID.defaultPinned
        }

        var seen = Set<QuickActionReference>()
        var references: [QuickActionReference] = []
        for storageValue in defaults.stringArray(forKey: Key.pinnedQuickActions) ?? [] {
            guard let reference = QuickActionReference(storageValue: storageValue) else { continue }
            guard seen.insert(reference).inserted else { continue }
            references.append(reference)
            if references.count == 7 { break }
        }
        return references
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
