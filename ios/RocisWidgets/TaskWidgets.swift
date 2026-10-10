import SwiftUI
import WidgetKit

// MARK: - Task list (pending_tasks_list)

private struct WidgetTask: Decodable, Identifiable {
    let id: String
    let title: String
    let priority: String?
    let category_name: String?
    let category_color: String?
    let dueDate: String?
    let isCompleted: Bool?
    let isPinned: Bool?
}

struct TaskWidgetView: View {
    @Environment(\.widgetFamily) private var family

    private var tasks: [WidgetTask] {
        (WidgetStore.json("pending_tasks_list", as: [WidgetTask].self) ?? [])
            .filter { $0.isCompleted != true }
    }

    var body: some View {
        let all = tasks
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Tasks").font(.headline).foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(all.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundStyle(.white)
                Link(destination: WidgetLink.addTask) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                }
            }
            if all.isEmpty {
                EmptyState(text: "All tasks completed")
            } else {
                ForEach(all.prefix(family.rowLimit)) { task in
                    Link(destination: WidgetLink.task(task.id)) { row(task) }
                }
                Spacer(minLength: 0)
            }
        }
        // Small widgets ignore Links; the whole widget opens the app.
        .widgetURL(WidgetLink.url("tasks"))
        .rocisBackground()
    }

    private func row(_ task: WidgetTask) -> some View {
        HStack(spacing: 8) {
            ColorBar(color: Color(hex: task.category_color ?? ""))
            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                if family != .systemSmall, let due = task.dueDate, !due.isEmpty {
                    Text(due).font(.caption2).foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer(minLength: 0)
            if task.isPinned == true {
                Image(systemName: "pin.fill").font(.caption2).foregroundStyle(Theme.secondaryText)
            }
            if let color = Theme.priority(task.priority ?? "") {
                Circle().fill(color).frame(width: 6, height: 6)
            }
        }
        .frame(height: family == .systemSmall ? 22 : 30)
    }
}

struct TaskWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TaskWidget", provider: SimpleProvider()) { _ in
            TaskWidgetView()
        }
        .configurationDisplayName("Tasks")
        .description("Your pending tasks.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Up Next (up_next_*)

struct UpNextWidgetView: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let type = WidgetStore.string("up_next_type") ?? "none"
        let title = WidgetStore.string("up_next_title") ?? "All tasks completed"
        let subtitle = WidgetStore.string("up_next_subtitle") ?? ""
        let color = Color(hex: WidgetStore.string("up_next_color") ?? "#10B981")
        let startMillis = WidgetStore.int("up_next_start_millis") ?? -1
        let start = startMillis > 0 ? Date(timeIntervalSince1970: Double(startMillis) / 1000) : nil
        let id = WidgetStore.string("up_next_id") ?? ""

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon(for: type)).foregroundStyle(color)
                Text("Up next").font(.caption.bold()).foregroundStyle(Theme.secondaryText)
                Spacer(minLength: 0)
            }
            Text(title)
                .font(family == .systemSmall ? .headline : .title3.bold())
                .foregroundStyle(Theme.primaryText)
                .lineLimit(family == .systemSmall ? 3 : 2)
            if !subtitle.isEmpty {
                Text(subtitle).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
            Spacer(minLength: 0)
            badge(type: type, start: start, color: color)
        }
        .widgetURL(type == "task" && !id.isEmpty ? WidgetLink.task(id) : WidgetLink.calendar())
        .rocisBackground()
    }

    @ViewBuilder
    private func badge(type: String, start: Date?, color: Color) -> some View {
        Group {
            if let start, start > Date() {
                Text(start, style: .relative)
            } else if let start {
                Text(start, style: .time)
            } else {
                Text(WidgetStore.string("up_next_time_display") ?? "")
            }
        }
        .font(.caption.bold())
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.25)))
        .foregroundStyle(color)
    }

    private func icon(for type: String) -> String {
        switch type {
        case "event": return "calendar"
        case "schedule": return "graduationcap.fill"
        case "none": return "checkmark.circle.fill"
        default: return "checklist"
        }
    }
}

struct UpNextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "UpNextWidget", provider: SimpleProvider(refresh: 15 * 60)) { _ in
            UpNextWidgetView()
        }
        .configurationDisplayName("Up Next")
        .description("Your next task, event or class.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Quick actions (quick_action_*)

struct QuickActionWidgetView: View {
    var body: some View {
        let pending = WidgetStore.int("quick_action_pending_count") ?? 0
        let completed = WidgetStore.int("quick_action_completed_count") ?? 0
        let total = pending + completed

        VStack(alignment: .leading, spacing: 8) {
            Text("Today").font(.caption.bold()).foregroundStyle(Theme.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(completed)").font(.largeTitle.bold()).foregroundStyle(Theme.primaryText)
                Text("/ \(total)").font(.headline).foregroundStyle(Theme.secondaryText)
            }
            ProgressView(value: total == 0 ? 1 : Double(completed), total: total == 0 ? 1 : Double(total))
                .tint(Theme.done)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Link(destination: WidgetLink.addTask) { action("plus", "Add") }
                Link(destination: WidgetLink.calendar()) { action("calendar", "Plan") }
            }
        }
        .widgetURL(WidgetLink.addTask)
        .rocisBackground()
    }

    private func action(_ symbol: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(label)
        }
        .font(.caption.bold())
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.accent))
        .foregroundStyle(.white)
    }
}

struct QuickActionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickActionWidget", provider: SimpleProvider()) { _ in
            QuickActionWidgetView()
        }
        .configurationDisplayName("Quick Actions")
        .description("Today's progress with quick add.")
        .supportedFamilies([.systemSmall])
    }
}
