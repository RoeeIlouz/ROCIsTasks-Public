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

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        days.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            widgetTheme = widgetData.getString("full_calendar_theme", "system") ?: "system"
            selectedDateStr = widgetData.getString(MonthAgendaWidgetProvider.PREF_SELECTED_DATE, "") ?: ""
            if (selectedDateStr.isEmpty()) {
                selectedDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
            }

            val rawGrid = widgetData.getString("month_agenda_grid_data", "[]") ?: "[]"
            val jsonArray = JSONArray(rawGrid)
            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.optJSONObject(i) ?: continue
                if (!obj.optBoolean("isWeekNumber", false)) {
                    days.add(obj)
                }
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
        rowViews.removeAllViews(R.id.widget_month_agenda_row_root)

        val startIndex = position * 7
        for (i in 0 until 7) {
            val cellIndex = startIndex + i
            if (cellIndex >= days.size) break

            val day = days[cellIndex]
            val cellViews = RemoteViews(context.packageName, R.layout.widget_month_agenda_day_item)

            val dayNum = day.optInt("day", 1)
            val dateStr = day.optString("date", "")
            val isCurrentMonth = day.optBoolean("isCurrentMonth", true)
            val isToday = day.optBoolean("isToday", false)
            val hasEvents = day.optBoolean("hasEvents", false)
            val isSelected = dateStr.isNotEmpty() && dateStr == selectedDateStr

            cellViews.setTextViewText(R.id.widget_month_day_text, dayNum.toString())

            // Text colors
            val textColor = when {
                !isCurrentMonth -> Color.parseColor("#60888888")
                isSelected || isToday -> Color.parseColor("#6C63FF")
                else -> when (widgetTheme) {
                    "light" -> Color.parseColor("#1C1C1E")
                    "dark", "glassmorphic" -> Color.parseColor("#FFFFFF")
                    else -> context.getColor(R.color.widget_title_text)
                }
            }
            cellViews.setTextColor(R.id.widget_month_day_text, textColor)

            if (isSelected) {
                cellViews.setViewVisibility(R.id.widget_month_day_bg, View.VISIBLE)
                cellViews.setInt(R.id.widget_month_day_bg, "setImageAlpha", 0x33)
            } else {
                cellViews.setViewVisibility(R.id.widget_month_day_bg, View.GONE)
            }

            if (hasEvents) {
                cellViews.setViewVisibility(R.id.widget_month_day_dot, View.VISIBLE)
            } else {
                cellViews.setViewVisibility(R.id.widget_month_day_dot, View.GONE)
            }

            // Fill-in broadcast intent to select this day
            if (dateStr.isNotEmpty()) {
                val fillIntent = Intent().apply {
                    putExtra("date", dateStr)
                }
                cellViews.setOnClickFillInIntent(R.id.widget_month_day_root, fillIntent)
            }

            rowViews.addView(R.id.widget_month_agenda_row_root, cellViews)
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

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        items.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            widgetTheme = widgetData.getString("full_calendar_theme", "system") ?: "system"
            var selectedDate = widgetData.getString(MonthAgendaWidgetProvider.PREF_SELECTED_DATE, "") ?: ""
            if (selectedDate.isEmpty()) {
                selectedDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
            }

            val rawJson = widgetData.getString("today_agenda_data", "[]") ?: "[]"
            val jsonArray = JSONArray(rawJson)

            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.optJSONObject(i) ?: continue
                val itemDate = item.optString("date", "")
                if (itemDate.startsWith(selectedDate)) {
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
                "light" -> Color.parseColor("#1C1C1E")
                "dark", "glassmorphic" -> Color.parseColor("#FFFFFF")
                else -> context.getColor(R.color.widget_title_text)
            }
            val secondaryColor = when (widgetTheme) {
                "light" -> Color.parseColor("#8E8E93")
                "dark", "glassmorphic" -> Color.parseColor("#AEAEB2")
                else -> context.getColor(R.color.widget_secondary_text)
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
                    views.setViewVisibility(R.id.widget_agenda_color_strip, View.INVISIBLE)
                }
            } else {
                views.setViewVisibility(R.id.widget_agenda_color_strip, View.INVISIBLE)
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
                views.setViewVisibility(R.id.widget_agenda_badge, View.GONE)

                if (colorHex.isNotEmpty() && colorHex.startsWith("#")) {
                    try {
                        val color = Color.parseColor(colorHex)
                        views.setInt(R.id.widget_agenda_event_icon, "setColorFilter", color)
                    } catch (_: Exception) {}
                }

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
