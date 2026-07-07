import SwiftUI

private let eventAccentPalette: [Color] = [.orange, .purple, .blue, .green, .pink]

private func gregorianCalendar(for timeZone: TimeZone, weekStartDay: WeekStartDay) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    calendar.firstWeekday = weekStartDay.firstWeekday
    return calendar
}

private func eventAccentColor(for event: CalendarEventInfo) -> Color {
    let scalarTotal = event.calendarTitle.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    return eventAccentPalette[scalarTotal % eventAccentPalette.count]
}

struct StatusPopoverView: View {
    @ObservedObject var model: AppModel
    let openSettings: () -> Void
    @State private var visibleMonthDate = Date()
    @State private var selectedCalendarDate = Date()
    @State private var quickEventDraft: QuickEventDraft?

    var body: some View {
        overviewView
            .padding(18)
            .frame(width: 280, height: 560, alignment: .topLeading)
            .sheet(isPresented: quickEventSheetBinding) {
                quickEventSheet
            }
    }

    private var overviewView: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    clockSection(date: context.date)
                    MonthCalendarView(
                        monthDate: $visibleMonthDate,
                        selectedDate: $selectedCalendarDate,
                        events: model.events,
                        timeZone: model.settings.overviewTimeZone,
                        weekStartDay: model.settings.calendarWeekStartDay
                    )
                    eventsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Events")
                    .font(.headline)
                Spacer()
                Button("New Event") {
                    openQuickEventEditor()
                }
                .disabled(!model.authorizationState.canReadEvents && model.authorizationState != .notDetermined)
                Button("Settings") {
                    openSettings()
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
                    timeZone: model.settings.overviewTimeZone,
                    weekStartDay: model.settings.calendarWeekStartDay
                )
            }
        }
    }

    private var quickEventSheetBinding: Binding<Bool> {
        Binding(
            get: { quickEventDraft != nil },
            set: { isPresented in
                if !isPresented {
                    quickEventDraft = nil
                }
            }
        )
    }

    @ViewBuilder
    private var quickEventSheet: some View {
        if let currentDraft = quickEventDraft {
            QuickEventEditor(
                draft: Binding(
                    get: { quickEventDraft ?? currentDraft },
                    set: { quickEventDraft = $0 }
                ),
                calendars: model.calendars,
                onCancel: { quickEventDraft = nil },
                onSave: { draft in
                    model.createEvent(from: draft)
                    quickEventDraft = nil
                }
            )
            .padding(20)
            .frame(width: 540)
        }
    }

    private func openQuickEventEditor() {
        if model.authorizationState == .notDetermined {
            model.requestCalendarAccess()
            return
        }
        quickEventDraft = model.quickEventDraft(startDate: selectedCalendarDate)
    }
}

struct QuickEventWindowView: View {
    @ObservedObject var model: AppModel
    @State private var draft: QuickEventDraft
    let onClose: () -> Void

    init(model: AppModel, startDate: Date = Date(), onClose: @escaping () -> Void) {
        self.model = model
        self._draft = State(initialValue: model.quickEventDraft(startDate: startDate))
        self.onClose = onClose
    }

    var body: some View {
        QuickEventEditor(
            draft: $draft,
            calendars: model.calendars,
            onCancel: onClose,
            onSave: { draft in
                model.createEvent(from: draft)
                onClose()
            }
        )
        .padding(20)
        .frame(width: 540)
    }
}

