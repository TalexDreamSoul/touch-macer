import EventKit
import Foundation

final class CalendarService {
    private let eventStore = EKEventStore()

    var authorizationState: CalendarAuthorizationState {
        Self.mapAuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
    }

    func requestAccess(completion: @escaping (CalendarAuthorizationState, Error?) -> Void) {
        eventStore.requestFullAccessToEvents { [weak self] _, error in
            guard let self else { return }
            completion(self.authorizationState, error)
        }
    }

    func calendars() -> [CalendarInfo] {
        eventStore.calendars(for: .event)
            .sorted { left, right in
                if left.source.title == right.source.title {
                    return left.title.localizedCaseInsensitiveCompare(right.title) == .orderedAscending
                }
                return left.source.title.localizedCaseInsensitiveCompare(right.source.title) == .orderedAscending
            }
            .map { calendar in
                CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    sourceTitle: calendar.source.title
                )
            }
    }

    func upcomingEvents(settings: AppSettings, daysAhead: Int = 14) -> [CalendarEventInfo] {
        let allCalendars = eventStore.calendars(for: .event)
        let selectedCalendars: [EKCalendar]
        switch settings.calendarSelectionMode {
        case .all:
            selectedCalendars = allCalendars
        case .custom:
            selectedCalendars = allCalendars.filter { settings.selectedCalendarIDs.contains($0.calendarIdentifier) }
        }

        guard !selectedCalendars.isEmpty else { return [] }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: startDate) ?? startDate.addingTimeInterval(14 * 24 * 60 * 60)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
        return eventStore.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(12)
            .map { event in
                CalendarEventInfo(
                    id: event.eventIdentifier ?? "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)",
                    title: event.title?.isEmpty == false ? event.title : "Untitled Event",
                    calendarTitle: event.calendar.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay
                )
            }
    }

    private static func mapAuthorizationStatus(_ status: EKAuthorizationStatus) -> CalendarAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .fullAccess
        case .fullAccess:
            return .fullAccess
        case .writeOnly:
            return .writeOnly
        @unknown default:
            return .unknown(String(describing: status))
        }
    }
}
