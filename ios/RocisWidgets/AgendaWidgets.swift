import SwiftUI
import WidgetKit

/// One task, calendar event or ROCIs Schedule class, as written by
/// WidgetDataService (today_agenda_data, timeline_agenda_data).
struct AgendaItem: Decodable {
    let type: String?
    let id: String?
    let title: String?
    let subtitle: String?
    let category_color: String?
    let category_colors: [String]?
    let dateOnly: String?
    /// ISO start/end (Dart toIso8601String), used by the Week View timetable.
    let date: String?
    let end: String?
    let timeDisplay: String?
    let isAllDay: Bool?
    let priority: String?
    // Timeline section headers
    let isHeader: Bool?
    let dayLabel: String?
    let dateDisplay: String?

    var link: URL {
        if type == "task", let id, !id.isEmpty { return WidgetLink.task(id) }
        return WidgetLink.calendar(date: dateOnly)
    }
}

struct AgendaRow: View {
    let item: AgendaItem
    var compact = false

    var body: some View {
        HStack(spacing: 8) {
            ColorBar(color: Color(hex: item.category_color ?? ""), colors: item.category_colors)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title ?? "")
                    .font(compact ? .caption : .subheadline)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                if !compact {
                    Text(detail).font(.caption2).foregroundStyle(Theme.secondaryText).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if item.type == "schedule" {
                Image(systemName: "graduationcap.fill").font(.caption2).foregroundStyle(Theme.secondaryText)
            } else if item.type == "event" {
                Image(systemName: "calendar").font(.caption2).foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(height: compact ? 20 : 30)
    }

    private var detail: String {
        let time = item.timeDisplay ?? ""
        let sub = item.subtitle ?? ""
        if sub.isEmpty || sub == time { return time }
        return time.isEmpty ? sub : "\(time) · \(sub)"
    }
}

// MARK: - Timeline agenda (timeline_agenda_data)

struct TimelineAgendaWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let rows = WidgetStore.json("timeline_agenda_data", as: [AgendaItem].self) ?? []
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L10n.agenda).font(.headline).foregroundStyle(Theme.primaryText)
                Spacer()
                Link(destination: WidgetLink.addTask) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            if rows.isEmpty {
                EmptyState(text: L10n.noEventsOrTasks)
            } else {
                PagedList(
                    items: rows,
                    pageKey: "ios_page_timeline",
                    height: { $0.isHeader == true ? 16 : 30 }
                ) { row in
                    if row.isHeader == true {
                        HStack(spacing: 6) {
                            Text(row.dayLabel ?? "").font(.caption2.bold()).foregroundStyle(Theme.accent)
                            Text(row.dateDisplay ?? "").font(.caption2).foregroundStyle(Theme.secondaryText)
                        }
                    } else {
                        Link(destination: row.link) { AgendaRow(item: row) }
                    }
                }
            }
        }
        .widgetURL(WidgetLink.calendar())
        .rocisBackground()
    }
}