private struct QuickEventEditor: View {
    @Binding var draft: QuickEventDraft
    let calendars: [CalendarInfo]
    let onCancel: () -> Void
    let onSave: (QuickEventDraft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 3, height: 36)
                    .clipShape(Capsule())
                TextField("New Event", text: $draft.title)
                    .font(.system(size: 28, weight: .medium))
                    .textFieldStyle(.plain)
                Spacer()
                if !calendars.isEmpty {
                    Picker("Calendar", selection: calendarSelection) {
                        ForEach(calendars) { calendar in
                            Text(calendar.title).tag(Optional(calendar.id))
                        }
                    }
                    .labelsHidden()
                    .frame(width: 150)
                }
            }

            TextField("Add Location or Video Call", text: $draft.location)
                .font(.title3)
                .textFieldStyle(.plain)

            Grid(alignment: .trailingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    Text("All-day:")
                    Toggle("", isOn: $draft.isAllDay)
                        .labelsHidden()
                        .gridColumnAlignment(.leading)
                }
                GridRow {
                    Text("Starts:")
                    DatePicker("", selection: $draft.startDate, displayedComponents: datePickerComponents)
                        .labelsHidden()
                        .gridColumnAlignment(.leading)
                }
                GridRow {
                    Text("Ends:")
                    DatePicker("", selection: $draft.endDate, displayedComponents: datePickerComponents)
                        .labelsHidden()
                        .gridColumnAlignment(.leading)
                }
                GridRow {
                    Text("Repeat:")
                    Picker("Repeat", selection: $draft.repeatMode) {
                        ForEach(EventRepeatMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .frame(width: 300)
                    .gridColumnAlignment(.leading)
                }
                GridRow {
                    Text("Alert:")
                    Picker("Alert", selection: $draft.alertMode) {
                        ForEach(EventAlertMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .frame(width: 300)
                    .gridColumnAlignment(.leading)
                }
            }
            .font(.title3)

            TextField("Add Notes", text: $draft.notes, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)
            TextField("Add URL", text: $draft.urlString)
                .textFieldStyle(.plain)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save Event") {
                    onSave(draft)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.endDate > draft.startDate
    }

    private var calendarSelection: Binding<String?> {
        Binding(
            get: { draft.calendarID ?? calendars.first?.id },
            set: { draft.calendarID = $0 }
        )
    }

    private var datePickerComponents: DatePickerComponents {
        draft.isAllDay ? [.date] : [.date, .hourAndMinute]
    }
}

struct SettingsWindowView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        SettingsContentView(model: model)
            .padding(20)
            .frame(minWidth: 420, idealWidth: 480, minHeight: 520, idealHeight: 640, alignment: .topLeading)
    }
}

private struct SettingsContentView: View {
    @ObservedObject var model: AppModel
    @State private var pendingTimeZoneID = TimeZone.autoupdatingCurrent.identifier

