import Foundation

struct AppSettings: Equatable {
    var displayTimeZoneMode: TimeZoneMode
    var customDisplayTimeZoneID: String
    var showsSystemTimeZone: Bool
    var selectedTimeZoneIDs: [String]
    var statusBarSwitchIntervalSeconds: TimeInterval
    var appearanceMode: AppearanceMode
    var appearanceTimeZoneID: String
    var appliesSystemAppearance: Bool
    var overviewTimeZoneID: String
    var calendarWeekStartDay: WeekStartDay
    var calendarSelectionMode: CalendarSelectionMode
    var selectedCalendarIDs: Set<String>
    var pinnedQuickActions: [QuickActionReference]

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

    func statusBarClock(at date: Date, switchInterval: TimeInterval? = nil) -> ClockTimeZone {
        let clocks = clockTimeZones
        let effectiveSwitchInterval = switchInterval ?? statusBarSwitchIntervalSeconds
        guard clocks.count > 1, effectiveSwitchInterval > 0 else { return clocks[0] }

        let slot = Int(floor(date.timeIntervalSinceReferenceDate / effectiveSwitchInterval))
        let index = ((slot % clocks.count) + clocks.count) % clocks.count
        return clocks[index]
    }
}

struct ClockTimeZone: Identifiable, Equatable {
    let id: String
    let identifier: String
    let title: String
    let menuBarTitle: String
    let statusBarTitle: String
    let flag: String
    let subtitle: String
    let timeZone: TimeZone
    let isSystem: Bool

    static func system(timeZone: TimeZone) -> ClockTimeZone {
        ClockTimeZone(
            id: "system",
            identifier: timeZone.identifier,
            title: TimeZoneCatalog.shortTitle(for: timeZone.identifier),
            menuBarTitle: TimeZoneCatalog.shortTitle(for: timeZone.identifier),
            statusBarTitle: TimeZoneCatalog.statusTitle(for: timeZone.identifier),
            flag: TimeZoneCatalog.flag(for: timeZone.identifier),
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
            flag: TimeZoneCatalog.flag(for: identifier),
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

enum WeekStartDay: Int, CaseIterable, Identifiable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }
    var firstWeekday: Int { rawValue }

    var title: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
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

struct QuickEventDraft: Equatable {
    var title: String
    var location: String
    var notes: String
    var urlString: String
    var calendarID: String?
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
    var repeatMode: EventRepeatMode
    var alertMode: EventAlertMode

    init(startDate: Date, calendarID: String?) {
        let roundedStartDate = Self.roundedStartDate(from: startDate)
        self.title = "New Event"
        self.location = ""
        self.notes = ""
        self.urlString = ""
        self.calendarID = calendarID
        self.startDate = roundedStartDate
        self.endDate = roundedStartDate.addingTimeInterval(60 * 60)
        self.isAllDay = false
        self.repeatMode = .none
        self.alertMode = .none
    }

    private static func roundedStartDate(from date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: date)
        guard let hourStart = calendar.date(from: components) else { return date }
        if date.timeIntervalSince(hourStart) == 0 {
            return hourStart
        }
        return calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? date
    }
}

enum EventRepeatMode: String, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly
    case yearly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

enum EventAlertMode: String, CaseIterable, Identifiable {
    case none
    case atStart
    case fiveMinutesBefore
    case fifteenMinutesBefore
    case oneHourBefore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .atStart: return "At start"
        case .fiveMinutesBefore: return "5 minutes before"
        case .fifteenMinutesBefore: return "15 minutes before"
        case .oneHourBefore: return "1 hour before"
        }
    }

    var relativeOffset: TimeInterval? {
        switch self {
        case .none: return nil
        case .atStart: return 0
        case .fiveMinutesBefore: return -5 * 60
        case .fifteenMinutesBefore: return -15 * 60
        case .oneHourBefore: return -60 * 60
        }
    }
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

    static func flag(for identifier: String) -> String {
        guard let countryCode = countryCode(for: identifier) else { return "🌐" }
        return countryCode.uppercased().unicodeScalars.compactMap { scalar in
            UnicodeScalar(127397 + scalar.value).map(String.init)
        }.joined()
    }

    private static func countryCode(for identifier: String) -> String? {
        let normalizedIdentifier = identifier.replacingOccurrences(of: "_", with: " ")
        let city = shortTitle(for: identifier)
        let directMatches = [
            "America/Los Angeles": "US",
            "America/New York": "US",
            "America/Chicago": "US",
            "America/Denver": "US",
            "America/Phoenix": "US",
            "America/Anchorage": "US",
            "Pacific/Honolulu": "US",
            "America/Toronto": "CA",
            "America/Vancouver": "CA",
            "America/Mexico City": "MX",
            "America/Sao Paulo": "BR",
            "America/Buenos Aires": "AR",
            "Europe/London": "GB",
            "Europe/Paris": "FR",
            "Europe/Berlin": "DE",
            "Europe/Rome": "IT",
            "Europe/Madrid": "ES",
            "Europe/Amsterdam": "NL",
            "Europe/Zurich": "CH",
            "Europe/Stockholm": "SE",
            "Europe/Moscow": "RU",
            "Asia/Shanghai": "CN",
            "Asia/Hong Kong": "HK",
            "Asia/Singapore": "SG",
            "Asia/Tokyo": "JP",
            "Asia/Seoul": "KR",
            "Asia/Taipei": "TW",
            "Asia/Bangkok": "TH",
            "Asia/Jakarta": "ID",
            "Asia/Kolkata": "IN",
            "Asia/Dubai": "AE",
            "Asia/Jerusalem": "IL",
            "Australia/Sydney": "AU",
            "Australia/Melbourne": "AU",
            "Australia/Perth": "AU",
            "Pacific/Auckland": "NZ"
        ]
        if let countryCode = directMatches[normalizedIdentifier] {
            return countryCode
        }

        let cityMatches = [
            "Los Angeles": "US",
            "New York": "US",
            "London": "GB",
            "Paris": "FR",
            "Berlin": "DE",
            "Shanghai": "CN",
            "Hong Kong": "HK",
            "Singapore": "SG",
            "Tokyo": "JP",
            "Seoul": "KR",
            "Sydney": "AU",
            "Dubai": "AE"
        ]
        return cityMatches[city]
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