struct TimelineAgendaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimelineAgendaWidget", provider: SimpleProvider()) { _ in
            TimelineAgendaWidgetView()
        }
        .configurationDisplayName("Agenda")
        .description("Tasks, events and classes for the coming days.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Week view (today_agenda_data)

/// Week offset from this week, shared with the Android widget's key and range.
private enum WeekPaging {
    static let key = "week_view_offset"
    static let range = -8...16

    static var offset: Int {
        min(max(WidgetStore.int(key) ?? 0, range.lowerBound), range.upperBound)
    }
}

/// One agenda item placed in the week: column, all-day flag, minutes of day.
/// Same rules as Android's WeekViewRenderer.loadItems.
private struct WeekItem {
    static let minBlockMinutes = 30

    let item: AgendaItem
    let color: Color
    let day: Int
    let allDay: Bool
    let startMin: Int
    let endMin: Int

    static func load(_ items: [AgendaItem], dayKeys: [String]) -> [WeekItem] {
        items.compactMap { item in
            guard let dateOnly = item.dateOnly, let day = dayKeys.firstIndex(of: dateOnly) else { return nil }
            let start = LocalISO.parse(item.date)
            var startMin = 0
            if let start, DayKey.of(start) == dateOnly { startMin = minuteOf(start) }
            let end = LocalISO.parse(item.end)
            var endMin: Int
            if let end {
                let endKey = DayKey.of(end)
                endMin = endKey > dateOnly ? 24 * 60 : (endKey == dateOnly ? minuteOf(end) : startMin + minBlockMinutes)
            } else {
                endMin = startMin + minBlockMinutes
            }
            startMin = min(startMin, 24 * 60 - minBlockMinutes)
            endMin = min(max(endMin, startMin + minBlockMinutes), 24 * 60)
            return WeekItem(
                item: item,
                color: Color(hex: item.category_color ?? ""),
                day: day,
                allDay: item.isAllDay == true,
                startMin: startMin,
                endMin: endMin
            )
        }
    }

    private static func minuteOf(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
}

/// Dart's DateTime.toIso8601String(): local time without an offset, or UTC
/// with a trailing "Z".
private enum LocalISO {
    static let local: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f
    }()

    static func parse(_ value: String?) -> Date? {
        guard let value, value.count >= 19 else { return nil }
        let tail = value.dropFirst(19)
        if tail.contains("Z") || tail.contains("+") || tail.contains("-") {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = f.date(from: value) { return date }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: value)
        }
        return local.date(from: String(value.prefix(19)))
    }
}

struct WeekViewWidgetView: View {
    let date: Date

    var body: some View {
        let offset = WeekPaging.offset
        let calendar = weekCalendar
        let shown = calendar.date(byAdding: .weekOfYear, value: offset, to: date) ?? date
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: shown)?.start ?? shown
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
        let items = WeekItem.load(
            WidgetStore.json("today_agenda_data", as: [AgendaItem].self) ?? [],
            dayKeys: days.map(DayKey.of)
        )

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(offset == 0 ? L10n.thisWeek : weekStart.formatted(.dateTime.month(.wide).year().locale(L10n.locale)))
                        .font(.headline)
                        .foregroundStyle(offset == 0 ? Theme.accent : Theme.primaryText)
                }
                Spacer(minLength: 0)
                if offset != 0 {
                    Button(intent: PageIntent(key: WeekPaging.key, value: 0)) {
                        Image(systemName: "calendar.badge.clock")
                    }
                }
                Button(intent: PageIntent(key: WeekPaging.key, value: offset - 1)) {
                    Image(systemName: "chevron.backward")
                }
                .disabled(offset <= WeekPaging.range.lowerBound)
                Button(intent: PageIntent(key: WeekPaging.key, value: offset + 1)) {
                    Image(systemName: "chevron.forward")
                }
                .disabled(offset >= WeekPaging.range.upperBound)
            }
            .font(.subheadline.bold())
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)

            WeekTimetable(days: days, items: items, isCurrentWeek: offset == 0)
        }
        .widgetURL(WidgetLink.calendar())
        .rocisBackground()
    }

    /// Honors the app's start-of-week setting (Dart: 1 = Monday ... 7 = Sunday).
    private var weekCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = (WidgetStore.int("full_calendar_start_of_week") ?? 7) % 7 + 1
        return calendar
    }
}

/// The Schedule-style grid: day header, all-day strip, hour axis and timed
/// blocks laid out in lanes when they overlap.
private struct WeekTimetable: View {
    let days: [Date]
    let items: [WeekItem]
    let isCurrentWeek: Bool

    private let axisW: CGFloat = 26
    private let headerH: CGFloat = 34
    private let allDayRowH: CGFloat = 14
    private let minHourH: CGFloat = 22
    private let gridLine = Color.white.opacity(0.12)

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let colW = (w - axisW) / 7
            // Positions are absolute offsets, so right-to-left languages mirror x
            // by hand (day 1 on the right, axis on the right), like Android.
            let rtl = L10n.isRTL
            let mx = { (left: CGFloat, width: CGFloat) -> CGFloat in rtl ? w - left - width : left }
            let textDirection: LayoutDirection = rtl ? .rightToLeft : .leftToRight
            let todayCol = isCurrentWeek ? days.firstIndex(where: { Calendar.current.isDateInToday($0) }) : nil

