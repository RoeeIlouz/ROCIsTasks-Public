package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class CalendarWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CalendarWidgetFactory(this.applicationContext)
    }
}

class CalendarWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var items = ArrayList<JSONObject>()
    private val TAG = "CalendarWidget"

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        items.clear()
        val widgetData = HomeWidgetPlugin.getData(context)
        
        // Load Calendar Events with improved error handling
        val eventsJson = widgetData.getString("calendar_events_list", "[]")
        try {
            if (!eventsJson.isNullOrEmpty() && eventsJson != "null") {
                val events = JSONArray(eventsJson)
                
                for (i in 0 until events.length()) {
                    try {
                        val event = events.getJSONObject(i)
                        
                        // Validate required fields before processing
                        if (hasRequiredEventFields(event)) {
                            // Standardize event data structure
                            val standardizedEvent = standardizeEventData(event)
                            items.add(standardizedEvent)
                        } else {
                        }
                    } catch (e: Exception) {
                        // Continue processing other events instead of failing completely
                    }
                }
            } else {
            }
        } catch (e: Exception) {
            // Continue with empty events list instead of crashing
        }

        // Load Pending Tasks with improved error handling
        val tasksJson = widgetData.getString("pending_tasks_list", "[]")
        try {
            if (!tasksJson.isNullOrEmpty() && tasksJson != "null") {
                val tasks = JSONArray(tasksJson)
                
                for (i in 0 until tasks.length()) {
                    try {
                        val task = tasks.getJSONObject(i)
                        
                        // Validate required fields and filter for tasks with due dates
                        if (hasRequiredTaskFields(task) && hasValidDueDate(task)) {
                            // Standardize task data structure for calendar display
                            val standardizedTask = standardizeTaskDataForCalendar(task)
                            items.add(standardizedTask)
                        } else {
                        }
                    } catch (e: Exception) {
                        // Continue processing other tasks instead of failing completely
                    }
                }
            } else {
            }
        } catch (e: Exception) {
            // Continue with empty tasks list instead of crashing
        }

        // Improved sorting logic with proper error handling
        try {
            items.sortWith { a, b ->
                try {
                    val dateA = a.optString("sortDate", "")
                    val dateB = b.optString("sortDate", "")
                    
                    // Handle empty dates by pushing them to the end
                    when {
                        dateA.isEmpty() && dateB.isEmpty() -> 0
                        dateA.isEmpty() -> 1
                        dateB.isEmpty() -> -1
                        else -> {
                            // Parse and compare dates safely
                            try {
                                val parsedDateA = parseIsoDate(dateA)
                                val parsedDateB = parseIsoDate(dateB)
                                parsedDateA.compareTo(parsedDateB)
                            } catch (e: Exception) {
                                dateA.compareTo(dateB) // Fallback to string comparison
                            }
                        }
                    }
                } catch (e: Exception) {
                    0 // Treat as equal if comparison fails
                }
            }
            
        } catch (e: Exception) {
            // Continue with unsorted items instead of crashing
        }
    }

    override fun onDestroy() {}

    override fun getCount(): Int {
        return items.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_item)
        
        try {
            if (position >= items.size) {
                return createErrorView("Invalid position")
            }
            
            val item = items[position]
            val isTask = item.optString("type", "event") == "task"
            val title = item.optString("title", "No Title")
            
            // Set title with fallback
            views.setTextViewText(R.id.widget_event_title, title)
            views.setTextColor(R.id.widget_event_title, context.getColor(R.color.widget_title_text))

            // Set Category Color with improved error handling and fallback
            val colorHex = item.optString("category_color", "")
            setColorWithFallback(views, colorHex)

            // Set date/time display information
            setDateTimeDisplay(views, item, isTask)

            // Set Intent to open app with proper error handling
            try {
                val itemId = item.optString("id", "")
                val fillInIntent = Intent().apply {
                    data = android.net.Uri.parse("rocistasks://calendar_item?id=$itemId&is_task=$isTask")
                }
                views.setOnClickFillInIntent(R.id.widget_calendar_item_container, fillInIntent)
            } catch (e: Exception) {
                // Continue without click functionality rather than crashing
            }

        } catch (e: Exception) {
            return createErrorView("Error loading item")
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? {
        return null
    }

    override fun getViewTypeCount(): Int {
        return 1
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun hasStableIds(): Boolean {
        return true
    }

    // Helper methods for improved data processing and error handling

    private fun hasRequiredEventFields(event: JSONObject): Boolean {
        return event.has("title") && 
               event.has("start") && 
               event.has("id") &&
               event.optString("title", "").isNotEmpty() &&
               event.optString("start", "").isNotEmpty()
    }

    private fun hasRequiredTaskFields(task: JSONObject): Boolean {
        return task.has("title") && 
               task.has("id") &&
               task.optString("title", "").isNotEmpty() &&
               task.optString("id", "").isNotEmpty()
    }

    private fun hasValidDueDate(task: JSONObject): Boolean {
        val dueDateIso = task.optString("dueDateIso", "")
        val dueDate = task.optString("dueDate", "")
        return dueDateIso.isNotEmpty() || dueDate.isNotEmpty()
    }

    private fun standardizeEventData(event: JSONObject): JSONObject {
        val standardized = JSONObject()
        
        try {
            // Copy required fields with fallbacks
            standardized.put("type", "event")
            standardized.put("id", event.optString("id", "unknown_event"))
            standardized.put("title", event.optString("title", "No Title"))
            standardized.put("start", event.optString("start", ""))
            standardized.put("startDisplay", event.optString("startDisplay", ""))
            standardized.put("dateDisplay", event.optString("dateDisplay", ""))
            standardized.put("category_color", event.optString("category_color", "#4285F4"))
            
            // Set sortDate for consistent sorting
            val startTime = event.optString("start", "")
            standardized.put("sortDate", startTime)
            
            // Mark as event for identification
            standardized.put("is_task", false)
            
        } catch (e: Exception) {
            // Return minimal valid structure
            standardized.put("type", "event")
            standardized.put("id", "error_event")
            standardized.put("title", "Error loading event")
            standardized.put("sortDate", "9999-12-31T23:59:59Z")
            standardized.put("is_task", false)
        }
        
        return standardized
    }

    private fun standardizeTaskDataForCalendar(task: JSONObject): JSONObject {
        val standardized = JSONObject()
        
        try {
            // Copy required fields with fallbacks
            standardized.put("type", "task")
            standardized.put("id", task.optString("id", "unknown_task"))
            standardized.put("title", task.optString("title", "No Title"))
            
            // Use dueDateIso for sorting, dueDate for display
            val dueDateIso = task.optString("dueDateIso", "")
            val dueDate = task.optString("dueDate", "")
            
            if (dueDateIso.isNotEmpty()) {
                standardized.put("start", dueDateIso)
                standardized.put("sortDate", dueDateIso)
            } else if (dueDate.isNotEmpty()) {
                // Try to convert display date to ISO format for sorting
                try {
                    val parsedDate = parseDisplayDate(dueDate)
                    standardized.put("start", parsedDate.toIso8601String())
                    standardized.put("sortDate", parsedDate.toIso8601String())
                } catch (e: Exception) {
                    standardized.put("start", "")
                    standardized.put("sortDate", "9999-12-31T23:59:59Z") // Push to end
                }
            } else {
                standardized.put("start", "")
                standardized.put("sortDate", "9999-12-31T23:59:59Z") // Push to end
            }
            
            // Set display fields
            standardized.put("startDisplay", formatTimeForDisplay(standardized.optString("start", "")))
            standardized.put("dateDisplay", dueDate.ifEmpty { formatDateForDisplay(standardized.optString("start", "")) })
            
            // Set category color with fallback
            val categoryColor = task.optString("category_color", "#9E9E9E")
            standardized.put("category_color", categoryColor)
            
            // Mark as task for identification
            standardized.put("is_task", true)
            
        } catch (e: Exception) {
            // Return minimal valid structure
            standardized.put("type", "task")
            standardized.put("id", "error_task")
            standardized.put("title", "Error loading task")
            standardized.put("sortDate", "9999-12-31T23:59:59Z")
            standardized.put("is_task", true)
        }
        
        return standardized
    }

    private fun setColorWithFallback(views: RemoteViews, colorHex: String) {
        try {
            if (colorHex.isNotEmpty() && colorHex != "null") {
                // Validate color format before parsing
                if (isValidColorFormat(colorHex)) {
                    val color = android.graphics.Color.parseColor(colorHex)
                    views.setInt(R.id.widget_event_category_color, "setBackgroundColor", color)
                    views.setViewVisibility(R.id.widget_event_category_color, android.view.View.VISIBLE)
                } else {
                    setTransparentColor(views)
                }
            } else {
                setTransparentColor(views)
            }
        } catch (e: Exception) {
            setTransparentColor(views)
        }
    }

    private fun isValidColorFormat(colorHex: String): Boolean {
        if (!colorHex.startsWith("#")) return false
        if (colorHex.length != 7 && colorHex.length != 9) return false // #RRGGBB or #RRGGBBAA
        
        val hexPart = colorHex.substring(1)
        return hexPart.all { it.isDigit() || it.lowercaseChar() in 'a'..'f' }
    }

    private fun setTransparentColor(views: RemoteViews) {
        views.setInt(R.id.widget_event_category_color, "setBackgroundColor", android.graphics.Color.TRANSPARENT)
        views.setViewVisibility(R.id.widget_event_category_color, android.view.View.GONE)
    }

    private fun setDateTimeDisplay(views: RemoteViews, item: JSONObject, isTask: Boolean) {
        try {
            val startDisplay = item.optString("startDisplay", "")
            val dateDisplay = item.optString("dateDisplay", "")
            
            // For now, we only show the title in the current layout
            // Future enhancement could add date/time display to the layout
            
        } catch (e: Exception) {
        }
    }

    private fun createErrorView(errorMessage: String): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_calendar_item)
        views.setTextViewText(R.id.widget_event_title, errorMessage)
        views.setTextColor(R.id.widget_event_title, context.getColor(android.R.color.darker_gray))
        setTransparentColor(views)
        return views
    }

    private fun parseIsoDate(isoString: String): java.util.Date {
        return java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", java.util.Locale.getDefault()).parse(isoString)
            ?: throw IllegalArgumentException("Invalid ISO date format: $isoString")
    }

    private fun parseDisplayDate(displayDate: String): java.util.Date {
        // Try to parse YYYY-MM-DD format
        return java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault()).parse(displayDate)
            ?: throw IllegalArgumentException("Invalid display date format: $displayDate")
    }

    private fun formatTimeForDisplay(isoString: String): String {
        return try {
            if (isoString.isEmpty()) return ""
            val date = parseIsoDate(isoString)
            java.text.SimpleDateFormat("HH:mm", java.util.Locale.getDefault()).format(date)
        } catch (e: Exception) {
            ""
        }
    }

    private fun formatDateForDisplay(isoString: String): String {
        return try {
            if (isoString.isEmpty()) return ""
            val date = parseIsoDate(isoString)
            java.text.SimpleDateFormat("MMM d", java.util.Locale.getDefault()).format(date)
        } catch (e: Exception) {
            ""
        }
    }

    // Extension function to convert Date to ISO string
    private fun java.util.Date.toIso8601String(): String {
        return java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.getDefault()).format(this)
    }
}

