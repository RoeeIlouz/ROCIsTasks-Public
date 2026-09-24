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

class TodayAgendaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TodayAgendaWidgetFactory(this.applicationContext)
    }
}

class TodayAgendaWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val items = ArrayList<JSONObject>()
    private var palette: FullCalendarWidgetUtils.Palette? = null
    private var locale: Locale = Locale.getDefault()

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            palette = WidgetStyle.palette(context, widgetData)
            locale = WidgetLocaleHelper.getWidgetLocale(widgetData)

            val offset = widgetData.getInt(TodayAgendaWidgetProvider.PREF_TODAY_OFFSET, 0)
            val cal = Calendar.getInstance()
            if (offset != 0) cal.add(Calendar.DAY_OF_YEAR, offset)
            val targetDateStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)

            val jsonArray = JSONArray(widgetData.getString("today_agenda_data", "[]") ?: "[]")
            val dayItems = mutableListOf<JSONObject>()
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.optJSONObject(i) ?: continue
                val day = item.optString("dateOnly", "").ifEmpty { item.optString("dateDisplay", "") }
                if (day == targetDateStr) dayItems.add(item)
            }

            // All-day first, then by start time (sortMinutes; timeDisplay for older data).
            dayItems.sortWith(compareBy<JSONObject>(
                { if (it.has("sortMinutes")) it.optInt("sortMinutes") else if (it.optBoolean("isAllDay")) -1 else 0 },
                { it.optString("timeDisplay") }
            ))

            items.clear()
            items.addAll(dayItems)
        } catch (_: Exception) {
            // Keep existing items on error
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_today_agenda_item)
        if (position < 0 || position >= items.size) return views
        val palette = palette ?: return views

        try {
            val item = items[position]
            val type = item.optString("type", "task")
            val id = item.optString("id", "")
            val subtitle = item.optString("subtitle", "")
            val timeDisplay = item.optString("timeDisplay", "")
            val accent = WidgetStyle.parseColor(item.optString("category_color", ""), palette.primary)

            // Tile: a faint onSurface wash on the card, like the app's list tiles.
            WidgetStyle.applyTile(views, R.id.widget_agenda_item_fill, palette.onSurface, if (palette.isDark) 0x14 else 0x0D)
            views.setInt(R.id.widget_agenda_color_strip, "setColorFilter", accent)

            views.setTextViewText(R.id.widget_agenda_title, item.optString("title", ""))
            views.setTextColor(R.id.widget_agenda_title, palette.onSurface)
            views.setTextViewText(R.id.widget_agenda_time, timeDisplay)
            views.setTextColor(R.id.widget_agenda_time, palette.primary)
            views.setViewVisibility(R.id.widget_agenda_time, if (timeDisplay.isEmpty()) View.GONE else View.VISIBLE)
            // For events the subtitle repeats the time when there is no location.
            val meta = if (subtitle == timeDisplay) "" else subtitle
            views.setTextViewText(R.id.widget_agenda_subtitle, meta)
            views.setTextColor(R.id.widget_agenda_subtitle, palette.onSurfaceMuted)

            if (type == "task") {
                views.setViewVisibility(R.id.widget_agenda_check, View.VISIBLE)
                views.setViewVisibility(R.id.widget_agenda_event_icon, View.GONE)
                val done = item.optBoolean("isCompleted", false)
                views.setImageViewResource(
                    R.id.widget_agenda_check,
                    if (done) R.drawable.ic_widget_check_on else R.drawable.ic_widget_check_off
                )
                views.setInt(R.id.widget_agenda_check, "setColorFilter", if (done) palette.primary else palette.onSurfaceMuted)
                if (id.isNotEmpty()) {
                    views.setOnClickFillInIntent(
                        R.id.widget_agenda_check,
                        Intent().apply { data = Uri.parse("rocistasks://complete?id=$id") }
                    )
                }

                val priority = item.optString("priority", "")
                val priorityColor = WidgetStyle.priorityColor(priority)
                // Low priority is the default; only flag medium and high like the app.
                if (priorityColor != null && !priority.equals("low", ignoreCase = true)) {
                    views.setViewVisibility(R.id.widget_agenda_badge_box, View.VISIBLE)
                    views.setTextViewText(R.id.widget_agenda_badge, WidgetStyle.priorityLabel(priority, locale))
                    views.setTextColor(R.id.widget_agenda_badge, priorityColor)
                    WidgetStyle.applyTile(views, R.id.widget_agenda_badge_fill, priorityColor, 0x26)
                } else {
                    views.setViewVisibility(R.id.widget_agenda_badge_box, View.GONE)
                }

                views.setOnClickFillInIntent(
                    R.id.widget_agenda_item_root,
                    Intent().apply { data = Uri.parse("rocistasks://task_item?id=$id") }
                )
            } else {
                views.setViewVisibility(R.id.widget_agenda_check, View.GONE)
                views.setViewVisibility(R.id.widget_agenda_event_icon, View.VISIBLE)
                views.setInt(R.id.widget_agenda_event_icon, "setColorFilter", accent)
                views.setViewVisibility(R.id.widget_agenda_badge_box, View.GONE)

                // Events open the in-app calendar on their day.
                val day = item.optString("dateOnly", "").ifEmpty { item.optString("dateDisplay", "") }
                views.setOnClickFillInIntent(
                    R.id.widget_agenda_item_root,
                    Intent().apply { data = Uri.parse("rocistasks://calendar?date=$day") }
                )
            }
        } catch (_: Exception) {}

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
