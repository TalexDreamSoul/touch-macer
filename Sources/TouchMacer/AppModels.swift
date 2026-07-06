import Foundation

struct AppSettings: Equatable {
    var displayTimeZoneMode: TimeZoneMode
    var customDisplayTimeZoneID: String
    var showsSystemTimeZone: Bool
    var selectedTimeZoneIDs: [String]
    var appearanceMode: AppearanceMode
    var appearanceTimeZoneID: String
    var overviewTimeZoneID: String
    var calendarSelectionMode: CalendarSelectionMode
    var selectedCalendarIDs: Set<String>

    var clockTimeZones: [ClockTimeZone] {
        var seenIdentifiers = Set<String>()
        var clocks: [ClockTimeZone] = []
        let systemTimeZone = TimeZone.autoupdatingCurrent

        if showsSystemTimeZone {
            clocks.append(.system(timeZone: systemTimeZone))
            seenIdentifiers.insert(systemTimeZone.identifier)
        }

        for identifier in selectedTimeZoneIDs where !seenIdentifiers.contains(identifier) {
            guard let clock = ClockTimeZone.custom(identifier: identifier) else { continue }
            clocks.append(clock)
            seenIdentifiers.insert(identifier)
        }

        return clocks.isEmpty ? [.system(timeZone: systemTimeZone)] : clocks
    }

    var displayTimeZone: TimeZone {
        clockTimeZones.first?.timeZone ?? .autoupdatingCurrent
    }

    var appearanceTimeZone: TimeZone {
        TimeZone(identifier: appearanceTimeZoneID) ?? displayTimeZone
    }

    var overviewTimeZone: TimeZone {
        TimeZone(identifier: overviewTimeZoneID) ?? displayTimeZone
    }
}

struct ClockTimeZone: Identifiable, Equatable {
    let id: String
    let identifier: String
    let title: String
    let menuBarTitle: String
    let statusBarTitle: String
    let subtitle: String
    let timeZone: TimeZone
    let isSystem: Bool

    static func system(timeZone: TimeZone) -> ClockTimeZone {
        ClockTimeZone(
            id: "system",
            identifier: timeZone.identifier,
            title: "System Time Zone",
            menuBarTitle: "Local",
            statusBarTitle: "LOCAL",
            subtitle: TimeZoneCatalog.displayName(for: timeZone.identifier),
            timeZone: timeZone,
            isSystem: true
        )
    }

    static func custom(identifier: String) -> ClockTimeZone? {
        guard let timeZone = TimeZone(identifier: identifier) else { return nil }
        return ClockTimeZone(
            id: identifier,
            identifier: identifier,
            title: TimeZoneCatalog.shortTitle(for: identifier),
            menuBarTitle: TimeZoneCatalog.shortTitle(for: identifier),
            statusBarTitle: TimeZoneCatalog.statusTitle(for: identifier),
            subtitle: TimeZoneCatalog.displayName(for: identifier),
            timeZone: timeZone,
            isSystem: false
        )
    }
}

enum TimeZoneMode: String, CaseIterable, Identifiable {
    case system
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .custom: return "Custom"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark
    case automaticByTimeZone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        case .automaticByTimeZone: return "Auto by Time Zone"
        }
    }
}

enum CalendarSelectionMode: String, CaseIterable, Identifiable {
    case all
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All Calendars"
        case .custom: return "Selected Calendars"
        }
    }
}

enum CalendarAuthorizationState: Equatable {
    case notDetermined
    case fullAccess
    case writeOnly
    case denied
    case restricted
    case unknown(String)

    var canReadEvents: Bool {
        self == .fullAccess
    }

    var title: String {
        switch self {
        case .notDetermined: return "Calendar access has not been requested."
        case .fullAccess: return "Calendar access granted."
        case .writeOnly: return "Calendar write-only access cannot read events."
        case .denied: return "Calendar access denied."
        case .restricted: return "Calendar access restricted."
        case .unknown(let value): return "Calendar access: \(value)."
        }
    }
}

struct CalendarInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let sourceTitle: String
}

struct CalendarEventInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let calendarTitle: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
}

enum TimeZoneCatalog {
    static let identifiers: [String] = TimeZone.knownTimeZoneIdentifiers.sorted { left, right in
        displayName(for: left) < displayName(for: right)
    }

    static func displayName(for identifier: String) -> String {
        let timeZone = TimeZone(identifier: identifier) ?? .autoupdatingCurrent
        return "\(offsetText(for: timeZone))  \(shortTitle(for: identifier))"
    }

    static func shortTitle(for identifier: String) -> String {
        identifier.split(separator: "/").last.map { String($0).replacingOccurrences(of: "_", with: " ") } ?? identifier
    }

    static func statusTitle(for identifier: String) -> String {
        let title = shortTitle(for: identifier)
        let knownCodes = [
            "Los Angeles": "LA",
            "New York": "NYC",
            "London": "LON",
            "Paris": "PAR",
            "Berlin": "BER",
            "Shanghai": "SHA",
            "Hong Kong": "HKG",
            "Singapore": "SG",
            "Tokyo": "TYO",
            "Seoul": "SEL",
            "Sydney": "SYD",
            "Dubai": "DXB"
        ]
        if let code = knownCodes[title] {
            return code
        }
        return title
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(3)
            .map { String($0).uppercased() }
            .joined()
    }

    static func offsetText(for timeZone: TimeZone, date: Date = Date()) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        let hours = absolute / 3600
        let minutes = (absolute % 3600) / 60
        return String(format: "GMT%@%02d:%02d", sign, hours, minutes)
    }
}
