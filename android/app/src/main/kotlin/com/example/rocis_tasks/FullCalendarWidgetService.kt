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
    private var showTasks = true
    private var showGoogle = true
    private var showRocis = true

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        android.util.Log.d("FullCalendarWidget", "onDataSetChanged started")
        days.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            
            // Read filter settings
            showTasks = widgetData.getBoolean(FullCalendarWidgetProvider.PREF_SHOW_TASKS, true)
            showGoogle = widgetData.getBoolean(FullCalendarWidgetProvider.PREF_SHOW_GOOGLE, true)
            showRocis = widgetData.getBoolean(FullCalendarWidgetProvider.PREF_SHOW_ROCIS, true)
            android.util.Log.d("FullCalendarWidget", "Filter settings - Tasks: $showTasks, Google: $showGoogle, ROCIs: $showRocis")
            
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
                                "schedule", "schedule_event", "assignment" -> showRocis
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
            android.util.Log.d("FullCalendarWidget", "Parsed ${days.size} grid days with filtering applied")
        } catch (e: Exception) {
            android.util.Log.e("FullCalendarWidget", "Error loading grid data", e)
        }
    }

    override fun onDestroy() {
        days.clear()
    }

    override fun getCount(): Int {
        val count = days.size / 8
        android.util.Log.d("FullCalendarWidget", "=== getCount returning rows: $count ===")
        return count
    }

    override fun getViewAt(position: Int): RemoteViews {
        android.util.Log.d("FullCalendarWidget", "=== getViewAt called for row: $position ===")
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
                    val isToday = day.optBoolean("isToday", false)
                    val isCurrentMonth = day.optBoolean("isCurrentMonth", true)
                    val date = day.optString("date", "")

                    cellViews.setTextViewText(R.id.widget_full_calendar_day_text, dayNum.toString())
                    cellViews.setViewVisibility(R.id.widget_full_calendar_today_indicator, if (isToday) android.view.View.VISIBLE else android.view.View.GONE)
                    
                    val textColor = if (isToday) {
                        android.graphics.Color.WHITE
                    } else if (isCurrentMonth) {
                        context.getColor(R.color.widget_title_text)
                    } else {
                        context.getColor(R.color.widget_secondary_text)
                    }
                    cellViews.setTextColor(R.id.widget_full_calendar_day_text, textColor)

                    // Summaries (event/task titles)
                    val summaries = day.optJSONArray("summaries") ?: JSONArray()
                    
                    // Reset visibility
                    cellViews.setViewVisibility(R.id.widget_full_calendar_summary_1, android.view.View.GONE)
                    cellViews.setViewVisibility(R.id.widget_full_calendar_summary_2, android.view.View.GONE)
                    cellViews.setViewVisibility(R.id.widget_full_calendar_summary_3, android.view.View.GONE)
                    
                    // Populate up to 3 summaries
                    for (j in 0 until minOf(3, summaries.length())) {
                        val summary = summaries.getJSONObject(j)
                        var title = summary.optString("text", "")
                        val time = summary.optString("time", "")
                        val subtitle = summary.optString("subtitle", "")
                        val priority = summary.optString("priority", "")
                        val colorHex = summary.optString("color", "")
                        val type = summary.optString("type", "")

                        // Enhance title with details (Priority only, no time)
                        var displayTitle = title
                        if (priority.isNotEmpty()) {
                            val prioritySymbol = when (priority.lowercase()) {
                                "high" -> "!!!"
                                "medium" -> "!!"
                                "low" -> "!"
                                else -> ""
                            }
                            displayTitle = "$prioritySymbol $displayTitle"
                        }
                        
                        val viewId = when(j) {
                            0 -> R.id.widget_full_calendar_summary_1
                            1 -> R.id.widget_full_calendar_summary_2
                            else -> R.id.widget_full_calendar_summary_3
                        }
                        
                        cellViews.setViewVisibility(viewId, android.view.View.VISIBLE)
                        cellViews.setTextViewText(viewId, displayTitle)
                        cellViews.setTextColor(viewId, android.graphics.Color.parseColor("#CCFFFFFF"))
                        cellViews.setTextViewTextSize(viewId, android.util.TypedValue.COMPLEX_UNIT_SP, 9f)
                        
                        if (colorHex.isNotEmpty()) {
                            try {
                                val color = android.graphics.Color.parseColor(colorHex)
                                // Apply some alpha to the background color (60% = 0x99)
                                val alphaColor = (color and 0x00FFFFFF) or (0x99 shl 24)
                                cellViews.setInt(viewId, "setBackgroundColor", alphaColor)
                            } catch (e: Exception) {}
                        }
                    }

                    // Click Intent to open app to specific date
                    if (date.isNotEmpty()) {
                        val fillInIntent = Intent().apply {
                            action = Intent.ACTION_VIEW
                            // Use host-only deep link to avoid GoRouter "route not found" errors.
                            // The app handles host-based widget links and navigates to the calendar tab.
                            data = Uri.parse("rocistasks://calendar")
                        }
                        cellViews.setOnClickFillInIntent(R.id.widget_full_calendar_day_container, fillInIntent)
                        android.util.Log.d("FullCalendarWidget", "Set fill-in intent for date: $date with URI: rocistasks://calendar")
                    }
                }
                rowViews.addView(R.id.widget_full_calendar_row_container, cellViews)
            }
        } catch (e: Exception) {
            android.util.Log.e("FullCalendarWidget", "Error in getViewAt rows", e)
        }

        return rowViews
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