            let allDay = Dictionary(grouping: items.filter(\.allDay), by: \.day)
            let allDayRows = min(2, allDay.values.map(\.count).max() ?? 0)
            let gridTop = headerH + (allDayRows > 0 ? CGFloat(allDayRows) * allDayRowH + 3 : 0)

            let timed = items.filter { !$0.allDay }
            let window = hourWindow(timed: timed, gridH: h - gridTop)
            let hourH = (h - gridTop) / CGFloat(window.count)

            ZStack(alignment: .topLeading) {
                // 1. Day header.
                Rectangle().fill(Color.white.opacity(0.04)).frame(width: w, height: headerH)
                ForEach(0..<days.count, id: \.self) { col in
                    header(day: days[col], isToday: col == todayCol)
                        .frame(width: colW, height: headerH)
                        .offset(x: mx(axisW + CGFloat(col) * colW, colW))
                }
                line(width: w, height: 1).offset(y: headerH)

                // 2. All-day strip: up to two pills per day, then "+N".
                if allDayRows > 0 {
                    ForEach(Array(allDay.keys), id: \.self) { col in
                        let dayItems = allDay[col] ?? []
                        let shown = dayItems.count > allDayRows ? allDayRows - 1 : allDayRows
                        ForEach(0..<allDayRows, id: \.self) { row in
                            Group {
                                if row < shown, row < dayItems.count {
                                    allDayPill(dayItems[row])
                                } else if row == allDayRows - 1, dayItems.count > allDayRows {
                                    Text("+\(dayItems.count - shown)")
                                        .font(.system(size: 7.5, weight: .medium))
                                        .foregroundStyle(Theme.secondaryText)
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(width: colW - 3, height: allDayRowH - 2)
                            .environment(\.layoutDirection, textDirection)
                            .offset(x: mx(axisW + CGFloat(col) * colW + 1.5, colW - 3), y: headerH + 2 + CGFloat(row) * allDayRowH)
                        }
                    }
                    line(width: w, height: 1).offset(y: gridTop)
                }

                // 3. Hour lines and labels.
                ForEach(Array(window.enumerated()), id: \.offset) { i, hour in
                    let y = gridTop + CGFloat(i) * hourH
                    if i > 0 { line(width: w - axisW, height: 1).offset(x: mx(axisW, w - axisW), y: y) }
                    Text(hourLabel(hour))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .frame(width: axisW - 2)
                        .offset(x: mx(0, axisW - 2), y: y + 2)
                }
                ForEach(0..<7, id: \.self) { col in
                    line(width: 1, height: h - gridTop).offset(x: mx(axisW + CGFloat(col) * colW, 1), y: gridTop)
                }
                if let todayCol {
                    Rectangle().fill(Theme.accent.opacity(0.05))
                        .frame(width: colW, height: h - gridTop)
                        .offset(x: mx(axisW + CGFloat(todayCol) * colW, colW), y: gridTop)
                }

                // 4. Blocks, with dots for items above/below the hour window.
                let windowStart = (window.first ?? 0) * 60
                let windowEnd = ((window.last ?? 23) + 1) * 60
                ForEach(Array(Dictionary(grouping: timed, by: \.day)), id: \.key) { col, dayItems in
                    let lanes = Self.layoutLanes(dayItems)
                    let left = axisW + CGFloat(col) * colW
                    ForEach(Array(dayItems.enumerated()), id: \.offset) { index, item in
                        if item.endMin > windowStart, item.startMin < windowEnd {
                            let lane = lanes[index]
                            let laneW = (colW - 3) / CGFloat(lane.count)
                            let blockW = laneW - (lane.count > 1 ? 1.5 : 0)
                            let top = max(item.startMin, windowStart)
                            let bottom = min(item.endMin, windowEnd)
                            let y = gridTop + CGFloat(top - windowStart) / 60 * hourH + 1
                            let blockH = max(CGFloat(bottom - top) / 60 * hourH - 2, 10)
                            Link(destination: item.item.link) {
                                block(item, height: blockH)
                            }
                            .frame(width: blockW, height: blockH)
                            .environment(\.layoutDirection, textDirection)
                            .offset(x: mx(left + 1.5 + CGFloat(lane.index) * laneW, blockW), y: y)
                        }
                    }
                    if dayItems.contains(where: { $0.endMin <= windowStart }) {
                        Circle().fill(Theme.secondaryText).frame(width: 3, height: 3)
                            .offset(x: mx(left + colW / 2 - 1.5, 3), y: gridTop + 2)
                    }
                    if dayItems.contains(where: { $0.startMin >= windowEnd }) {
                        Circle().fill(Theme.secondaryText).frame(width: 3, height: 3)
                            .offset(x: mx(left + colW / 2 - 1.5, 3), y: h - 5)
                    }
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
            .environment(\.layoutDirection, .leftToRight)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(gridLine, lineWidth: 1))
        }
    }

    private func line(width: CGFloat, height: CGFloat) -> some View {
        Rectangle().fill(gridLine).frame(width: width, height: height)
    }

    private func header(day: Date, isToday: Bool) -> some View {
        ZStack(alignment: .bottom) {
            if isToday { Theme.accent.opacity(0.08) }
            VStack(spacing: 2) {
                Text(day.formatted(.dateTime.weekday(.abbreviated).locale(L10n.locale)).uppercased(with: L10n.locale))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isToday ? Theme.accent : Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(day.formatted(.dateTime.day().locale(L10n.locale)))
                    .font(.system(size: 11, weight: isToday ? .bold : .regular))
                    .foregroundStyle(Theme.primaryText)
                    .padding(.horizontal, 5)
                    .background(Capsule().fill(isToday ? Theme.accent : .clear))
            }
            .frame(maxHeight: .infinity)
            if isToday { Theme.accent.frame(height: 2.5) }
        }
    }

    private func allDayPill(_ item: WeekItem) -> some View {
        Text(item.item.title ?? "")
            .font(.system(size: 7.5, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 4).fill(item.color.opacity(0.35)))
            .foregroundStyle(Theme.primaryText)
    }

    private func block(_ item: WeekItem, height: CGFloat) -> some View {
        HStack(spacing: 0) {
            item.color.frame(width: 3)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .top, spacing: 2) {
                    if item.item.type == "task" {
                        Circle().stroke(item.color, lineWidth: 1.1).frame(width: 5, height: 5).padding(.top, 2)
                    }
                    Text(item.item.title ?? "")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(max(1, Int((height - 4) / 10)))
                }
                if height >= 34 {
                    Text(timeLabel(item.startMin))
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(item.color)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 2)
            .padding(.top, 2)
            Spacer(minLength: 0)
        }
        .background(item.color.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(RoundedRectangle(cornerRadius: 5).stroke(item.color.opacity(0.35), lineWidth: 0.8))
    }

    /// 8:00-20:00 by default, widened to fit the week's items, then narrowed to
    /// the hours that stay readable, anchored at the current hour this week.
    private func hourWindow(timed: [WeekItem], gridH: CGFloat) -> [Int] {
        var startHour = 8
        var endHour = 20
        for item in timed {
            startHour = min(startHour, item.startMin / 60)
            endHour = max(endHour, Int((Double(item.endMin) / 60).rounded(.up)))
        }
        endHour = min(endHour, 24)
        let total = endHour - startHour
        let visible = min(total, max(4, Int(gridH / minHourH)))
        var windowStart = startHour
        if visible < total {
            let anchor = isCurrentWeek
                ? Calendar.current.component(.hour, from: Date()) - 1
                : (timed.map { $0.startMin / 60 }.min() ?? startHour)
            windowStart = min(max(anchor, startHour), endHour - visible)
        }
        return Array(windowStart..<(windowStart + visible))
    }

    private func hourLabel(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return date.formatted(.dateTime.hour().locale(L10n.locale))
    }

    private func timeLabel(_ minutes: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: L10n.locale))
    }

    /// Side-by-side lanes for overlapping items, same rule as the Schedule grid.
    private static func layoutLanes(_ items: [WeekItem]) -> [(index: Int, count: Int)] {
        let order = items.indices.sorted { items[$0].startMin < items[$1].startMin }
        var result = Array(repeating: (index: 0, count: 1), count: items.count)
        var cluster: [(item: Int, lane: Int)] = []
        var laneEnds: [Int] = []
        var clusterEnd = -1
        func close() {
            for entry in cluster { result[entry.item] = (entry.lane, laneEnds.count) }
            cluster = []
            laneEnds = []
        }
        for i in order {
            let item = items[i]
            if item.startMin >= clusterEnd { close() }
            var lane = laneEnds.firstIndex(where: { $0 <= item.startMin }) ?? -1
            if lane < 0 {
                lane = laneEnds.count
                laneEnds.append(item.endMin)
            } else {
                laneEnds[lane] = item.endMin
            }
            cluster.append((i, lane))
            clusterEnd = max(clusterEnd, item.endMin)
        }
        close()
        return result
    }
}

