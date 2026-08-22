package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.graphics.Color
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

// 1. Grid RemoteViewsService for Month Grid (Left half)
class MonthAgendaGridService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MonthAgendaGridFactory(this.applicationContext)
    }
}

class MonthAgendaGridFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val days = ArrayList<JSONObject>()
    private var selectedDateStr = ""
    private var widgetTheme = "system"
    private var highlightColor = Color.parseColor("#6366F1")

    private data class DayCellIds(
        val rootId: Int,
        val bgId: Int,
        val textId: Int,
        val dotId: Int
    )

    private val cellIdsList = arrayOf(
        DayCellIds(R.id.widget_month_day_0, R.id.widget_month_bg_0, R.id.widget_month_text_0, R.id.widget_month_dot_0),
        DayCellIds(R.id.widget_month_day_1, R.id.widget_month_bg_1, R.id.widget_month_text_1, R.id.widget_month_dot_1),
        DayCellIds(R.id.widget_month_day_2, R.id.widget_month_bg_2, R.id.widget_month_text_2, R.id.widget_month_dot_2),
        DayCellIds(R.id.widget_month_day_3, R.id.widget_month_bg_3, R.id.widget_month_text_3, R.id.widget_month_dot_3),
        DayCellIds(R.id.widget_month_day_4, R.id.widget_month_bg_4, R.id.widget_month_text_4, R.id.widget_month_dot_4),
        DayCellIds(R.id.widget_month_day_5, R.id.widget_month_bg_5, R.id.widget_month_text_5, R.id.widget_month_dot_5),
        DayCellIds(R.id.widget_month_day_6, R.id.widget_month_bg_6, R.id.widget_month_text_6, R.id.widget_month_dot_6),
    )

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        days.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            widgetTheme = widgetData.getString("full_calendar_theme", "system") ?: "system"
            val colorHex = widgetData.getString("full_calendar_highlight_color", "#6366F1") ?: "#6366F1"
            highlightColor = try {
                Color.parseColor(colorHex)
            } catch (_: Exception) {
                Color.parseColor("#6366F1")
            }

            selectedDateStr = widgetData.getString(MonthAgendaWidgetProvider.PREF_SELECTED_DATE, "") ?: ""
            if (selectedDateStr.isEmpty()) {
                selectedDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
            }

            val offset = widgetData.getInt(MonthAgendaWidgetProvider.PREF_MONTH_OFFSET, 0)
            val cal = Calendar.getInstance()
            val todayYear = cal.get(Calendar.YEAR)
            val todayMonth = cal.get(Calendar.MONTH)
            val todayDay = cal.get(Calendar.DAY_OF_MONTH)
            val todayStr = String.format(Locale.US, "%04d-%02d-%02d", todayYear, todayMonth + 1, todayDay)

            if (offset != 0) {
                cal.add(Calendar.MONTH, offset)
            }
            val targetYear = cal.get(Calendar.YEAR)
            val targetMonth = cal.get(Calendar.MONTH)

            // Set to 1st of the target month
            val firstDayCal = Calendar.getInstance().apply {
                set(Calendar.YEAR, targetYear)
                set(Calendar.MONTH, targetMonth)
                set(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            val startOfWeek = widgetData.getInt("full_calendar_start_of_week", 7) // 7 = Sunday, 1 = Monday
            val dayOfWeek = firstDayCal.get(Calendar.DAY_OF_WEEK) // 1 = Sun, 2 = Mon ...

            val diff = if (startOfWeek == 1) {
                (dayOfWeek - Calendar.MONDAY + 7) % 7
            } else {
                (dayOfWeek - Calendar.SUNDAY + 7) % 7
            }

            val gridCal = (firstDayCal.clone() as Calendar).apply {
                add(Calendar.DAY_OF_MONTH, -diff)
            }

            // Gather event dates from agenda and grid data
            val eventDates = HashSet<String>()
            val rawAgenda = widgetData.getString("today_agenda_data", "[]") ?: "[]"
            try {
                val agendaArray = JSONArray(rawAgenda)
                for (i in 0 until agendaArray.length()) {
                    val item = agendaArray.optJSONObject(i) ?: continue
                    val d = item.optString("date", "")
                    if (d.length >= 10) {
                        eventDates.add(d.substring(0, 10))
                    }
                    val dateOnly = item.optString("dateOnly", "")
                    if (dateOnly.length >= 10) {
                        eventDates.add(dateOnly.substring(0, 10))
                    }
                }
            } catch (_: Exception) {}

            try {
                val rawGrid = widgetData.getString("month_agenda_grid_data", "[]") ?: "[]"
                val jsonArray = JSONArray(rawGrid)
                for (i in 0 until jsonArray.length()) {
                    val obj = jsonArray.optJSONObject(i) ?: continue
                    if (obj.optBoolean("hasEvents", false)) {
                        val d = obj.optString("date", "")
                        if (d.length >= 10) {
                            eventDates.add(d.substring(0, 10))
                        }
                    }
                }
            } catch (_: Exception) {}

            // Generate exactly 42 days (6 weeks x 7 days)
            for (i in 0 until 42) {
                val year = gridCal.get(Calendar.YEAR)
                val month = gridCal.get(Calendar.MONTH)
                val day = gridCal.get(Calendar.DAY_OF_MONTH)
                val dateStr = String.format(Locale.US, "%04d-%02d-%02d", year, month + 1, day)
                val isCurrentMonth = (month == targetMonth)
                val isToday = (dateStr == todayStr)
                val hasEvents = eventDates.contains(dateStr)

                val dayObj = JSONObject().apply {
                    put("day", day)
                    put("date", dateStr)
                    put("isCurrentMonth", isCurrentMonth)
                    put("isToday", isToday)
                    put("hasEvents", hasEvents)
                }
                days.add(dayObj)
                gridCal.add(Calendar.DAY_OF_MONTH, 1)
            }
        } catch (_: Exception) {
            days.clear()
        }
    }

    override fun onDestroy() {
        days.clear()
    }

    override fun getCount(): Int = days.size / 7

    override fun getViewAt(position: Int): RemoteViews {
        val rowViews = RemoteViews(context.packageName, R.layout.widget_month_agenda_row)
        val startIndex = position * 7

        for (i in 0 until 7) {
            val cellIds = cellIdsList[i]
            val cellIndex = startIndex + i
            if (cellIndex >= days.size) {
                rowViews.setViewVisibility(cellIds.rootId, View.INVISIBLE)
                continue
            }
            rowViews.setViewVisibility(cellIds.rootId, View.VISIBLE)

            val day = days[cellIndex]
            val dayNum = day.optInt("day", 1)
            val dateStr = day.optString("date", "")
            val isCurrentMonth = day.optBoolean("isCurrentMonth", true)
            val isToday = day.optBoolean("isToday", false)
            val hasEvents = day.optBoolean("hasEvents", false)
            val isSelected = dateStr.isNotEmpty() && dateStr == selectedDateStr

            rowViews.setTextViewText(cellIds.textId, dayNum.toString())

            // Text colors
            val textColor = when {
                !isCurrentMonth -> Color.parseColor("#50888888")
                isSelected || isToday -> highlightColor
                else -> when (widgetTheme) {
                    "light" -> Color.parseColor("#0F172A")
                    else -> Color.parseColor("#FFFFFF")
                }
            }
            rowViews.setTextColor(cellIds.textId, textColor)

            if (isSelected) {
                rowViews.setViewVisibility(cellIds.bgId, View.VISIBLE)
                rowViews.setInt(cellIds.bgId, "setColorFilter", highlightColor)
                rowViews.setInt(cellIds.bgId, "setImageAlpha", 0x44)
            } else if (isToday) {
                rowViews.setViewVisibility(cellIds.bgId, View.VISIBLE)
                rowViews.setInt(cellIds.bgId, "setColorFilter", highlightColor)
                rowViews.setInt(cellIds.bgId, "setImageAlpha", 0x22)
            } else {
                rowViews.setViewVisibility(cellIds.bgId, View.GONE)
            }

            if (hasEvents) {
                rowViews.setViewVisibility(cellIds.dotId, View.VISIBLE)
                rowViews.setInt(cellIds.dotId, "setColorFilter", highlightColor)
            } else {
                rowViews.setViewVisibility(cellIds.dotId, View.GONE)
            }

            // Fill-in broadcast intent to select this day
            if (dateStr.isNotEmpty()) {
                val fillIntent = Intent().apply {
                    putExtra("date", dateStr)
                }
                rowViews.setOnClickFillInIntent(cellIds.rootId, fillIntent)
            }
        }

        return rowViews
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}

