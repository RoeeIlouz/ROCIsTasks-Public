package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class MonthWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return MonthWidgetFactory(this.applicationContext)
    }
}

class MonthWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var days = ArrayList<JSONObject>()

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        days.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val gridJson = widgetData.getString("month_grid_data", "[]")
            val jsonArray = JSONArray(gridJson)
            for (i in 0 until jsonArray.length()) {
                days.add(jsonArray.getJSONObject(i))
            }
        } catch (e: Exception) {
        }
    }

    override fun onDestroy() {
        days.clear()
    }

    override fun getCount(): Int = days.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position >= days.size) return RemoteViews(context.packageName, R.layout.widget_month_day_item)

        val views = RemoteViews(context.packageName, R.layout.widget_month_day_item)
        try {
            val day = days[position]
            val isWeekNumber = day.optBoolean("isWeekNumber", false)

            if (isWeekNumber) {
                views.setTextViewText(R.id.widget_day_text, "W${day.optInt("weekNumber")}")
                views.setViewVisibility(R.id.widget_summaries_container, android.view.View.GONE)
                views.setInt(R.id.widget_day_container, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
                views.setViewVisibility(R.id.widget_today_indicator, android.view.View.GONE)
            } else {
                val dayNum = day.optInt("day")
                val isToday = day.optBoolean("isToday", false)
                val isCurrentMonth = day.optBoolean("isCurrentMonth", true)
                val summaries = day.optJSONArray("summaries")

                views.setTextViewText(R.id.widget_day_text, dayNum.toString())
                
                // Style based on current month
                if (!isCurrentMonth) {
                    views.setTextColor(R.id.widget_day_text, android.graphics.Color.LTGRAY)
                } else {
                    views.setTextColor(R.id.widget_day_text, context.getColor(R.color.widget_title_text))
                }

                // Today Highlight
                if (isToday) {
                    views.setViewVisibility(R.id.widget_today_indicator, android.view.View.VISIBLE)
                    views.setTextColor(R.id.widget_day_text, android.graphics.Color.WHITE)
                } else {
                    views.setViewVisibility(R.id.widget_today_indicator, android.view.View.GONE)
                }

                // Summaries
                views.setViewVisibility(R.id.widget_summaries_container, android.view.View.VISIBLE)
                views.setViewVisibility(R.id.widget_summary_1, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_summary_2, android.view.View.GONE)
                views.setViewVisibility(R.id.widget_summary_3, android.view.View.GONE)

                if (summaries != null) {
                    for (i in 0 until summaries.length()) {
                        if (i >= 3) break
                        val summary = summaries.getJSONObject(i)
                        val text = summary.optString("text", "")
                        val colorHex = summary.optString("color", "")
                        
                        val summaryId = when (i) {
                            0 -> R.id.widget_summary_1
                            1 -> R.id.widget_summary_2
                            else -> R.id.widget_summary_3
                        }
                        
                        views.setViewVisibility(summaryId, android.view.View.VISIBLE)
                        views.setTextViewText(summaryId, text)
                        if (colorHex.isNotEmpty()) {
                            try {
                                views.setTextColor(summaryId, android.graphics.Color.parseColor(colorHex))
                            } catch (e: Exception) {}
                        }
                    }
                }

                // Fill-in Intent
                val dateStr = day.optString("date", "")
                val fillInIntent = Intent().apply {
                    data = Uri.parse("rocistasks://month_day?date=$dateStr")
                }
                views.setOnClickFillInIntent(R.id.widget_day_container, fillInIntent)
            }

        } catch (e: Exception) {
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
