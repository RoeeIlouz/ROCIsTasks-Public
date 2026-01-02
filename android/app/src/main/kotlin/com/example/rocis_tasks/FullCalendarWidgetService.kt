package com.example.rocis_tasks

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class FullCalendarWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return FullCalendarWidgetFactory(this.applicationContext)
    }
}

class FullCalendarWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var days = ArrayList<JSONObject>()

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        android.util.Log.d("FullCalendarWidget", "onDataSetChanged started")
        days.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val gridDataJson = widgetData.getString("full_calendar_grid_data", "[]")
            val gridData = JSONArray(gridDataJson)
            for (i in 0 until gridData.length()) {
                days.add(gridData.getJSONObject(i))
            }
            android.util.Log.d("FullCalendarWidget", "Parsed ${days.size} grid days")
        } catch (e: Exception) {
            android.util.Log.e("FullCalendarWidget", "Error loading grid data", e)
        }
    }

    override fun onDestroy() {
        days.clear()
    }

    override fun getCount(): Int {
        val count = days.size
        android.util.Log.d("FullCalendarWidget", "=== getCount returning: $count ===")
        return count
    }

    override fun getViewAt(position: Int): RemoteViews {
        android.util.Log.d("FullCalendarWidget", "=== getViewAt called for position: $position ===")
        if (position < 0 || position >= days.size) {
            return RemoteViews(context.packageName, R.layout.widget_full_calendar_day_item)
        }

        val views = RemoteViews(context.packageName, R.layout.widget_full_calendar_day_item)
        try {
            val day = days[position]
            val isWeekNumber = day.optBoolean("isWeekNumber", false)

            if (isWeekNumber) {
                // Week number cell
                val weekNum = day.optInt("weekNumber", 0)
                views.setTextViewText(R.id.widget_full_calendar_day_text, weekNum.toString())
                views.setViewVisibility(R.id.widget_full_calendar_today_indicator, android.view.View.GONE)
                views.setTextColor(R.id.widget_full_calendar_day_text, context.getColor(R.color.widget_secondary_text))
                views.setTextViewTextSize(R.id.widget_full_calendar_day_text, android.util.TypedValue.COMPLEX_UNIT_SP, 8f)
                
                // Hide summaries
                views.setViewVisibility(R.id.widget_full_calendar_summary_1, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_full_calendar_summary_2, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_full_calendar_summary_3, android.view.View.GONE)
                
                // Make non-clickable
                views.setOnClickFillInIntent(R.id.widget_full_calendar_day_container, Intent())
            } else {
                // Regular day cell
                val dayNum = day.optInt("day", 1)
                val isToday = day.optBoolean("isToday", false)
                val isCurrentMonth = day.optBoolean("isCurrentMonth", true)
                val date = day.optString("date", "")

                views.setTextViewText(R.id.widget_full_calendar_day_text, dayNum.toString())
                views.setViewVisibility(R.id.widget_full_calendar_today_indicator, if (isToday) android.view.View.VISIBLE else android.view.View.GONE)
                views.setTextViewTextSize(R.id.widget_full_calendar_day_text, android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
                
                val textColor = if (isToday) {
                    android.graphics.Color.WHITE
                } else if (isCurrentMonth) {
                    context.getColor(R.color.widget_title_text)
                } else {
                    context.getColor(R.color.widget_secondary_text)
                }
                views.setTextColor(R.id.widget_full_calendar_day_text, textColor)

                // Summaries (event/task indicators)
                val summaries = day.optJSONArray("summaries") ?: JSONArray()
                
                // Reset visibility
                views.setViewVisibility(R.id.widget_full_calendar_summary_1, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_full_calendar_summary_2, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_full_calendar_summary_3, android.view.View.GONE)
                
                // Populate up to 3 summaries
                for (i in 0 until minOf(3, summaries.length())) {
                    val summary = summaries.getJSONObject(i)
                    val colorHex = summary.optString("color", "")
                    
                    val viewId = when(i) {
                        0 -> R.id.widget_full_calendar_summary_1
                        1 -> R.id.widget_full_calendar_summary_2
                        else -> R.id.widget_full_calendar_summary_3
                    }
                    
                    views.setViewVisibility(viewId, android.view.View.VISIBLE)
                    
                    if (colorHex.isNotEmpty()) {
                        try {
                            val color = android.graphics.Color.parseColor(colorHex)
                            views.setInt(viewId, "setBackgroundColor", color)
                        } catch (e: Exception) {}
                    }
                }

                // Click Intent to open app to specific date
                if (date.isNotEmpty()) {
                    val fillInIntent = Intent().apply {
                        data = Uri.parse("rocistasks://calendar/day/$date")
                    }
                    views.setOnClickFillInIntent(R.id.widget_full_calendar_day_container, fillInIntent)
                } else {
                    // Empty cell
                    views.setOnClickFillInIntent(R.id.widget_full_calendar_day_container, Intent())
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("FullCalendarWidget", "=== ERROR in getViewAt $position ===", e)
            // Reset views to safe state on error
            views.setTextViewText(R.id.widget_full_calendar_day_text, "!")
            views.setViewVisibility(R.id.widget_full_calendar_today_indicator, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_full_calendar_summary_1, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_full_calendar_summary_2, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_full_calendar_summary_3, android.view.View.GONE)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
