import SwiftUI
import WidgetKit

/// Widget kinds match the iOSName values the Flutter app passes to
/// HomeWidget.updateWidget, so app updates reload the right widget.
@main
struct RocisWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TaskWidget()
        UpNextWidget()
        QuickActionWidget()
        TimelineAgendaWidget()
        WeekViewWidget()
        MonthAgendaWidget()
        FullCalendarWidget()
        KanbanWidget()
    }
}
