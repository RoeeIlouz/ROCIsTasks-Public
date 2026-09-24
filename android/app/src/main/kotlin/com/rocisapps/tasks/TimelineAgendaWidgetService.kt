package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class TimelineAgendaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TimelineAgendaWidgetFactory(this.applicationContext)
    }
}

class TimelineAgendaWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {

    /** A day section (header) or a task/event row. */
    private class Row(
        val item: JSONObject?,
        val dayKey: String = "",
        val dayLabel: String = "",
        val dateLabel: String = "",
        val isToday: Boolean = false
    )

    private val rows = ArrayList<Row>()
    private var palette: FullCalendarWidgetUtils.Palette? = null
    private var locale: Locale = Locale.getDefault()
    private var todayKey = ""
    private var nowMinutes = 0

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            palette = WidgetStyle.palette(context, widgetData)
            locale = WidgetLocaleHelper.getWidgetLocale(widgetData)

            val now = Calendar.getInstance()
            todayKey = dayKeyFormat().format(now.time)
            nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)

            val jsonArray = JSONArray(widgetData.getString("timeline_agenda_data", "[]") ?: "[]")
            val raw = mutableListOf<JSONObject>()
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.optJSONObject(i) ?: continue
                raw.add(obj)
            }

            rows.clear()
            rows.addAll(buildRows(raw))
        } catch (_: Exception) {
            // Keep existing rows on error
        }
    }

    /**
     * Regroups the items by day natively so the section labels ("Today", "Tomorrow", ...)
     * stay correct after midnight and follow the widget language. Falls back to the
     * Dart-built sections for data written before items carried `dateOnly`.
     */
    private fun buildRows(raw: List<JSONObject>): List<Row> {
        val items = raw.filter { !it.optBoolean("isHeader", false) }
        if (items.any { it.optString("dateOnly", "").isEmpty() }) {
            return raw.map { obj ->
                if (obj.optBoolean("isHeader", false)) {
                    val label = obj.optString("dayLabel", "")
                    Row(
                        item = null,
                        dayLabel = label,
                        dateLabel = obj.optString("dateDisplay", ""),
                        isToday = label.equals(WidgetLocaleHelper.getTodayText(locale), ignoreCase = true)
                    )
                } else {
                    Row(obj)
                }
            }
        }

        // By day, then all-day first, then by start time (stable for equal keys).
        val sorted = items.sortedWith(compareBy<JSONObject>(
            { it.optString("dateOnly") },
            { if (it.has("sortMinutes")) it.optInt("sortMinutes") else if (it.optBoolean("isAllDay")) -1 else 0 }
        ))

        val result = ArrayList<Row>()
        var currentDay: String? = null
        for (item in sorted) {
            val day = item.optString("dateOnly")
            if (day != currentDay) {
                currentDay = day
                result.add(sectionRow(day))
            }
            result.add(Row(item, dayKey = day))
        }
        return result
    }

    private fun sectionRow(dayKey: String): Row {
        val cal = Calendar.getInstance()
        try {
            cal.time = dayKeyFormat().parse(dayKey) ?: return Row(null, dayKey, dayKey)
        } catch (_: Exception) {
            return Row(null, dayKey, dayKey)
        }
        val today = Calendar.getInstance()
        val diff = daysBetween(today, cal)
        val label = when (diff) {
            0 -> WidgetLocaleHelper.getTodayText(locale)
            1 -> WidgetLocaleHelper.getTomorrowText(locale)
            -1 -> WidgetLocaleHelper.getYesterdayText(locale)
            else -> SimpleDateFormat("EEEE", locale).format(cal.time)
                .replaceFirstChar { if (it.isLowerCase()) it.titlecase(locale) else it.toString() }
        }
        val date = try {
            val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "MMMd")
            SimpleDateFormat(pattern, locale).format(cal.time)
        } catch (_: Exception) {
            SimpleDateFormat("MMM d", locale).format(cal.time)
        }
        return Row(null, dayKey, label, date, diff == 0)
    }

    private fun daysBetween(from: Calendar, to: Calendar): Int {
        fun midnight(c: Calendar) = (c.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        // Rounded so DST shifts don't skew the day count.
        return Math.round((midnight(to) - midnight(from)) / 86_400_000.0).toInt()
    }

    private fun dayKeyFormat() = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    override fun onDestroy() {
        rows.clear()
    }

    override fun getCount(): Int = rows.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= rows.size) {
            return RemoteViews(context.packageName, R.layout.widget_timeline_header_item)
        }
        val row = rows[position]
        val item = row.item
        return if (item == null) sectionView(row) else itemView(item, row.dayKey)
    }

    private fun sectionView(row: Row): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_timeline_header_item)
        val palette = palette ?: return views
        try {
            views.setTextViewText(R.id.widget_timeline_section_day, row.dayLabel)
            // "Today" reads in the accent, other days muted (like the app's day header).
            views.setTextColor(R.id.widget_timeline_section_day, if (row.isToday) palette.primary else palette.onSurfaceMuted)
            views.setTextViewText(R.id.widget_timeline_section_date, row.dateLabel)
            views.setTextColor(R.id.widget_timeline_section_date, palette.onSurfaceMuted)
            views.setInt(
                R.id.widget_timeline_section_line, "setBackgroundColor",
                WidgetStyle.withAlpha(if (row.isToday) palette.primary else palette.onSurface, 0x1F)
            )
            if (row.dayKey.isNotEmpty()) {
                views.setOnClickFillInIntent(
                    R.id.widget_timeline_section_root,
                    Intent().apply { data = Uri.parse("rocistasks://calendar?date=${row.dayKey}") }
                )
            }
        } catch (_: Exception) {}
        return views
    }

    private fun itemView(item: JSONObject, dayKey: String): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_timeline_event_item)
        val palette = palette ?: return views

        try {
            val type = item.optString("type", "task")
            val id = item.optString("id", "")
            val subtitle = item.optString("subtitle", "")
            val rawTime = item.optString("timeDisplay", "")
            val isAllDay = item.optBoolean("isAllDay", false)
            val timeDisplay = if (isAllDay) WidgetLocaleHelper.getAllDayText(locale) else rawTime
            val accent = WidgetStyle.parseColor(item.optString("category_color", ""), palette.primary)

            // Tile: a faint onSurface wash on the card, like the app's list tiles.
            WidgetStyle.applyTile(views, R.id.widget_timeline_item_fill, palette.onSurface, if (palette.isDark) 0x14 else 0x0D)
            views.setInt(R.id.widget_timeline_color_strip, "setColorFilter", accent)

            views.setTextViewText(R.id.widget_timeline_item_title, item.optString("title", ""))
            views.setTextColor(R.id.widget_timeline_item_title, palette.onSurface)
            views.setTextViewText(R.id.widget_timeline_time, timeDisplay)
            views.setViewVisibility(R.id.widget_timeline_time, if (timeDisplay.isEmpty()) View.GONE else View.VISIBLE)
            // For events the subtitle repeats the time (or "All day") when there is no location.
            val meta = if (subtitle == rawTime) "" else subtitle
            views.setTextViewText(R.id.widget_timeline_subtitle, meta)
            views.setTextColor(R.id.widget_timeline_subtitle, palette.onSurfaceMuted)

            val day = item.optString("dateOnly", "").ifEmpty { dayKey }

            if (type == "task") {
                views.setViewVisibility(R.id.widget_timeline_check, View.VISIBLE)
                views.setViewVisibility(R.id.widget_timeline_event_icon, View.GONE)
                val done = item.optBoolean("isCompleted", false)
                views.setImageViewResource(
                    R.id.widget_timeline_check,
                    if (done) R.drawable.ic_widget_check_on else R.drawable.ic_widget_check_off
                )
                views.setInt(R.id.widget_timeline_check, "setColorFilter", if (done) palette.primary else palette.onSurfaceMuted)
                if (id.isNotEmpty()) {
                    views.setOnClickFillInIntent(
                        R.id.widget_timeline_check,
                        Intent().apply { data = Uri.parse("rocistasks://complete?id=$id") }
                    )
                }

                // Past-due pending tasks show their time in the high-priority red.
                val minutes = if (item.has("sortMinutes")) item.optInt("sortMinutes") else -1
                val overdue = !done && day.isNotEmpty() &&
                    (day < todayKey || (day == todayKey && minutes >= 0 && minutes < nowMinutes))
                views.setTextColor(R.id.widget_timeline_time, if (overdue) WidgetStyle.PRIORITY_HIGH else palette.primary)

                val priority = item.optString("priority", "")
                val priorityColor = WidgetStyle.priorityColor(priority)
                // Low priority is the default; only flag medium and high like the app.
                if (priorityColor != null && !priority.equals("low", ignoreCase = true)) {
                    views.setViewVisibility(R.id.widget_timeline_badge_box, View.VISIBLE)
                    views.setTextViewText(R.id.widget_timeline_badge, WidgetStyle.priorityLabel(priority, locale))
                    views.setTextColor(R.id.widget_timeline_badge, priorityColor)
                    WidgetStyle.applyTile(views, R.id.widget_timeline_badge_fill, priorityColor, 0x26)
                } else {
                    views.setViewVisibility(R.id.widget_timeline_badge_box, View.GONE)
                }

                if (id.isNotEmpty()) {
                    views.setOnClickFillInIntent(
                        R.id.widget_timeline_item_root,
                        Intent().apply { data = Uri.parse("rocistasks://task_detail?id=$id") }
                    )
                }
            } else {
                views.setViewVisibility(R.id.widget_timeline_check, View.GONE)
                views.setViewVisibility(R.id.widget_timeline_event_icon, View.VISIBLE)
                views.setInt(R.id.widget_timeline_event_icon, "setColorFilter", accent)
                views.setViewVisibility(R.id.widget_timeline_badge_box, View.GONE)
                views.setTextColor(R.id.widget_timeline_time, palette.primary)

                // Events open the in-app calendar on their day.
                val uri = if (day.isNotEmpty()) "rocistasks://calendar?date=$day" else "rocistasks://calendar"
                views.setOnClickFillInIntent(
                    R.id.widget_timeline_item_root,
                    Intent().apply { data = Uri.parse(uri) }
                )
            }
        } catch (_: Exception) {}

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 2
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