struct WeekViewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekViewWidget", provider: SimpleProvider()) { entry in
            WeekViewWidgetView(date: entry.date)
        }
        .configurationDisplayName("Week View")
        .description("Your week as a timetable. Page between weeks.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Month grids (month_agenda_*, full_calendar_*)

private struct GridDay: Decodable {
    var isWeekNumber: Bool? = nil
    var weekNumber: Int? = nil
    var date: String? = nil
    var day: Int? = nil
    var isCurrentMonth: Bool? = nil
    var isToday: Bool? = nil
    var hasEvents: Bool? = nil
    var summaries: [Summary]? = nil

    struct Summary: Decodable {
        let text: String?
        let color: String?
    }
}

/// Six week rows sized to the space they get. Full Calendar's grid data puts a
/// week-number entry before each row of 7 days.
private struct MonthGrid: View {
    let entries: [GridDay]
    let showSummaries: Bool
    var showWeekNumbers = false

    var body: some View {
        let weekNumbers = entries.filter { $0.isWeekNumber == true }.map { $0.weekNumber ?? 0 }
        let days = entries.filter { $0.isWeekNumber != true }
        let rows = stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<min($0 + 7, days.count)]) }

        GeometryReader { geo in
            let spacing: CGFloat = 2
            let weekdayH: CGFloat = 12
            let rowsH = geo.size.height - weekdayH - spacing
            let rowHeight = rows.isEmpty ? 0 : (rowsH - spacing * CGFloat(rows.count - 1)) / CGFloat(rows.count)
            // Date circle is 18pt; each summary chip needs ~10pt.
            let summaryCount = showSummaries ? max(0, Int((rowHeight - 19) / 10)) : 0
            VStack(spacing: spacing) {
                // Weekday names from the grid's own first week, so they follow
                // the start-of-week setting and the app language.
                HStack(spacing: spacing) {
                    if showWeekNumbers { Color.clear.frame(width: 14) }
                    ForEach(Array((rows.first ?? []).enumerated()), id: \.offset) { _, day in
                        Text(weekdayLabel(day.date))
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Theme.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: weekdayH)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(spacing: spacing) {
                        if showWeekNumbers {
                            Text(index < weekNumbers.count ? "\(weekNumbers[index])" : "")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(Theme.secondaryText)
                                .frame(width: 14)
                        }
                        ForEach(Array(row.enumerated()), id: \.offset) { _, day in
                            Link(destination: WidgetLink.calendar(date: day.date)) {
                                cell(day, summaryCount: summaryCount)
                            }
                        }
                    }
                    .frame(height: max(0, rowHeight))
                }
            }
        }
    }

    private func weekdayLabel(_ key: String?) -> String {
        guard let key, let date = DayKey.date(key) else { return "" }
        return date.formatted(.dateTime.weekday(.abbreviated).locale(L10n.locale)).uppercased(with: L10n.locale)
    }

    private func cell(_ day: GridDay, summaryCount: Int) -> some View {
        VStack(spacing: 1) {
            Text("\(day.day ?? 0)")
                .font(.system(size: 10, weight: day.isToday == true ? .bold : .regular))
                .frame(width: 18, height: 18)
                .background(Circle().fill(day.isToday == true ? Theme.accent : .clear))
                .foregroundStyle(day.isCurrentMonth == true ? Theme.primaryText : Theme.secondaryText.opacity(0.5))
            if showSummaries {
                let summaries = day.summaries ?? []
                let limit = summaries.count > summaryCount ? max(0, summaryCount - 1) : summaryCount
                ForEach(Array(summaries.prefix(limit).enumerated()), id: \.offset) { _, s in
                    Text(s.text ?? "")
                        .font(.system(size: 7))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, minHeight: 9, maxHeight: 9, alignment: .leading)
                        .padding(.horizontal, 1)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color(hex: s.color ?? "").opacity(0.4)))
                        .foregroundStyle(Theme.primaryText)
                }
                if summaries.count > limit {
                    Text("+\(summaries.count - limit)")
                        .font(.system(size: 7))
                        .frame(height: 9)
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                Circle()
                    .fill(day.hasEvents == true || !(day.summaries ?? []).isEmpty ? Theme.accent : .clear)
                    .frame(width: 3, height: 3)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Month + day agenda

struct MonthAgendaWidgetView: View {
    var body: some View {
        let grid = WidgetStore.json("month_agenda_grid_data", as: [GridDay].self) ?? []
        let title = WidgetStore.string("month_agenda_month_title") ?? ""
        let today = DayKey.of(Date())
        let agenda = (WidgetStore.json("today_agenda_data", as: [AgendaItem].self) ?? [])
            .filter { $0.dateOnly == today }

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Theme.primaryText).lineLimit(1)
                MonthGrid(entries: grid, showSummaries: false)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.today).font(.caption.bold()).foregroundStyle(Theme.accent)
                if agenda.isEmpty {
                    EmptyState(text: L10n.nothingToday)
                } else {
                    PagedList(items: agenda, pageKey: "ios_page_month_agenda", height: { _ in 30 }) { item in
                        Link(destination: item.link) { AgendaRow(item: item) }
                    }
                }
            }
        }
        .widgetURL(WidgetLink.calendar())
        .rocisBackground()
    }
}

