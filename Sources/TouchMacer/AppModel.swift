import Combine
import Foundation

final class AppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published var selectedPage: PopoverPage = .overview
    @Published private(set) var authorizationState: CalendarAuthorizationState
    @Published private(set) var calendars: [CalendarInfo] = []
    @Published private(set) var events: [CalendarEventInfo] = []
    @Published var errorMessage: String?

    private let settingsStore: SettingsStore
    private let calendarService: CalendarService
    private let appearanceService: AppearanceService

    init(
        settingsStore: SettingsStore,
        calendarService: CalendarService,
        appearanceService: AppearanceService
    ) {
        self.settingsStore = settingsStore
        self.calendarService = calendarService
        self.appearanceService = appearanceService
        self.settings = settingsStore.load()
        self.authorizationState = calendarService.authorizationState
        appearanceService.apply(settings: settings)
        refreshCalendarData()
    }

    func updateSettings(_ update: (inout AppSettings) -> Void) {
        var nextSettings = settings
        update(&nextSettings)
        settings = nextSettings
        settingsStore.save(nextSettings)
        appearanceService.apply(settings: nextSettings)
        refreshEventsIfPossible()
    }

    func addTimeZone(identifier: String) {
        guard TimeZone(identifier: identifier) != nil else { return }
        let systemIdentifier = TimeZone.autoupdatingCurrent.identifier
        updateSettings { settings in
            guard !settings.selectedTimeZoneIDs.contains(identifier) else { return }
            guard !(settings.showsSystemTimeZone && identifier == systemIdentifier) else { return }
            settings.selectedTimeZoneIDs.append(identifier)
        }
    }

    func removeTimeZone(identifier: String) {
        updateSettings { settings in
            settings.selectedTimeZoneIDs.removeAll { $0 == identifier }
        }
    }

    func refreshCalendarData() {
        authorizationState = calendarService.authorizationState
        guard authorizationState.canReadEvents else {
            calendars = []
            events = []
            return
        }

        calendars = calendarService.calendars()
        refreshEventsIfPossible()
    }

    func requestCalendarAccess() {
        calendarService.requestAccess { [weak self] state, error in
            DispatchQueue.main.async {
                self?.authorizationState = state
                self?.errorMessage = error?.localizedDescription
                self?.refreshCalendarData()
            }
        }
    }

    func refreshTimeDrivenState() {
        appearanceService.apply(settings: settings)
    }

    private func refreshEventsIfPossible() {
        guard authorizationState.canReadEvents else {
            events = []
            return
        }
        events = calendarService.upcomingEvents(settings: settings)
    }
}
