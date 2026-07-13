import Combine
import Foundation

final class AppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var authorizationState: CalendarAuthorizationState
    @Published private(set) var calendars: [CalendarInfo] = []
    @Published private(set) var events: [CalendarEventInfo] = []
    @Published var errorMessage: String?
    @Published private(set) var launchAtLoginState: LaunchAtLoginState
    @Published var launchAtLoginErrorMessage: String?

    private let settingsStore: SettingsStore
    private let calendarService: CalendarService
    private let appearanceService: AppearanceService
    private let launchAtLoginService: LaunchAtLoginManaging

    init(
        settingsStore: SettingsStore,
        calendarService: CalendarService,
        appearanceService: AppearanceService,
        launchAtLoginService: LaunchAtLoginManaging = LaunchAtLoginService()
    ) {
        self.settingsStore = settingsStore
        self.calendarService = calendarService
        self.appearanceService = appearanceService
        self.launchAtLoginService = launchAtLoginService
        self.launchAtLoginState = launchAtLoginService.state
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

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLoginErrorMessage = nil
        } catch {
            launchAtLoginErrorMessage = error.localizedDescription
        }
        refreshLaunchAtLoginState()
    }

    func refreshLaunchAtLoginState() {
        launchAtLoginState = launchAtLoginService.state
    }

    func openLoginItemsSettings() {
        launchAtLoginService.openSystemSettings()
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

    func quickEventDraft(startDate: Date = Date()) -> QuickEventDraft {
        QuickEventDraft(startDate: startDate, calendarID: calendarService.defaultNewEventCalendarID)
    }

    func createEvent(from draft: QuickEventDraft) {
        do {
            try calendarService.createEvent(from: draft)
            errorMessage = nil
            refreshCalendarData()
        } catch {
            errorMessage = error.localizedDescription
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
