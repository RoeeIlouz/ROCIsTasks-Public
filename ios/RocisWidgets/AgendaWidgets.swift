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
                ForEach(Array(rows.prefix(family.rowLimit + 2).enumerated()), id: \.offset) { _, row in
                    if row.isHeader == true {
                        HStack(spacing: 6) {
                            Text(row.dayLabel ?? "").font(.caption2.bold()).foregroundStyle(Theme.accent)
                            Text(row.dateDisplay ?? "").font(.caption2).foregroundStyle(Theme.secondaryText)
                        }
                        .padding(.top, 2)
                    } else {
                        Link(destination: row.link) { AgendaRow(item: row) }
                    }
                }
                Spacer(minLength: 0)
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

struct WeekViewWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let date: Date

    var body: some View {
        let items = WidgetStore.json("today_agenda_data", as: [AgendaItem].self) ?? []
        let byDay = Dictionary(grouping: items, by: { $0.dateOnly ?? "" })
        let days = weekDays(from: date)

        VStack(alignment: .leading, spacing: 6) {
            Text(date, format: .dateTime.month(.wide).year())
                .font(.headline).foregroundStyle(Theme.primaryText)
            HStack(alignment: .top, spacing: 4) {
                ForEach(days, id: \.self) { day in
                    let key = DayKey.of(day)
                    Link(destination: WidgetLink.calendar(date: key)) {
                        column(day: day, items: byDay[key] ?? [])
                    }
                }
            }
        }
        .widgetURL(WidgetLink.calendar())
        .rocisBackground()
    }

    private func column(day: Date, items: [AgendaItem]) -> some View {
        let isToday = Calendar.current.isDateInToday(day)
        let limit = family == .systemLarge || family == .systemExtraLarge ? 8 : 3
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color(hex: item.category_color ?? "").opacity(0.35)))
                    .foregroundStyle(Theme.primaryText)
            }
            if items.count > limit {
                Text("+\(items.count - limit)").font(.system(size: 9)).foregroundStyle(Theme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    /// The 7 days of the week containing [date], honoring the app's start-of-week
    /// setting (Dart weekday numbering: 1 = Monday ... 7 = Sunday).
    private func weekDays(from date: Date) -> [Date] {
        var calendar = Calendar.current
        let dartStart = WidgetStore.int("full_calendar_start_of_week") ?? 7
        calendar.firstWeekday = dartStart % 7 + 1
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
        .description("This week at a glance.")
        .supportedFamilies([.systemMedium, .systemLarge, .systemExtraLarge])
    }
}

// MARK: - Month + day agenda (month_agenda_*, today_agenda_data)

private struct GridDay: Decodable {
    let isWeekNumber: Bool?
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

struct MonthAgendaWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let grid = (WidgetStore.json("month_agenda_grid_data", as: [GridDay].self) ?? [])
            .filter { $0.isWeekNumber != true }
        let title = WidgetStore.string("month_agenda_month_title") ?? ""
        let today = DayKey.of(Date())
        let agenda = (WidgetStore.json("today_agenda_data", as: [AgendaItem].self) ?? [])
            .filter { $0.dateOnly == today }

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(Theme.primaryText)
                MonthGrid(days: grid, showSummaries: false)
            }
            if family != .systemSmall {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today").font(.caption.bold()).foregroundStyle(Theme.accent)
                    if agenda.isEmpty {
                        EmptyState(text: "Nothing today")
                    } else {
                        ForEach(Array(agenda.prefix(family.rowLimit).enumerated()), id: \.offset) { _, item in
                            Link(destination: item.link) { AgendaRow(item: item) }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .widgetURL(WidgetLink.calendar())
        .rocisBackground()
    }
}

private struct MonthGrid: View {
    let days: [GridDay]
    let showSummaries: Bool

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        LazyVGrid(columns: columns, spacing: showSummaries ? 2 : 3) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                Link(destination: WidgetLink.calendar(date: day.date)) { cell(day) }
            }
        }
    }

    private func cell(_ day: GridDay) -> some View {
        VStack(spacing: 1) {
            Text("\(day.day ?? 0)")
                .font(.system(size: 10, weight: day.isToday == true ? .bold : .regular))
                .frame(width: 18, height: 18)
                .background(Circle().fill(day.isToday == true ? Theme.accent : .clear))
                .foregroundStyle(day.isCurrentMonth == true ? Theme.primaryText : Theme.secondaryText.opacity(0.5))
            if showSummaries {
                ForEach(Array((day.summaries ?? []).prefix(2).enumerated()), id: \.offset) { _, s in
                    Text(s.text ?? "")
                        .font(.system(size: 7))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 1)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Color(hex: s.color ?? "").opacity(0.4)))
                        .foregroundStyle(Theme.primaryText)
                }
                Spacer(minLength: 0)
            } else {
                Circle()
                    .fill(day.hasEvents == true || !(day.summaries ?? []).isEmpty ? Theme.accent : .clear)
                    .frame(width: 3, height: 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: showSummaries ? 44 : 22, alignment: .top)
    }
}

struct MonthAgendaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MonthAgendaWidget", provider: SimpleProvider()) { _ in
            MonthAgendaWidgetView()
        }
        .configurationDisplayName("Month & Agenda")
        .description("The month with today's agenda.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Full calendar (full_calendar_*)

struct FullCalendarWidgetView: View {
    var body: some View {
        let grid = (WidgetStore.json("full_calendar_grid_data", as: [GridDay].self) ?? [])
            .filter { $0.isWeekNumber != true }
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(WidgetStore.string("full_calendar_month_name") ?? "")
                    .font(.headline).foregroundStyle(Theme.primaryText)
                Spacer()
                Link(destination: WidgetLink.addTask) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            MonthGrid(days: grid, showSummaries: true)
            Spacer(minLength: 0)
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
