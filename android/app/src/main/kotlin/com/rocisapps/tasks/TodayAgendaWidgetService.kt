package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
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

class TodayAgendaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TodayAgendaWidgetFactory(this.applicationContext)
    }
}

class TodayAgendaWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
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
            val offset = widgetData.getInt(TodayAgendaWidgetProvider.PREF_TODAY_OFFSET, 0)

            val cal = Calendar.getInstance()
            if (offset != 0) {
                cal.add(Calendar.DAY_OF_YEAR, offset)
            }
            val targetDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)

            val rawJson = widgetData.getString("today_agenda_data", "[]") ?: "[]"
            val jsonArray = JSONArray(rawJson)

            val dayItems = mutableListOf<JSONObject>()
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.optJSONObject(i) ?: continue
                val itemDate = item.optString("date", "")
                if (itemDate.startsWith(targetDateStr)) {
                    dayItems.add(item)
                }
            }

            // Sort: All-day items first, then by time
            dayItems.sortWith(Comparator { a, b ->
                val aAllDay = a.optBoolean("isAllDay", false)
                val bAllDay = b.optBoolean("isAllDay", false)
                if (aAllDay && !bAllDay) return@Comparator -1
                if (!aAllDay && bAllDay) return@Comparator 1

                val aTime = a.optString("timeDisplay", "00:00")
                val bTime = b.optString("timeDisplay", "00:00")
                aTime.compareTo(bTime)
            })

            items.addAll(dayItems)
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

            // Text colors based on theme
            val textColor = when (widgetTheme) {
                "light" -> Color.parseColor("#1C1C1E")
                "dark", "glassmorphic" -> Color.parseColor("#FFFFFF")
                else -> Color.parseColor("#1C1C1E")
            }
            val secondaryColor = when (widgetTheme) {
                "light" -> Color.parseColor("#8E8E93")
                "dark", "glassmorphic" -> Color.parseColor("#AEAEB2")
                else -> Color.parseColor("#8E8E93")
            }

            views.setTextViewText(R.id.widget_agenda_title, title)
            views.setTextColor(R.id.widget_agenda_title, textColor)
            views.setTextViewText(R.id.widget_agenda_time, timeDisplay)
            views.setTextColor(R.id.widget_agenda_time, secondaryColor)
            views.setTextViewText(R.id.widget_agenda_subtitle, subtitle)
            views.setTextColor(R.id.widget_agenda_subtitle, secondaryColor)

            // Color Strip
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

            // Task vs Event handling
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

                // Priority Badge
                if (priority.equals("high", ignoreCase = true)) {
                    views.setTextViewText(R.id.widget_agenda_badge, "HIGH")
                    views.setTextColor(R.id.widget_agenda_badge, Color.parseColor("#FF5252"))
                    views.setViewVisibility(R.id.widget_agenda_badge, View.VISIBLE)
                } else if (priority.equals("medium", ignoreCase = true)) {
                    views.setTextViewText(R.id.widget_agenda_badge, "MED")
                    views.setTextColor(R.id.widget_agenda_badge, Color.parseColor("#FFAB40"))
                    views.setViewVisibility(R.id.widget_agenda_badge, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_agenda_badge, View.GONE)
                }

                // Row click intent (opens task in app)
                val rowIntent = Intent().apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("rocistasks://task_item?id=$id")
                }
                views.setOnClickFillInIntent(R.id.widget_agenda_item_root, rowIntent)
            } else {
                // Calendar Event
                views.setViewVisibility(R.id.widget_agenda_check, View.GONE)
                views.setViewVisibility(R.id.widget_agenda_event_icon, View.VISIBLE)
                views.setViewVisibility(R.id.widget_agenda_badge, View.GONE)

                if (colorHex.isNotEmpty() && colorHex.startsWith("#")) {
                    try {
                        val color = Color.parseColor(colorHex)
                        views.setInt(R.id.widget_agenda_event_icon, "setColorFilter", color)
                    } catch (_: Exception) {}
                }

                // Row click opens calendar in app
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