// 2. Day Agenda List RemoteViewsService (Right half)
class MonthAgendaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MonthAgendaListFactory(this.applicationContext)
    }
}

class MonthAgendaListFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val items = ArrayList<JSONObject>()
    private var widgetTheme = "system"
    private var highlightColor = Color.parseColor("#6366F1")

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        items.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            widgetTheme = widgetData.getString("full_calendar_theme", "system") ?: "system"
            val colorHex = widgetData.getString("full_calendar_highlight_color", "#6366F1") ?: "#6366F1"
            highlightColor = try {
                Color.parseColor(colorHex)
            } catch (_: Exception) {
                Color.parseColor("#6366F1")
            }

            var selectedDate = widgetData.getString(MonthAgendaWidgetProvider.PREF_SELECTED_DATE, "") ?: ""
            if (selectedDate.isEmpty()) {
                selectedDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
            }

            val rawJson = widgetData.getString("today_agenda_data", "[]") ?: "[]"
            val jsonArray = JSONArray(rawJson)

            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.optJSONObject(i) ?: continue
                val itemDate = item.optString("date", "")
                val itemDateOnly = item.optString("dateOnly", "")
                val itemDateDisplay = item.optString("dateDisplay", "")
                if (itemDateOnly == selectedDate || itemDate.startsWith(selectedDate) || itemDateDisplay == selectedDate) {
                    items.add(item)
                }
            }

            // Sort
            items.sortWith(Comparator { a, b ->
                val aAllDay = a.optBoolean("isAllDay", false)
                val bAllDay = b.optBoolean("isAllDay", false)
                if (aAllDay && !bAllDay) return@Comparator -1
                if (!aAllDay && bAllDay) return@Comparator 1

                val aTime = a.optString("timeDisplay", "00:00")
                val bTime = b.optString("timeDisplay", "00:00")
                aTime.compareTo(bTime)
            })
        } catch (_: Exception) {
            items.clear()
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today_agenda_item)
        if (position < 0 || position >= items.size) return views

        try {
            val item = items[position]
            val type = item.optString("type", "task")
            val id = item.optString("id", "")
            val title = item.optString("title", "Untitled")
            val isCompleted = item.optBoolean("isCompleted", false)
            val timeDisplay = item.optString("timeDisplay", "")
            val subtitle = item.optString("subtitle", "")
            val priority = item.optString("priority", "")
            val colorHex = item.optString("category_color", "")

            val textColor = when (widgetTheme) {
                "light" -> Color.parseColor("#0F172A")
                else -> Color.parseColor("#FFFFFF")
            }
            val secondaryColor = when (widgetTheme) {
                "light" -> Color.parseColor("#64748B")
                else -> Color.parseColor("#94A3B8")
            }

            views.setTextViewText(R.id.widget_agenda_title, title)
            views.setTextColor(R.id.widget_agenda_title, textColor)
            views.setTextViewText(R.id.widget_agenda_time, timeDisplay)
            views.setTextColor(R.id.widget_agenda_time, secondaryColor)
            views.setTextViewText(R.id.widget_agenda_subtitle, subtitle)
            views.setTextColor(R.id.widget_agenda_subtitle, secondaryColor)

            if (colorHex.isNotEmpty() && colorHex.startsWith("#")) {
                try {
                    val color = Color.parseColor(colorHex)
                    views.setInt(R.id.widget_agenda_color_strip, "setBackgroundColor", color)
                    views.setViewVisibility(R.id.widget_agenda_color_strip, View.VISIBLE)
                } catch (_: Exception) {
                    views.setInt(R.id.widget_agenda_color_strip, "setBackgroundColor", highlightColor)
                    views.setViewVisibility(R.id.widget_agenda_color_strip, View.VISIBLE)
                }
            } else {
                views.setInt(R.id.widget_agenda_color_strip, "setBackgroundColor", highlightColor)
                views.setViewVisibility(R.id.widget_agenda_color_strip, View.VISIBLE)
            }

            if (type == "task") {
                views.setViewVisibility(R.id.widget_agenda_check, View.VISIBLE)
                views.setViewVisibility(R.id.widget_agenda_event_icon, View.GONE)

                if (isCompleted) {
                    views.setImageViewResource(R.id.widget_agenda_check, R.drawable.ic_check_circle_filled)
                } else {
                    views.setImageViewResource(R.id.widget_agenda_check, R.drawable.ic_circle_outline)
                }

                // Checkbox direct task completion fill-in intent
                if (id.isNotEmpty()) {
                    val checkIntent = Intent().apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("rocistasks://complete?id=$id")
                    }
                    views.setOnClickFillInIntent(R.id.widget_agenda_check, checkIntent)
                }

                if (priority.equals("high", ignoreCase = true)) {
                    views.setTextViewText(R.id.widget_agenda_badge, "HIGH")
                    views.setTextColor(R.id.widget_agenda_badge, Color.parseColor("#FF5252"))
                    views.setViewVisibility(R.id.widget_agenda_badge, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_agenda_badge, View.GONE)
                }

                val rowIntent = Intent().apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("rocistasks://task_item?id=$id")
                }
                views.setOnClickFillInIntent(R.id.widget_agenda_item_root, rowIntent)
            } else {
                views.setViewVisibility(R.id.widget_agenda_check, View.GONE)
                views.setViewVisibility(R.id.widget_agenda_event_icon, View.VISIBLE)
                views.setInt(R.id.widget_agenda_event_icon, "setColorFilter", highlightColor)
                views.setViewVisibility(R.id.widget_agenda_badge, View.GONE)

                val rowIntent = Intent().apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("rocistasks://calendar")
                }
                views.setOnClickFillInIntent(R.id.widget_agenda_item_root, rowIntent)
            }
        } catch (_: Exception) {}

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
