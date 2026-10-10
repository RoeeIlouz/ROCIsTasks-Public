import SwiftUI
import WidgetKit
import AppIntents

// MARK: - Data store

/// Reads what the Flutter app writes with HomeWidget.saveWidgetData.
///
/// The app and this extension share the App Group "group.<app bundle id>".
/// The extension's bundle ID is "<app bundle id>.RocisWidgets", so the group is
/// derived from it at runtime; sideloading renames both IDs consistently.
enum WidgetStore {
    static let defaults: UserDefaults? = {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let appID = bundleID.split(separator: ".").dropLast().joined(separator: ".")
        return UserDefaults(suiteName: "group.\(appID)")
    }()

    static func string(_ key: String) -> String? {
        defaults?.string(forKey: key)
    }

    static func int(_ key: String) -> Int? {
        guard let value = defaults?.object(forKey: key) else { return nil }
        return (value as? NSNumber)?.intValue
    }

    static func bool(_ key: String, default fallback: Bool) -> Bool {
        guard let value = defaults?.object(forKey: key) as? NSNumber else { return fallback }
        return value.boolValue
    }

    /// Decodes a JSON string value, e.g. `today_agenda_data`.
    static func json<T: Decodable>(_ key: String, as type: T.Type) -> T? {
        guard let raw = string(key), let data = raw.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Deep links

/// Links back into the app. home_widget only reports URLs that carry the
/// `homeWidget` query item; the app routes on the host (see home_screen.dart).
enum WidgetLink {
    static func url(_ host: String, _ query: [String: String] = [:]) -> URL {
        var components = URLComponents()
        components.scheme = "rocistasks"
        components.host = host
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
            + [URLQueryItem(name: "homeWidget", value: nil)]
        return components.url ?? URL(fileURLWithPath: "/")
    }

    static let addTask = url("add_task")
    static let kanban = url("open_kanban")
    static func calendar(date: String? = nil) -> URL {
        date.map { url("calendar", ["date": $0]) } ?? url("calendar")
    }
    static func task(_ id: String) -> URL { url("task_detail", ["id": id]) }
}

// MARK: - Theme

enum Theme {
    static let accent = Color(hex: "#E5323F")
    static let background = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let card = Color.white.opacity(0.06)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.6)
    static let done = Color(hex: "#10B981")

    static func priority(_ name: String) -> Color? {
        switch name.lowercased() {
        case "high", "urgent": return Color(hex: "#EF4444")
        case "medium": return Color(hex: "#F59E0B")
        case "low": return Color(hex: "#3B82F6")
        default: return nil
        }
    }
}

extension Color {
    /// Accepts "#RRGGBB" and the app's "#AARRGGBB"; anything else is the
    /// brand red. (No `Theme.accent` default argument: Theme.accent is built
    /// with this initializer, and reading it while it initializes traps.)
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard let number = UInt64(value, radix: 16), value.count == 6 || value.count == 8 else {
            self = Color(.sRGB, red: 0xE5 / 255, green: 0x32 / 255, blue: 0x3F / 255)
            return
        }
        let alpha = value.count == 8 ? Double((number >> 24) & 0xFF) / 255 : 1
        self = Color(
            .sRGB,
            red: Double((number >> 16) & 0xFF) / 255,
            green: Double((number >> 8) & 0xFF) / 255,
            blue: Double(number & 0xFF) / 255,
            opacity: alpha == 0 ? 1 : alpha
        )
    }
}

extension View {
    /// Dark card background used by every ROCIs widget.
    func rocisBackground() -> some View {
        containerBackground(for: .widget) { Theme.background }
    }
}

// MARK: - Shared views

struct ColorBar: View {
    let color: Color
    var body: some View {
        RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4)
    }
}

struct EmptyState: View {
    let text: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(Theme.done)
            Text(text)
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// How many rows fit for each widget size.
extension WidgetFamily {
    var rowLimit: Int {
        switch self {
        case .systemSmall: return 3
        case .systemMedium: return 4
        case .systemLarge: return 9
        case .systemExtraLarge: return 10
        default: return 3
        }
    }
}

// MARK: - Timeline helpers

/// All ROCIs widgets are pushed fresh by the app; this is only a fallback
/// reload so time-relative content (today, up next) doesn't go stale.
struct SimpleEntry: TimelineEntry {
    let date: Date
}

struct SimpleProvider: TimelineProvider {
    var refresh: TimeInterval = 30 * 60

    func placeholder(in context: Context) -> SimpleEntry { SimpleEntry(date: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        completion(SimpleEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let now = Date()
        completion(Timeline(entries: [SimpleEntry(date: now)], policy: .after(now.addingTimeInterval(refresh))))
    }
}

enum DayKey {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func of(_ date: Date) -> String { formatter.string(from: date) }
    static func date(_ key: String) -> Date? { formatter.date(from: key) }
}

// MARK: - Paging

/// Widgets can't scroll, so long lists page with buttons (iOS 17 interactive
/// widgets). The page lives in the shared store under `key`; the button sets
/// the target page and WidgetKit reloads the widget.
struct PageIntent: AppIntent {
    static var title: LocalizedStringResource = "Change widget page"
    static var isDiscoverable = false

    @Parameter(title: "Key") var key: String
    @Parameter(title: "Value") var value: Int

    init() {}
    init(key: String, value: Int) {
        self.key = key
        self.value = value
    }

    func perform() async throws -> some IntentResult {
        WidgetStore.defaults?.set(value, forKey: key)
        return .result()
    }
}

struct PagerBar: View {
    let key: String
    let page: Int
    let pages: Int

    var body: some View {
        HStack(spacing: 10) {
            Spacer(minLength: 0)
            Button(intent: PageIntent(key: key, value: page - 1)) {
                Image(systemName: "chevron.up")
            }
            .disabled(page == 0)
            Text("\(page + 1)/\(pages)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.secondaryText)
            Button(intent: PageIntent(key: key, value: page + 1)) {
                Image(systemName: "chevron.down")
            }
            .disabled(page >= pages - 1)
        }
        .font(.caption.bold())
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .frame(height: PagedList<Int, EmptyView>.pagerHeight)
    }
}

/// Lays out as many rows as fit the widget's real height and pages the rest.
struct PagedList<Item, Row: View>: View {
    static var pagerHeight: CGFloat { 18 }

    let items: [Item]
    let pageKey: String
    var spacing: CGFloat = 4
    let height: (Item) -> CGFloat
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        GeometryReader { geo in
            let all = pages(fitting: geo.size.height)
            let paged = all.count > 1
            let pagesList = paged ? pages(fitting: geo.size.height - Self.pagerHeight - spacing) : all
            let page = min(max(0, WidgetStore.int(pageKey) ?? 0), pagesList.count - 1)
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(Array(pagesList[page].enumerated()), id: \.offset) { _, index in
                    row(items[index]).frame(height: height(items[index]))
                }
                Spacer(minLength: 0)
                if paged {
                    PagerBar(key: pageKey, page: page, pages: pagesList.count)
                }
            }
        }
    }

    /// Splits item indices into pages whose rows fit `available` points.
    private func pages(fitting available: CGFloat) -> [[Int]] {
        var result: [[Int]] = [[]]
        var used: CGFloat = 0
        for index in items.indices {
            let h = height(items[index])
            let needed = result[result.count - 1].isEmpty ? h : used + spacing + h
            if needed > available, !result[result.count - 1].isEmpty {
                result.append([index])
                used = h
            } else {
                result[result.count - 1].append(index)
                used = needed
            }
        }
        return result
    }
}