struct MonthAgendaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MonthAgendaWidget", provider: SimpleProvider()) { _ in
            MonthAgendaWidgetView()
        }
        .configurationDisplayName("Month & Agenda")
        .description("The month with today's agenda.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Full calendar

/// The widget builds its own month grid from full_calendar_events_by_date,
/// which the app fills for 6 months before to 12 months after the current
/// month. That lets it page months without the app, and Calendar's day math
/// keeps dates right across DST changes.
private enum MonthPaging {
    static let key = "ios_full_calendar_offset"
    static let range = -6...12

    static var offset: Int {
        min(max(WidgetStore.int(key) ?? 0, range.lowerBound), range.upperBound)
    }
}

struct FullCalendarWidgetView: View {
    let date: Date

    var body: some View {
        let offset = MonthPaging.offset
        let calendar = monthCalendar
        let thisMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let month = calendar.date(byAdding: .month, value: offset, to: thisMonth) ?? thisMonth

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(month.formatted(.dateTime.month(.wide).year().locale(L10n.locale)))
                    .font(.headline).foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Group {
                    if offset != 0 {
                        Button(intent: PageIntent(key: MonthPaging.key, value: 0)) {
                            Image(systemName: "calendar.badge.clock")
                        }
                    }
                    Button(intent: PageIntent(key: MonthPaging.key, value: offset - 1)) {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(offset <= MonthPaging.range.lowerBound)
                    Button(intent: PageIntent(key: MonthPaging.key, value: offset + 1)) {
                        Image(systemName: "chevron.forward")
                    }
                    .disabled(offset >= MonthPaging.range.upperBound)
                }
                .font(.subheadline.bold())
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                Link(destination: WidgetLink.addTask) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            MonthGrid(
                entries: grid(for: month, calendar: calendar),
                showSummaries: true,
                // The app's "Show week numbers" widget setting.
                showWeekNumbers: WidgetStore.bool("full_calendar_show_week_numbers", default: false)
            )
        }
        .widgetURL(WidgetLink.calendar())
        .rocisBackground()
    }

    /// Six weeks from the start of the week containing the 1st, in the same
    /// shape as the app's full_calendar_grid_data (a week number, then 7 days).
    private func grid(for month: Date, calendar: Calendar) -> [GridDay] {
        let byDate = WidgetStore.json("full_calendar_events_by_date", as: [String: [GridDay.Summary]].self) ?? [:]
        let first = calendar.dateInterval(of: .weekOfYear, for: month)?.start ?? month
        let iso = Calendar(identifier: .iso8601)
        var entries: [GridDay] = []
        for row in 0..<6 {
            guard let rowStart = calendar.date(byAdding: .day, value: row * 7, to: first) else { continue }
            entries.append(GridDay(isWeekNumber: true, weekNumber: iso.component(.weekOfYear, from: rowStart)))
            for col in 0..<7 {
                guard let day = calendar.date(byAdding: .day, value: row * 7 + col, to: first) else { continue }
                let key = DayKey.of(day)
                entries.append(GridDay(
                    date: key,
                    day: calendar.component(.day, from: day),
                    isCurrentMonth: calendar.isDate(day, equalTo: month, toGranularity: .month),
                    isToday: calendar.isDateInToday(day),
                    summaries: byDate[key] ?? []
                ))
            }
        }
        return entries
    }

    /// Honors the app's start-of-week setting (Dart: 1 = Monday ... 7 = Sunday).
    private var monthCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = (WidgetStore.int("full_calendar_start_of_week") ?? 7) % 7 + 1
        return calendar
    }
}

