package com.example.rocis_tasks

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        android.util.Log.d("ScheduleWidget", "onGetViewFactory called")
        return ScheduleWidgetFactory(this.applicationContext)
    }
}

class ScheduleWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var items = ArrayList<JSONObject>()

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        android.util.Log.d("ScheduleWidget", "=== onDataSetChanged STARTED ===")
        items.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            val scheduleJson = widgetData.getString("schedule_list", "[]") ?: "[]"
            android.util.Log.d("ScheduleWidget", "scheduleJson length: ${scheduleJson.length}")
            
            val jsonArray = JSONArray(scheduleJson)
            for (i in 0 until jsonArray.length()) {
                try {
                    items.add(jsonArray.getJSONObject(i))
                } catch (e: Exception) {
                    android.util.Log.w("ScheduleWidget", "Error parsing item at index $i: ${e.message}")
                }
            }
            android.util.Log.d("ScheduleWidget", "=== Parsed ${items.size} schedule items ===")
        } catch (e: Exception) {
            android.util.Log.e("ScheduleWidget", "=== ERROR in onDataSetChanged ===", e)
            items.clear()
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int {
        val count = items.size
        android.util.Log.d("ScheduleWidget", "=== getCount returning: $count ===")
        return count
    }

    override fun getViewAt(position: Int): RemoteViews {
        android.util.Log.d("ScheduleWidget", "=== getViewAt called for position: $position ===")
        val views = RemoteViews(context.packageName, R.layout.widget_schedule_item)
        if (position < 0 || position >= items.size) {
            return views
        }
        try {
            val item = items[position]
            val type = item.optString("type", "task")
            val title = item.optString("title", "No Title")
            val dateStr = item.optString("date", "")
            
            views.setTextViewText(R.id.widget_schedule_title, title)
            
            // Use the pre-formatted display fields from Flutter for consistency
            val dateDisplay = item.optString("dateDisplay", "")
            val timeDisplay = item.optString("timeDisplay", "")
            
            if (dateDisplay.isNotEmpty()) {
                views.setTextViewText(R.id.widget_schedule_date, dateDisplay)
            } else {
                views.setTextViewText(R.id.widget_schedule_date, "")
            }
            
            if (timeDisplay.isNotEmpty()) {
                views.setTextViewText(R.id.widget_schedule_time, timeDisplay)
            } else {
                views.setTextViewText(R.id.widget_schedule_time, "")
            }
            
            // Fallback to parsing date if display fields are missing
            if (dateDisplay.isEmpty() && timeDisplay.isEmpty() && dateStr.isNotEmpty()) {
                try {
                    // Robust date parsing to handle various ISO formats from Dart
                    val date = parseIsoDateSafely(dateStr)
                    if (date != null) {
                        val timeFormatter = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
                        val dayFormatter = java.time.format.DateTimeFormatter.ofPattern("MMM d")
                        views.setTextViewText(R.id.widget_schedule_time, date.format(timeFormatter))
                        views.setTextViewText(R.id.widget_schedule_date, date.format(dayFormatter))
                        android.util.Log.d("ScheduleWidget", "Parsed date: $dateStr -> ${date.format(dayFormatter)}")
                    }
                } catch (e: Exception) {
                    android.util.Log.w("ScheduleWidget", "Failed to parse date: $dateStr - ${e.message}")
                    views.setTextViewText(R.id.widget_schedule_time, "")
                    views.setTextViewText(R.id.widget_schedule_date, "")
                }
            }

            // Category Color with improved error handling
            val colorHex = item.optString("category_color", "")
            if (colorHex.isNotEmpty() && colorHex.startsWith("#")) {
                try {
                    val color = android.graphics.Color.parseColor(colorHex)
                    views.setInt(R.id.widget_schedule_category_color, "setBackgroundColor", color)
                    views.setViewVisibility(R.id.widget_schedule_category_color, android.view.View.VISIBLE)
                } catch (e: Exception) {
                    android.util.Log.w("ScheduleWidget", "Failed to parse color: $colorHex", e)
                    // Use default color based on type
                    setDefaultColorForType(views, type)
                }
            } else {
                // No color provided, use default based on type
                setDefaultColorForType(views, type)
            }

            // Set up click intent with proper type identification
            val fillInIntent = Intent().apply {
                val id = item.optString("id", "")
                data = Uri.parse("rocistasks://schedule_item?id=$id&type=$type")
            }
            views.setOnClickFillInIntent(R.id.widget_schedule_item_container, fillInIntent)

        } catch (e: Exception) {
            android.util.Log.e("ScheduleWidget", "=== ERROR in getViewAt $position ===", e)
            // Set fallback content
            views.setTextViewText(R.id.widget_schedule_title, "Error loading item")
        }
        return views
    }

    /**
     * Set default color based on item type
     * - task: no color indicator (invisible)
     * - event: blue (device calendar events)
     * - schedule_event: purple (ROCIs-Schedule classes/exams)
     * - assignment: orange (ROCIs-Schedule assignments)
     */
    private fun setDefaultColorForType(views: RemoteViews, type: String) {
        when (type) {
            "event" -> {
                // Device calendar events - blue
                views.setInt(R.id.widget_schedule_category_color, "setBackgroundColor", android.graphics.Color.parseColor("#4285F4"))
                views.setViewVisibility(R.id.widget_schedule_category_color, android.view.View.VISIBLE)
            }
            "schedule_event" -> {
                // ROCIs-Schedule events (classes, exams, labs) - purple
                views.setInt(R.id.widget_schedule_category_color, "setBackgroundColor", android.graphics.Color.parseColor("#9C27B0"))
                views.setViewVisibility(R.id.widget_schedule_category_color, android.view.View.VISIBLE)
            }
            "assignment" -> {
                // ROCIs-Schedule assignments - orange
                views.setInt(R.id.widget_schedule_category_color, "setBackgroundColor", android.graphics.Color.parseColor("#FF9800"))
                views.setViewVisibility(R.id.widget_schedule_category_color, android.view.View.VISIBLE)
            }
            else -> {
                // Tasks - no color indicator
                views.setViewVisibility(R.id.widget_schedule_category_color, android.view.View.INVISIBLE)
            }
        }
    }

    /**
     * Safely parse ISO date strings from Dart, which might lack offsets
     */
    private fun parseIsoDateSafely(dateStr: String): java.time.LocalDateTime? {
        return try {
            when {
                dateStr.endsWith("Z") -> java.time.ZonedDateTime.parse(dateStr).toLocalDateTime()
                dateStr.contains("+") || (dateStr.lastIndexOf("-") > 10) -> java.time.OffsetDateTime.parse(dateStr).toLocalDateTime()
                else -> java.time.LocalDateTime.parse(dateStr)
            }
        } catch (e: Exception) {
            try {
                // Try treating as LocalDate + midnight
                java.time.LocalDate.parse(dateStr.take(10)).atStartOfDay()
            } catch (e2: Exception) {
                null
            }
        }
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
