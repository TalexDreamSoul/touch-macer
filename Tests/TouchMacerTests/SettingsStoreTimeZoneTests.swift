import Foundation
import XCTest
@testable import TouchMacer

final class SettingsStoreTimeZoneTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()

        suiteName = "TouchMacerTests.SettingsStoreTimeZoneTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = SettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        store = nil
        defaults = nil
        suiteName = nil

        super.tearDown()
    }

    func testEmptyDefaultsLoadSystemTimeZoneAsFirstClock() {
        let settings = store.load()
        let firstClock = settings.clockTimeZones.first

        XCTAssertTrue(settings.showsSystemTimeZone)
        XCTAssertEqual(firstClock?.identifier, TimeZone.autoupdatingCurrent.identifier)
        XCTAssertEqual(firstClock?.isSystem, true)
    }

    func testEmptyDefaultsLoadMondayAsCalendarWeekStartDay() {
        let settings = store.load()

        XCTAssertEqual(settings.calendarWeekStartDay, .monday)
    }

    func testCalendarWeekStartDayPersistsAcrossSaveAndLoad() {
        var settings = store.load()
        settings.calendarWeekStartDay = .sunday

        store.save(settings)

        let reloaded = SettingsStore(defaults: defaults).load()

        XCTAssertEqual(reloaded.calendarWeekStartDay, .sunday)
    }

    func testQuickEventDraftRoundsStartDateUpToNextHourAndSetsOneHourDuration() throws {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let requestedStart = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 15,
            hour: 9,
            minute: 37,
            second: 42
        )))
        let expectedStart = try XCTUnwrap(calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 1,
            day: 15,
            hour: 10,
            minute: 0,
            second: 0
        )))

        let draft = QuickEventDraft(startDate: requestedStart, calendarID: "primary")

        XCTAssertEqual(draft.startDate, expectedStart)
        XCTAssertEqual(draft.endDate, expectedStart.addingTimeInterval(60 * 60))
    }

    func testOverviewTimeZonePersistsSeparatelyFromMenuBarAndAppearanceTimeZones() {
        var settings = store.load()
        settings.selectedTimeZoneIDs = ["America/New_York", "Asia/Tokyo"]
        settings.appearanceTimeZoneID = "Europe/London"
        settings.overviewTimeZoneID = "Pacific/Honolulu"

        store.save(settings)

        let reloaded = SettingsStore(defaults: defaults).load()

        XCTAssertEqual(reloaded.overviewTimeZoneID, "Pacific/Honolulu")
        XCTAssertEqual(reloaded.overviewTimeZone.identifier, "Pacific/Honolulu")
        XCTAssertEqual(reloaded.selectedTimeZoneIDs, ["America/New_York", "Asia/Tokyo"])
        XCTAssertEqual(reloaded.appearanceTimeZoneID, "Europe/London")
        XCTAssertEqual(reloaded.appearanceTimeZone.identifier, "Europe/London")
        XCTAssertNotEqual(reloaded.overviewTimeZoneID, reloaded.selectedTimeZoneIDs.first)
        XCTAssertNotEqual(reloaded.overviewTimeZoneID, reloaded.appearanceTimeZoneID)
    }

    func testStatusBarSwitchIntervalPersists() {
        var settings = store.load()
        settings.statusBarSwitchIntervalSeconds = 8

        store.save(settings)

        let reloaded = SettingsStore(defaults: defaults).load()

        XCTAssertEqual(reloaded.statusBarSwitchIntervalSeconds, 8)
    }

    func testStatusBarClockRotatesAcrossConfiguredTimeZones() {
        var settings = store.load()
        settings.showsSystemTimeZone = false
        settings.selectedTimeZoneIDs = ["America/Los_Angeles", "Asia/Shanghai"]

        let start = Date(timeIntervalSinceReferenceDate: 0)

        XCTAssertEqual(settings.statusBarClock(at: start, switchInterval: 5).identifier, "America/Los_Angeles")
        XCTAssertEqual(settings.statusBarClock(at: start.addingTimeInterval(4.9), switchInterval: 5).identifier, "America/Los_Angeles")
        XCTAssertEqual(settings.statusBarClock(at: start.addingTimeInterval(5), switchInterval: 5).identifier, "Asia/Shanghai")
        XCTAssertEqual(settings.statusBarClock(at: start.addingTimeInterval(10), switchInterval: 5).identifier, "America/Los_Angeles")

        settings.statusBarSwitchIntervalSeconds = 3
        XCTAssertEqual(settings.statusBarClock(at: start.addingTimeInterval(2.9)).identifier, "America/Los_Angeles")
        XCTAssertEqual(settings.statusBarClock(at: start.addingTimeInterval(3)).identifier, "Asia/Shanghai")
    }

    func testSystemClockUsesCompactTimeZoneIdentifier() {
        let settings = store.load()
        let systemClock = settings.clockTimeZones.first

        XCTAssertNotEqual(systemClock?.statusBarTitle, "LOCAL")
        XCTAssertFalse(systemClock?.statusBarTitle.isEmpty ?? true)
    }

    func testKnownTimeZonesExposeLocalCountryFlags() {
        XCTAssertEqual(TimeZoneCatalog.flag(for: "America/Los_Angeles"), "🇺🇸")
        XCTAssertEqual(TimeZoneCatalog.flag(for: "Asia/Shanghai"), "🇨🇳")
        XCTAssertEqual(TimeZoneCatalog.flag(for: "Europe/London"), "🇬🇧")
    }
}
