import SwiftUI

private let eventAccentPalette: [Color] = [.orange, .purple, .blue, .green, .pink]

private func gregorianCalendar(for timeZone: TimeZone) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.firstWeekday = 2
    return calendar
}

private func eventAccentColor(for event: CalendarEventInfo) -> Color {
    let scalarTotal = event.calendarTitle.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return eventAccentPalette[scalarTotal % eventAccentPalette.count]
}

struct StatusPopoverView: View {
    @ObservedObject var model: AppModel
    @State private var pendingTimeZoneID = TimeZone.autoupdatingCurrent.identifier
    @State private var visibleMonthDate = Date()
    @State private var selectedCalendarDate = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch model.selectedPage {
            case .overview:
                overviewView
            case .settings:
                settingsView
            }
        }
        .padding(18)
        .frame(width: 460, height: 700, alignment: .topLeading)
    }

    private var overviewView: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DateTimeHero(date: context.date, timeZone: model.settings.overviewTimeZone)
                    clockSection(date: context.date)
                    MonthCalendarView(
                        monthDate: $visibleMonthDate,
                        selectedDate: $selectedCalendarDate,
                        events: model.events,
                        timeZone: model.settings.overviewTimeZone
                    )
                    eventsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                overviewSettingsSection
                Divider()
                timeZoneSettingsSection
                Divider()
                appearanceSection
                Divider()
                calendarSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var overviewSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date & Events")
                .font(.headline)
            TimeZonePicker(
                title: "Display time zone",
                selection: binding(\.overviewTimeZoneID)
            )
            Text("Month view, current date/time, and event times use this time zone independently from menu bar clocks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func clockSection(date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("World Clocks")
                .font(.headline)
            ForEach(model.settings.clockTimeZones) { clock in
                ClockCard(clock: clock, date: date)
            }
        }
    }

    private var timeZoneSettingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menu Bar Time Zones")
                .font(.headline)

            Toggle("Show system time zone", isOn: binding(\.showsSystemTimeZone))

            Stepper(
                "Switch every \(Int(model.settings.statusBarSwitchIntervalSeconds))s",
                value: binding(\.statusBarSwitchIntervalSeconds),
                in: 2...30,
                step: 1
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Custom time zones")
                    .font(.subheadline.weight(.medium))

                if selectedCustomTimeZones.isEmpty {
                    Text("Add a custom time zone to rotate the menu bar clock.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(selectedCustomTimeZones) { clock in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(clock.title)
                                Text(clock.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Remove", role: .destructive) {
                                model.removeTimeZone(identifier: clock.identifier)
                            }
                        }
                    }
                }
            }

            HStack {
                TimeZonePicker(title: "Add", selection: $pendingTimeZoneID)
                Button("Add") {
                    model.addTimeZone(identifier: pendingTimeZoneID)
                }
                .disabled(!canAddPendingTimeZone)
            }

            Text("The first visible clock remains the menu bar fallback. Date/event display has its own setting above.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Appearance")
                .font(.headline)
            Picker("Appearance", selection: binding(\.appearanceMode)) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }

            if model.settings.appearanceMode == .automaticByTimeZone {
                TimeZonePicker(
                    title: "Auto reference",
                    selection: binding(\.appearanceTimeZoneID)
                )
                Text("Auto uses light from 07:00-19:00 in the selected time zone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Toggle("Apply to macOS system appearance", isOn: binding(\.appliesSystemAppearance))

            Text("When enabled, TouchMacer switches the system Light/Dark appearance via macOS Automation permissions. When disabled, only this app previews the selected appearance.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Calendars")
                    .font(.headline)
                Spacer()
                Button("Refresh") {
                    model.refreshCalendarData()
                }
            }

            Text(model.authorizationState.title)
                .font(.caption)
                .foregroundStyle(model.authorizationState.canReadEvents ? Color.secondary : Color.orange)

            if model.authorizationState == .notDetermined || model.authorizationState == .denied || model.authorizationState == .writeOnly {
                Button("Grant Calendar Access") {
                    model.requestCalendarAccess()
                }
            }

            if let errorMessage = model.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if model.authorizationState.canReadEvents {
                Picker("Show", selection: binding(\.calendarSelectionMode)) {
                    ForEach(CalendarSelectionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                if model.settings.calendarSelectionMode == .custom {
                    calendarSelectionList
                }
            }
        }
    }

    private var calendarSelectionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(model.calendars) { calendar in
                Toggle(isOn: calendarBinding(calendar.id)) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(calendar.title)
                        Text(calendar.sourceTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Events")
                    .font(.headline)
                Spacer()
                Button("Settings") {
                    model.selectedPage = .settings
                }
            }

            if !model.authorizationState.canReadEvents {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grant Calendar access to show iCloud and local Calendar events.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Grant Calendar Access") {
                        model.requestCalendarAccess()
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                AgendaList(
                    events: model.events,
                    selectedDate: selectedCalendarDate,
                    timeZone: model.settings.overviewTimeZone
                )
            }
        }
    }

    private var selectedCustomTimeZones: [ClockTimeZone] {
        model.settings.selectedTimeZoneIDs.compactMap { ClockTimeZone.custom(identifier: $0) }
    }

    private var canAddPendingTimeZone: Bool {
        guard TimeZone(identifier: pendingTimeZoneID) != nil else { return false }
        guard !model.settings.selectedTimeZoneIDs.contains(pendingTimeZoneID) else { return false }
        return !(model.settings.showsSystemTimeZone && pendingTimeZoneID == TimeZone.autoupdatingCurrent.identifier)
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { model.settings[keyPath: keyPath] },
            set: { newValue in
                model.updateSettings { settings in
                    settings[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func calendarBinding(_ calendarID: String) -> Binding<Bool> {
        Binding(
            get: { model.settings.selectedCalendarIDs.contains(calendarID) },
            set: { isSelected in
                model.updateSettings { settings in
                    if isSelected {
                        settings.selectedCalendarIDs.insert(calendarID)
                    } else {
                        settings.selectedCalendarIDs.remove(calendarID)
                    }
                }
            }
        )
    }
}


private struct DateTimeHero: View {
    let date: Date
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dateText)
                        .font(.title2.weight(.bold))
                    Text(TimeZoneCatalog.displayName(for: timeZone.identifier))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Text(timeText)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.88), Color.purple.opacity(0.74)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

private struct ClockCard: View {
    let clock: ClockTimeZone
    let date: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(clock.title)
                    .font(.subheadline.weight(.medium))
                Text(clock.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(timeText)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .padding(10)
        .background(Color.purple.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.purple.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = clock.timeZone
        formatter.dateFormat = "EEE, MMM d HH:mm:ss"
        return formatter.string(from: date)
    }
}

private struct MonthCalendarView: View {
    @Binding var monthDate: Date
    @Binding var selectedDate: Date
    let events: [CalendarEventInfo]
    let timeZone: TimeZone

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdayTitles = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text(monthName)
                    .font(.headline.weight(.bold))
                Menu {
                    ForEach(yearRange, id: \.self) { year in
                        Button("\(year)") {
                            setYear(year)
                        }
                    }
                } label: {
                    Text(yearTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Spacer()
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                Button("Today") {
                    monthDate = Date()
                    selectedDate = Date()
                }
                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .controlSize(.small)

            HStack(spacing: 2) {
                ForEach(Array(weekdayTitles.enumerated()), id: \.offset) { _, title in
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(days) { day in
                    Button {
                        selectedDate = day.date
                        monthDate = day.date
                    } label: {
                        VStack(spacing: 2) {
                            Text("\(day.number)")
                                .font(.system(size: 13, weight: day.isSelected ? .bold : .semibold, design: .rounded))
                                .foregroundStyle(day.isInMonth ? Color.primary : Color.secondary.opacity(0.45))
                            HStack(spacing: 1.5) {
                                ForEach(Array(day.eventColors.enumerated()), id: \.offset) { _, color in
                                    Circle()
                                        .fill(color)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 5)
                        }
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(dayBackground(for: day))
                        .overlay(dayBorder(for: day))
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Text("Selected")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(selectedDateText)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(selectedDateRelativeText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var calendar: Calendar {
        gregorianCalendar(for: timeZone)
    }

    private var monthStart: Date {
        let components = calendar.dateComponents([.year, .month], from: monthDate)
        return calendar.date(from: components) ?? monthDate
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM"
        return formatter.string(from: monthDate)
    }

    private var yearTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy"
        return formatter.string(from: monthDate)
    }

    private var selectedDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE, MMM d, yyyy"
        return formatter.string(from: selectedDate)
    }

    private var selectedDateRelativeText: String {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let selectedStart = calendar.startOfDay(for: selectedDate)

        if calendar.isDate(selectedStart, inSameDayAs: todayStart) {
            let hours = max(0, Int(now.timeIntervalSince(todayStart) / 3600))
            return hours == 0 ? "Less than 1 hour ago" : "\(hours) \(hours == 1 ? "hour" : "hours") ago"
        }

        let days = abs(calendar.dateComponents([.day], from: todayStart, to: selectedStart).day ?? 0)
        let unit = days == 1 ? "day" : "days"
        return selectedStart < todayStart ? "\(days) \(unit) ago" : "In \(days) \(unit)"
    }

    private var daysInVisibleMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var leadingDays: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var yearRange: [Int] {
        let year = calendar.component(.year, from: monthDate)
        return Array((year - 10)...(year + 10))
    }

    private var days: [CalendarDay] {
        let currentMonth = calendar.component(.month, from: monthStart)

        return (-leadingDays..<(42 - leadingDays)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monthStart) else { return nil }
            let eventColors = events
                .filter { calendar.isDate($0.startDate, inSameDayAs: date) }
                .prefix(3)
                .map(eventAccentColor)
            return CalendarDay(
                id: date,
                date: date,
                number: calendar.component(.day, from: date),
                isInMonth: calendar.component(.month, from: date) == currentMonth,
                isToday: calendar.isDate(date, inSameDayAs: Date()),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                eventColors: Array(eventColors)
            )
        }
    }

    private func changeMonth(by value: Int) {
        monthDate = calendar.date(byAdding: .month, value: value, to: monthDate) ?? monthDate
    }

    private func setYear(_ year: Int) {
        let month = calendar.component(.month, from: monthDate)
        let selectedDay = calendar.component(.day, from: selectedDate)
        let cappedDay = min(selectedDay, daysInMonth(year: year, month: month))
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = cappedDay
        guard let nextDate = calendar.date(from: components) else { return }
        monthDate = nextDate
        selectedDate = nextDate
    }

    private func daysInMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = 1
        guard let date = calendar.date(from: components) else { return 30 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func dayBackground(for day: CalendarDay) -> some ShapeStyle {
        if day.isSelected {
            return Color.blue.opacity(0.16)
        }
        if day.isToday {
            return Color.orange.opacity(0.12)
        }
        return Color.clear
    }

    private func dayBorder(for day: CalendarDay) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(day.isSelected ? Color.blue : Color.clear, lineWidth: 2)
    }
}


private struct CalendarDay: Identifiable {
    let id: Date
    let date: Date
    let number: Int
    let isInMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let eventColors: [Color]
}

private struct AgendaList: View {
    let events: [CalendarEventInfo]
    let selectedDate: Date
    let timeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDayName)
                        .font(.headline)
                    Text(selectedDateRelativeText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(selectedDateText)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if selectedDateEvents.isEmpty {
                Text("No events on the selected date.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(selectedDateEvents) { event in
                    EventRow(event: event, timeZone: timeZone, accent: eventAccentColor(for: event))
                }
            }
        }
    }

    private var calendar: Calendar {
        gregorianCalendar(for: timeZone)
    }

    private var selectedDateEvents: [CalendarEventInfo] {
        events
            .filter { calendar.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.startDate < $1.startDate }
    }

    private var selectedDayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: selectedDate)
    }

    private var selectedDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d"
        return formatter.string(from: selectedDate)
    }

    private var selectedDateRelativeText: String {
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let selectedStart = calendar.startOfDay(for: selectedDate)

        if calendar.isDate(selectedStart, inSameDayAs: todayStart) {
            let hours = max(0, Int(now.timeIntervalSince(todayStart) / 3600))
            return hours == 0 ? "Less than 1 hour ago" : "\(hours) \(hours == 1 ? "hour" : "hours") ago"
        }

        let days = abs(calendar.dateComponents([.day], from: todayStart, to: selectedStart).day ?? 0)
        let unit = days == 1 ? "day" : "days"
        return selectedStart < todayStart ? "\(days) \(unit) ago" : "In \(days) \(unit)"
    }
}


private struct TimeZonePicker: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(TimeZoneCatalog.identifiers, id: \.self) { identifier in
                Text(TimeZoneCatalog.displayName(for: identifier)).tag(identifier)
            }
        }
    }
}

private struct EventRow: View {
    let event: CalendarEventInfo
    let timeZone: TimeZone
    let accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 5, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(timeText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(event.calendarTitle)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var timeText: String {
        if event.isAllDay {
            return "All day"
        }

        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: event.startDate)
    }
}
