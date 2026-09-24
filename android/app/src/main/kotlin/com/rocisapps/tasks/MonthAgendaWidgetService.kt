package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.net.Uri
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

/** Serves the selected day's tasks and events to the Month Agenda list. */
class MonthAgendaWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MonthAgendaListFactory(this.applicationContext)
    }
}

class MonthAgendaListFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
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
            val selectedDate = MonthAgendaWidgetProvider.selectedDate(widgetData)

            val jsonArray = JSONArray(widgetData.getString("today_agenda_data", "[]") ?: "[]")
            val dayItems = mutableListOf<JSONObject>()
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.optJSONObject(i) ?: continue
                if (MonthAgendaWidgetProvider.dayOf(item) == selectedDate) dayItems.add(item)
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
        val views = RemoteViews(context.packageName, R.layout.widget_month_agenda_day_item)
        if (position < 0 || position >= items.size) return views
        val palette = palette ?: return views

        try {
            val item = items[position]
            val type = item.optString("type", "task")
            val id = item.optString("id", "")
            val subtitle = item.optString("subtitle", "")
            val timeDisplay = item.optString("timeDisplay", "")
            val accent = WidgetStyle.parseColor(item.optString("category_color", ""), palette.primary)

            WidgetStyle.applyDirection(views, R.id.widget_month_item_root, locale)
            WidgetStyle.applyTile(views, R.id.widget_month_item_fill, palette.onSurface, if (palette.isDark) 0x14 else 0x0D)
            views.setInt(R.id.widget_month_item_bar, "setColorFilter", accent)

            views.setTextViewText(R.id.widget_month_item_title, item.optString("title", ""))
            views.setTextColor(R.id.widget_month_item_title, palette.onSurface)
            views.setTextViewText(R.id.widget_month_item_time, timeDisplay)
            views.setTextColor(R.id.widget_month_item_time, palette.primary)
            views.setViewVisibility(R.id.widget_month_item_time, if (timeDisplay.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextColor(R.id.widget_month_item_meta, palette.onSurfaceMuted)

            // Meta line: priority label (tasks), then category / location.
            val meta = SpannableStringBuilder()
            if (type == "task") {
                val priority = item.optString("priority", "")
                val priorityColor = WidgetStyle.priorityColor(priority)
                // Low priority is the default; only flag medium and high like the app.
                if (priorityColor != null && !priority.equals("low", ignoreCase = true)) {
                    val label = WidgetStyle.priorityLabel(priority, locale) ?: ""
                    meta.append(label)
                    meta.setSpan(ForegroundColorSpan(priorityColor), 0, label.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    meta.setSpan(StyleSpan(Typeface.BOLD), 0, label.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                }
            }
            // For events the subtitle repeats the time when there is no location.
            if (subtitle.isNotEmpty() && subtitle != timeDisplay) {
                if (meta.isNotEmpty()) meta.append(" · ")
                meta.append(subtitle)
            }
            views.setTextViewText(R.id.widget_month_item_meta, meta)
            views.setViewVisibility(R.id.widget_month_item_meta, if (meta.isEmpty()) View.GONE else View.VISIBLE)

            if (type == "task") {
                views.setViewVisibility(R.id.widget_month_item_check, View.VISIBLE)
                views.setViewVisibility(R.id.widget_month_item_event_icon, View.GONE)
                val done = item.optBoolean("isCompleted", false)
                views.setImageViewResource(
                    R.id.widget_month_item_check,
                    if (done) R.drawable.ic_widget_check_on else R.drawable.ic_widget_check_off
                )
                views.setInt(R.id.widget_month_item_check, "setColorFilter", if (done) palette.primary else palette.onSurfaceMuted)
                if (id.isNotEmpty()) {
                    views.setOnClickFillInIntent(
                        R.id.widget_month_item_check,
                        Intent().apply { data = Uri.parse("rocistasks://complete?id=$id") }
                    )
                }
                views.setOnClickFillInIntent(
                    R.id.widget_month_item_root,
                    Intent().apply { data = Uri.parse("rocistasks://task_item?id=$id") }
                )
            } else {
                views.setViewVisibility(R.id.widget_month_item_check, View.GONE)
                views.setViewVisibility(R.id.widget_month_item_event_icon, View.VISIBLE)
                views.setInt(R.id.widget_month_item_event_icon, "setColorFilter", accent)

                // Events open the in-app calendar on their day.
                views.setOnClickFillInIntent(
                    R.id.widget_month_item_root,
                    Intent().apply { data = Uri.parse("rocistasks://calendar?date=${MonthAgendaWidgetProvider.dayOf(item)}") }
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