    var body: some View {
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
            Picker("Week starts", selection: binding(\.calendarWeekStartDay)) {
                ForEach(WeekStartDay.allCases) { day in
                    Text(day.title).tag(day)
                }
            }
            Text("Month view and week numbers use this start day.")
                .font(.caption)
                .foregroundStyle(.secondary)
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



private struct ClockCard: View {
    let clock: ClockTimeZone
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(clock.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(timeText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(clock.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(dateText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(7)
        .background(Color.purple.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.purple.opacity(0.18), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = clock.timeZone
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = clock.timeZone
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }
}

private struct MonthCalendarView: View {
    @Binding var monthDate: Date
    @Binding var selectedDate: Date
    let events: [CalendarEventInfo]
    let timeZone: TimeZone
    let weekStartDay: WeekStartDay
    @State private var hoveredDate: Date?

    private let weekNumberColumnWidth: CGFloat = 24
    private let dateCellSize: CGFloat = 26
    private var columns: [GridItem] {
        [GridItem(.fixed(weekNumberColumnWidth), spacing: 0)] + Array(repeating: GridItem(.fixed(dateCellSize), spacing: 0), count: 7)
    }

    private var weekdayTitles: [String] {
        let symbols = Calendar(identifier: .gregorian).veryShortStandaloneWeekdaySymbols
        let zeroBasedStart = max(0, min(6, weekStartDay.firstWeekday - 1))
        return (0..<7).map { symbols[($0 + zeroBasedStart) % 7].uppercased() }
    }

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

            LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                Text("")
                    .frame(width: weekNumberColumnWidth, height: 20)
                ForEach(Array(weekdayTitles.enumerated()), id: \.offset) { _, title in
                    Text(title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: dateCellSize, height: 20)
                }

                ForEach(weeks) { week in
                    Text("\(week.number)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: weekNumberColumnWidth, height: dateCellSize, alignment: .center)

                    ForEach(week.days) { day in
                        Button {
                            selectedDate = day.date
                            monthDate = day.date
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(day.number)")
                                    .font(.system(size: 13, weight: day.isSelected ? .bold : .semibold, design: .rounded))
                                    .foregroundStyle(day.isInMonth ? Color.primary : Color.secondary.opacity(0.38))
                                HStack(spacing: 1) {
                                    ForEach(Array(day.eventColors.enumerated()), id: \.offset) { _, color in
                                        Circle()
                                            .fill(color)
                                            .frame(width: 3.5, height: 3.5)
                                    }
                                }
                                .frame(height: 4)
                            }
                            .frame(width: dateCellSize, height: dateCellSize)
                            .contentShape(Rectangle())
                            .background(dayBackground(for: day))
                            .overlay(monthBoundary(for: day))
                            .overlay(dayBorder(for: day))
                        }
                        .buttonStyle(.plain)
                        .help(dayHelpText(for: day))
                        .onHover { isHovering in
                            hoveredDate = isHovering ? day.date : nil
                        }
                    }
                }
            }

        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var calendar: Calendar {
        gregorianCalendar(for: timeZone, weekStartDay: weekStartDay)
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

    private var weeks: [CalendarWeek] {
        stride(from: 0, to: days.count, by: 7).map { index in
            let weekDays = Array(days[index..<min(index + 7, days.count)])
            return CalendarWeek(id: weekDays.first?.date ?? monthStart, number: weekNumber(for: weekDays.first?.date ?? monthStart), days: weekDays)
        }
    }

    private var days: [CalendarDay] {
        let currentMonth = calendar.component(.month, from: monthStart)

        return (-leadingDays..<(42 - leadingDays)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: monthStart) else { return nil }
            let eventColors = eventsForDay(date)
                .prefix(3)
                .map(eventAccentColor)
            return CalendarDay(
                id: date,
                date: date,
                number: calendar.component(.day, from: date),
                column: (offset + leadingDays) % 7,
                isInMonth: calendar.component(.month, from: date) == currentMonth,
                isToday: calendar.isDate(date, inSameDayAs: Date()),
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                eventColors: Array(eventColors)
            )
        }
    }

    private func weekNumber(for date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
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

    private func monthBoundary(for day: CalendarDay) -> some View {
        GeometryReader { proxy in
            let lineWidth: CGFloat = 1.4
            let color = Color.primary.opacity(0.72)
            ZStack {
                if drawsMonthBoundary(day, dayOffset: -7) {
                    Rectangle()
                        .fill(color)
                        .frame(height: lineWidth)
                        .position(x: proxy.size.width / 2, y: lineWidth / 2)
                }
                if drawsMonthBoundary(day, dayOffset: 7) {
                    Rectangle()
                        .fill(color)
                        .frame(height: lineWidth)
                        .position(x: proxy.size.width / 2, y: proxy.size.height - lineWidth / 2)
                }
                if day.column == 0 || drawsMonthBoundary(day, dayOffset: -1) {
                    Rectangle()
                        .fill(color)
                        .frame(width: lineWidth)
                        .position(x: lineWidth / 2, y: proxy.size.height / 2)
                }
                if day.column == 6 || drawsMonthBoundary(day, dayOffset: 1) {
                    Rectangle()
                        .fill(color)
                        .frame(width: lineWidth)
                        .position(x: proxy.size.width - lineWidth / 2, y: proxy.size.height / 2)
                }
            }
        }
        .opacity(day.isInMonth ? 1 : 0)
    }

    private func drawsMonthBoundary(_ day: CalendarDay, dayOffset: Int) -> Bool {
        guard day.isInMonth,
              let adjacentDate = calendar.date(byAdding: .day, value: dayOffset, to: day.date) else { return false }
        return calendar.component(.month, from: adjacentDate) != calendar.component(.month, from: monthStart)
    }

    private func dayBackground(for day: CalendarDay) -> some ShapeStyle {
        if day.isSelected {
            return Color.blue.opacity(0.16)
        }
        if isHovered(day) {
            return Color.blue.opacity(0.08)
        }
        if day.isToday {
            return Color.orange.opacity(0.12)
        }
        return Color.clear
    }

    private func dayBorder(for day: CalendarDay) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .stroke(dayBorderColor(for: day), lineWidth: day.isSelected ? 2 : 1)
    }

    private func dayBorderColor(for day: CalendarDay) -> Color {
        if day.isSelected {
            return .blue
        }
        if isHovered(day) {
            return .blue.opacity(0.45)
        }
        return .clear
    }

    private func isHovered(_ day: CalendarDay) -> Bool {
        hoveredDate.map { calendar.isDate($0, inSameDayAs: day.date) } ?? false
    }

    private func dayHelpText(for day: CalendarDay) -> String {
        let events = eventsForDay(day.date)
        let eventSummary = events.isEmpty ? "No events" : "\(events.count) \(events.count == 1 ? "event" : "events")"
        return "\(dateTooltipText(for: day.date)) • \(eventSummary) • Click to select"
    }

    private func eventsForDay(_ date: Date) -> [CalendarEventInfo] {
        events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    private func dateTooltipText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE, MMM d, yyyy"
        return formatter.string(from: date)
    }
}


private struct CalendarDay: Identifiable {
    let id: Date
    let date: Date
    let number: Int
    let column: Int
    let isInMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let eventColors: [Color]
}

private struct CalendarWeek: Identifiable {
    let id: Date
    let number: Int
    let days: [CalendarDay]
}

private struct AgendaList: View {
    let events: [CalendarEventInfo]
    let timeZone: TimeZone
    let weekStartDay: WeekStartDay

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Next 7 Days")
                    .font(.headline)
                Spacer()
                Text(dateRangeText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if weekEvents.isEmpty {
                Text("No events in the next 7 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                ForEach(groupedWeekEvents) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(group.title)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(group.dateText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        ForEach(group.events) { event in
                            EventRow(event: event, timeZone: timeZone, accent: eventAccentColor(for: event))
                        }
                    }
                }
            }
        }
    }

    private var calendar: Calendar {
        gregorianCalendar(for: timeZone, weekStartDay: weekStartDay)
    }

    private var weekEvents: [CalendarEventInfo] {
        let start = Date()
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
        return events
            .filter { $0.endDate >= start && $0.startDate < end }
            .sorted { $0.startDate < $1.startDate }
    }

    private var groupedWeekEvents: [AgendaDayGroup] {
        let grouped = Dictionary(grouping: weekEvents) { event in
            calendar.startOfDay(for: event.startDate)
        }
        return grouped.keys.sorted().map { day in
            AgendaDayGroup(
                id: day,
                title: dayTitle(for: day),
                dateText: shortDateText(for: day),
                events: grouped[day]?.sorted { $0.startDate < $1.startDate } ?? []
            )
        }
    }

    private var dateRangeText: String {
        let start = Date()
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return "\(shortDateText(for: start)) – \(shortDateText(for: end))"
    }

    private func dayTitle(for date: Date) -> String {
        if calendar.isDate(date, inSameDayAs: Date()) {
            return "Today"
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    private func shortDateText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

private struct AgendaDayGroup: Identifiable {
    let id: Date
    let title: String
    let dateText: String
    let events: [CalendarEventInfo]
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
