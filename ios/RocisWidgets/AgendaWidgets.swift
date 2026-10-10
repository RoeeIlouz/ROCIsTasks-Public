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
    let dateOnly: String?
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
            ColorBar(color: Color(hex: item.category_color ?? ""))
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
                Text("Agenda").font(.headline).foregroundStyle(Theme.primaryText)
                Spacer()
                Link(destination: WidgetLink.addTask) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            if rows.isEmpty {
                EmptyState(text: "Nothing scheduled")
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

struct WeekViewWidgetView: View {
    let date: Date

    var body: some View {
        let items = WidgetStore.json("today_agenda_data", as: [AgendaItem].self) ?? []
        let byDay = Dictionary(grouping: items, by: { $0.dateOnly ?? "" })
        let offset = WeekPaging.offset
        let calendar = weekCalendar
        let shown = calendar.date(byAdding: .weekOfYear, value: offset, to: date) ?? date
        let days = weekDays(containing: shown, calendar: calendar)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(shown, format: .dateTime.month(.wide).year())
                    .font(.headline).foregroundStyle(Theme.primaryText)
                Spacer(minLength: 0)
                if offset != 0 {
                    Button(intent: PageIntent(key: WeekPaging.key, value: 0)) {
                        Image(systemName: "calendar.badge.clock")
                    }
                }
                Button(intent: PageIntent(key: WeekPaging.key, value: offset - 1)) {
                    Image(systemName: "chevron.left")
                }
                .disabled(offset <= WeekPaging.range.lowerBound)
                Button(intent: PageIntent(key: WeekPaging.key, value: offset + 1)) {
                    Image(systemName: "chevron.right")
                }
                .disabled(offset >= WeekPaging.range.upperBound)
            }
            .font(.subheadline.bold())
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)

            GeometryReader { geo in
                // Weekday + date header take ~40pt; each item chip is 13pt + 3pt gap.
                let capacity = max(1, Int((geo.size.height - 40) / 16))
                HStack(alignment: .top, spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        let key = DayKey.of(day)
                        Link(destination: WidgetLink.calendar(date: key)) {
                            column(day: day, items: byDay[key] ?? [], capacity: capacity)
                        }
                    }
                }
            }
        }
        .widgetURL(WidgetLink.calendar())
        .rocisBackground()
    }

    private func column(day: Date, items: [AgendaItem], capacity: Int) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        // Reserve the last slot for "+N" when the day has more than fits.
        let limit = items.count > capacity ? max(0, capacity - 1) : capacity
        return VStack(spacing: 3) {
            Text(day, format: .dateTime.weekday(.narrow))
                .font(.caption2).foregroundStyle(Theme.secondaryText)
            Text(day, format: .dateTime.day())
                .font(.caption.bold())
                .frame(width: 22, height: 22)
                .background(Circle().fill(isToday ? Theme.accent : .clear))
                .foregroundStyle(Theme.primaryText)
            ForEach(Array(items.prefix(limit).enumerated()), id: \.offset) { _, item in
                Text(item.title ?? "")
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, minHeight: 13, maxHeight: 13, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: item.category_color ?? "").opacity(0.35)))
                    .foregroundStyle(Theme.primaryText)
            }
            if items.count > limit {
                Text("+\(items.count - limit)")
                    .font(.system(size: 9))
                    .frame(height: 13)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    /// Honors the app's start-of-week setting (Dart: 1 = Monday ... 7 = Sunday).
    private var weekCalendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = (WidgetStore.int("full_calendar_start_of_week") ?? 7) % 7 + 1
        return calendar
    }

    private func weekDays(containing date: Date, calendar: Calendar) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

struct WeekViewWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekViewWidget", provider: SimpleProvider()) { entry in
            WeekViewWidgetView(date: entry.date)
        }
        .configurationDisplayName("Week View")
        .description("Your week at a glance. Page between weeks.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Month grids (month_agenda_*, full_calendar_*)

private struct GridDay: Decodable {
    let isWeekNumber: Bool?
    let weekNumber: Int?
    let date: String?
    let day: Int?
    let isCurrentMonth: Bool?
    let isToday: Bool?
    let hasEvents: Bool?
    let summaries: [Summary]?

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
            let rowHeight = rows.isEmpty ? 0 : (geo.size.height - spacing * CGFloat(rows.count - 1)) / CGFloat(rows.count)
            // Date circle is 18pt; each summary chip needs ~10pt.
            let summaryCount = showSummaries ? max(0, Int((rowHeight - 19) / 10)) : 0
            VStack(spacing: spacing) {
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
                Text("Today").font(.caption.bold()).foregroundStyle(Theme.accent)
                if agenda.isEmpty {
                    EmptyState(text: "Nothing today")
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

struct FullCalendarWidgetView: View {
    var body: some View {
        let grid = WidgetStore.json("full_calendar_grid_data", as: [GridDay].self) ?? []
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(WidgetStore.string("full_calendar_month_name") ?? "")
                    .font(.headline).foregroundStyle(Theme.primaryText)
                Spacer()
                Link(destination: WidgetLink.addTask) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            MonthGrid(
                entries: grid,
                showSummaries: true,
                // The app's "Show week numbers" widget setting.
                showWeekNumbers: WidgetStore.bool("full_calendar_show_week_numbers", default: false)
            )
        }
        .widgetURL(WidgetLink.calendar())
        .rocisBackground()
    }
}

struct FullCalendarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FullCalendarWidget", provider: SimpleProvider()) { _ in
            FullCalendarWidgetView()
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
            Text("Board").font(.headline).foregroundStyle(Theme.primaryText)
            HStack(alignment: .top, spacing: 6) {
                column("In focus", data?.column_infocus ?? [], Theme.accent)
                column("To do", data?.column_todo ?? [], Color(hex: "#3B82F6"))
                column("Done", data?.column_done ?? [], Theme.done)
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
                                Rectangle().fill(Color(hex: card.category_color ?? "")).frame(width: 2)
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