struct FullCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FullCalendarWidget", provider: SimpleProvider()) { entry in
            FullCalendarWidgetView(date: entry.date)
        }
        .configurationDisplayName("Full Calendar")
        .description("The whole month with your tasks, events and classes.")
        .supportedFamilies([.systemLarge, .systemExtraLarge])
    }
}

// MARK: - Kanban (kanban_data)

private struct KanbanData: Decodable {
    let column_todo: [Card]?
    let column_infocus: [Card]?
    let column_done: [Card]?

    struct Card: Decodable {
        let id: String?
        let title: String?
        let category_color: String?
        let category_colors: [String]?
        let priority: String?
        let isOverdue: Bool?
        let dateDisplay: String?
    }
}

struct KanbanWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let data = WidgetStore.json("kanban_data", as: KanbanData.self)
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.board).font(.headline).foregroundStyle(Theme.primaryText)
            HStack(alignment: .top, spacing: 6) {
                column(L10n.inFocus, data?.column_infocus ?? [], Theme.accent)
                column(L10n.toDo, data?.column_todo ?? [], Color(hex: "#3B82F6"))
                column(L10n.done, data?.column_done ?? [], Theme.done)
            }
        }
        .widgetURL(WidgetLink.kanban)
        .rocisBackground()
    }

    private func column(_ title: String, _ cards: [KanbanData.Card], _ color: Color) -> some View {
        let limit = family == .systemMedium ? 3 : 8
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.caption2.bold()).foregroundStyle(Theme.secondaryText)
                Text("\(cards.count)").font(.caption2).foregroundStyle(Theme.secondaryText)
            }
            ForEach(Array(cards.prefix(limit).enumerated()), id: \.offset) { _, card in
                Link(destination: WidgetLink.task(card.id ?? "")) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(card.title ?? "")
                            .font(.caption2)
                            .lineLimit(1)
                            .foregroundStyle(Theme.primaryText)
                        if family != .systemMedium, let d = card.dateDisplay, !d.isEmpty {
                            Text(d).font(.system(size: 8))
                                .foregroundStyle(card.isOverdue == true ? Theme.accent : Theme.secondaryText)
                        }
                    }
                    .padding(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Theme.card)
                            .overlay(alignment: .leading) {
                                Group {
                                    if let hexes = card.category_colors, hexes.count > 1 {
                                        Rectangle().fill(LinearGradient(colors: hexes.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom))
                                    } else {
                                        Rectangle().fill(Color(hex: card.category_color ?? ""))
                                    }
                                }.frame(width: 2)
                            }
                    )
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }
}

struct KanbanWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "KanbanWidget", provider: SimpleProvider()) { _ in
            KanbanWidgetView()
        }
        .configurationDisplayName("Kanban")
        .description("To do, in focus and done.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}
