package com.rocisapps.tasks

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
    private var showTasks = true
    private var showGoogle = true

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        days.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            
            // Read filter settings
            showTasks = widgetData.getBoolean(FullCalendarWidgetProvider.PREF_SHOW_TASKS, true)
            showGoogle = widgetData.getBoolean(FullCalendarWidgetProvider.PREF_SHOW_GOOGLE, true)
            
            val gridDataJson = widgetData.getString("full_calendar_grid_data", "[]")
            val gridData = JSONArray(gridDataJson)
            for (i in 0 until gridData.length()) {
                val day = gridData.getJSONObject(i)
                
                // Filter summaries based on filter settings
                if (!day.optBoolean("isWeekNumber", false)) {
                    val summaries = day.optJSONArray("summaries")
                    if (summaries != null) {
                        val filteredSummaries = JSONArray()
                        for (j in 0 until summaries.length()) {
                            val summary = summaries.getJSONObject(j)
                            val type = summary.optString("type", "")
                            
                            val shouldInclude = when (type) {
                                "task" -> showTasks
                                "google" -> showGoogle
                                else -> true // Include unknown types
                            }
                            
                            if (shouldInclude) {
                                filteredSummaries.put(summary)
                            }
                        }
                        // Replace summaries with filtered version
                        day.put("summaries", filteredSummaries)
                    }
                }
                
                days.add(day)
            }
        } catch (e: Exception) {
            android.util.Log.e("FullCalendarWidget", "Error parsing widget data", e)
        }
    }

    override fun onDestroy() {
        days.clear()
    }

    override fun getCount(): Int {
        val count = days.size / 8
        return count
    }

    override fun getViewAt(position: Int): RemoteViews {
        val rowViews = RemoteViews(context.packageName, R.layout.widget_full_calendar_row)
        try {
            rowViews.removeAllViews(R.id.widget_full_calendar_row_container)

            val startIndex = position * 8
            for (i in 0 until 8) {
                val cellIndex = startIndex + i
                if (cellIndex >= days.size) break

                val day = days[cellIndex]
                val isWeekNumber = day.optBoolean("isWeekNumber", false)

                val cellViews: RemoteViews
                if (isWeekNumber) {
                    cellViews = RemoteViews(context.packageName, R.layout.widget_full_calendar_week_num_item)
                    val weekNum = day.optInt("weekNumber", 0)
                    cellViews.setTextViewText(R.id.widget_full_calendar_day_text, weekNum.toString())
                 } else {
                     cellViews = RemoteViews(context.packageName, R.layout.widget_full_calendar_day_item)
                     val dayNum = day.optInt("day", 1)
                     val dateStr = day.optString("date", "")
                     val isCurrentMonth = day.optBoolean("isCurrentMonth", true)
                     
                     // Dynamically calculate isToday to ensure it's accurate even if data is cached
                     val today = java.util.Calendar.getInstance()
                     val currentTodayStr = String.format("%04d-%02d-%02d", 
                         today.get(java.util.Calendar.YEAR),
                         today.get(java.util.Calendar.MONTH) + 1,
                         today.get(java.util.Calendar.DAY_OF_MONTH))
                     
                     val isToday = dateStr == currentTodayStr

                     var dayOfWeek = 0
                     try {
                         val dateObj = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).parse(dateStr)
                         if (dateObj != null) {
                             val cal = java.util.Calendar.getInstance()
                             cal.time = dateObj
                             dayOfWeek = cal.get(java.util.Calendar.DAY_OF_WEEK)
                         }
                     } catch (e: Exception) {}

                     cellViews.setTextViewText(R.id.widget_full_calendar_day_text, dayNum.toString())
                     
                     if (isToday) {
                         cellViews.setInt(R.id.widget_full_calendar_day_text, "setBackgroundResource", R.drawable.widget_today_background)
                     } else {
                         cellViews.setInt(R.id.widget_full_calendar_day_text, "setBackgroundResource", 0) // Transparent
                     }
                     
                     val textColor = if (isToday) {
                         android.graphics.Color.WHITE
                     } else if (isCurrentMonth) {
                         when (dayOfWeek) {
                             java.util.Calendar.SUNDAY -> android.graphics.Color.parseColor("#FF5252")
                             java.util.Calendar.SATURDAY -> android.graphics.Color.parseColor("#448AFF")
                             else -> context.getColor(R.color.widget_title_text)
                         }
                     } else {
                         context.getColor(R.color.widget_secondary_text)
                     }
                     cellViews.setTextColor(R.id.widget_full_calendar_day_text, textColor)

                    // Summaries (event/task indicators)
                    val summaries = day.optJSONArray("summaries") ?: JSONArray()
                    val count = summaries.length()
                    
                    // Reset visibility
                    cellViews.setViewVisibility(R.id.widget_full_calendar_day_title, android.view.View.GONE)
                    cellViews.setViewVisibility(R.id.widget_full_calendar_indicators_container, android.view.View.GONE)
                    cellViews.setViewVisibility(R.id.widget_full_calendar_summary_1, android.view.View.GONE)
                    cellViews.setViewVisibility(R.id.widget_full_calendar_summary_2, android.view.View.GONE)
                    cellViews.setViewVisibility(R.id.widget_full_calendar_summary_3, android.view.View.GONE)
                    
                    if (count == 1) {
                        val summary = summaries.getJSONObject(0)
                        val title = summary.optString("text", "")
                        val colorHex = summary.optString("color", "")

                        cellViews.setViewVisibility(R.id.widget_full_calendar_day_title, android.view.View.VISIBLE)
                        cellViews.setTextViewText(R.id.widget_full_calendar_day_title, title)

                        if (colorHex.isNotEmpty()) {
                            try {
                                val color = android.graphics.Color.parseColor(colorHex)
                                cellViews.setTextColor(R.id.widget_full_calendar_day_title, color)
                            } catch (e: Exception) {}
                        }
                    } else if (count > 1) {
                        cellViews.setViewVisibility(R.id.widget_full_calendar_indicators_container, android.view.View.VISIBLE)
                        for (j in 0 until minOf(3, count)) {
                            val summary = summaries.getJSONObject(j)
                            val colorHex = summary.optString("color", "")

                            val viewId = when(j) {
                                0 -> R.id.widget_full_calendar_summary_1
                                1 -> R.id.widget_full_calendar_summary_2
                                else -> R.id.widget_full_calendar_summary_3
                            }
                            
                            cellViews.setViewVisibility(viewId, android.view.View.VISIBLE)
                            
                            if (colorHex.isNotEmpty()) {
                                try {
                                    val color = android.graphics.Color.parseColor(colorHex)
                                    val alphaColor = (color and 0x00FFFFFF) or (0xFF shl 24)
                                    cellViews.setInt(viewId, "setColorFilter", alphaColor)
                                } catch (e: Exception) {}
                            }
                        }
                    }

                     // Click Intent to open app to specific date
                     if (dateStr.isNotEmpty()) {
                         val fillInIntent = Intent().apply {
                             action = Intent.ACTION_VIEW
                             // Use host-only deep link to avoid GoRouter "route not found" errors.
                             // The app handles host-based widget links and navigates to the calendar tab.
                             data = Uri.parse("rocistasks://calendar")
                         }
                         cellViews.setOnClickFillInIntent(R.id.widget_full_calendar_day_container, fillInIntent)
                     }
                }
                rowViews.addView(R.id.widget_full_calendar_row_container, cellViews)
            }
        } catch (e: Exception) {
        }

        return rowViews
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
