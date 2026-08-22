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

class TimelineAgendaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TimelineAgendaWidgetFactory(this.applicationContext)
    }
}

class TimelineAgendaWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
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

            val rawJson = widgetData.getString("timeline_agenda_data", "[]") ?: "[]"
            val jsonArray = JSONArray(rawJson)

            for (i in 0 until jsonArray.length()) {
                val obj = jsonArray.optJSONObject(i) ?: continue
                items.add(obj)
            }
        } catch (_: Exception) {
            items.clear()
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= items.size) {
            return RemoteViews(context.packageName, R.layout.widget_timeline_header_item)
        }

        val item = items[position]
        val isHeader = item.optBoolean("isHeader", false)

        val textColor = when (widgetTheme) {
            "light" -> Color.parseColor("#0F172A")
            else -> Color.parseColor("#FFFFFF")
        }
        val secondaryColor = when (widgetTheme) {
            "light" -> Color.parseColor("#64748B")
            else -> Color.parseColor("#94A3B8")
        }

        if (isHeader) {
            val views = RemoteViews(context.packageName, R.layout.widget_timeline_header_item)
            val dayLabel = item.optString("dayLabel", "")
            val dateDisplay = item.optString("dateDisplay", "")

            views.setTextViewText(R.id.widget_timeline_header_day, dayLabel)
            views.setTextViewText(R.id.widget_timeline_header_date, dateDisplay)
            views.setTextColor(R.id.widget_timeline_header_date, secondaryColor)
            return views
        } else {
            val views = RemoteViews(context.packageName, R.layout.widget_timeline_event_item)
            val type = item.optString("type", "task")
            val id = item.optString("id", "")
            val title = item.optString("title", "Untitled")
            val isCompleted = item.optBoolean("isCompleted", false)
            val timeDisplay = item.optString("timeDisplay", "")
            val subtitle = item.optString("subtitle", "")
            val priority = item.optString("priority", "")
            val colorHex = item.optString("category_color", "")

            views.setTextViewText(R.id.widget_timeline_title, title)
            views.setTextColor(R.id.widget_timeline_title, textColor)
            views.setTextViewText(R.id.widget_timeline_time, timeDisplay)
            views.setTextColor(R.id.widget_timeline_time, secondaryColor)
            views.setTextViewText(R.id.widget_timeline_subtitle, subtitle)
            views.setTextColor(R.id.widget_timeline_subtitle, secondaryColor)

            if (colorHex.isNotEmpty() && colorHex.startsWith("#")) {
                try {
                    val color = Color.parseColor(colorHex)
                    views.setInt(R.id.widget_timeline_color_strip, "setBackgroundColor", color)
                    views.setViewVisibility(R.id.widget_timeline_color_strip, View.VISIBLE)
                } catch (_: Exception) {
                    views.setViewVisibility(R.id.widget_timeline_color_strip, View.INVISIBLE)
                }
            } else {
                views.setViewVisibility(R.id.widget_timeline_color_strip, View.INVISIBLE)
            }

            if (type == "task") {
                views.setViewVisibility(R.id.widget_timeline_check, View.VISIBLE)
                views.setViewVisibility(R.id.widget_timeline_event_icon, View.GONE)

                if (isCompleted) {
                    views.setImageViewResource(R.id.widget_timeline_check, R.drawable.ic_check_circle_filled)
                } else {
                    views.setImageViewResource(R.id.widget_timeline_check, R.drawable.ic_circle_outline)
                }

                // Checkbox direct task completion fill-in intent
                if (id.isNotEmpty()) {
                    val checkIntent = Intent().apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("rocistasks://complete?id=$id")
                    }
                    views.setOnClickFillInIntent(R.id.widget_timeline_check, checkIntent)
                }

                if (priority.equals("high", ignoreCase = true)) {
                    views.setTextViewText(R.id.widget_timeline_badge, "HIGH")
                    views.setTextColor(R.id.widget_timeline_badge, Color.parseColor("#FF5252"))
                    views.setViewVisibility(R.id.widget_timeline_badge, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_timeline_badge, View.GONE)
                }

                val rowIntent = Intent().apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("rocistasks://task_item?id=$id")
                }
                views.setOnClickFillInIntent(R.id.widget_timeline_item_root, rowIntent)
            } else {
                views.setViewVisibility(R.id.widget_timeline_check, View.GONE)
                views.setViewVisibility(R.id.widget_timeline_event_icon, View.VISIBLE)
                views.setViewVisibility(R.id.widget_timeline_badge, View.GONE)

                val rowIntent = Intent().apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("rocistasks://calendar")
                }
                views.setOnClickFillInIntent(R.id.widget_timeline_item_root, rowIntent)
            }

            return views
        }
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 2
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
