package com.example.rocis_tasks

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        android.util.Log.d("TaskWidget", "=== onGetViewFactory CALLED ===")
        return TaskWidgetFactory(this.applicationContext)
    }
}

class TaskWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var tasks = ArrayList<JSONObject>()

    override fun onCreate() {
        android.util.Log.d("TaskWidget", "=== onCreate CALLED ===")
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        android.util.Log.d("TaskWidget", "=== onDataSetChanged STARTED ===")
        tasks.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            android.util.Log.d("TaskWidget", "Got widgetData: $widgetData")
            
            val tasksJson = widgetData.getString("pending_tasks_list", "[]") ?: "[]"
            android.util.Log.d("TaskWidget", "tasksJson length: ${tasksJson.length}")
            android.util.Log.d("TaskWidget", "tasksJson first 100 chars: ${tasksJson.take(100)}")
            
            // Improved JSON parsing with proper error handling
            val parsedTasks = parseTasksJsonSafely(tasksJson)
            tasks.addAll(parsedTasks)
            
            android.util.Log.d("TaskWidget", "=== Parsed ${tasks.size} valid tasks ===")
        } catch (e: Exception) {
            android.util.Log.e("TaskWidget", "=== ERROR in onDataSetChanged ===", e)
            // Ensure tasks list is empty on error to prevent crashes
            tasks.clear()
        }
    }

    /**
     * Safely parse tasks JSON with comprehensive error handling
     * Returns empty list on any parsing error to ensure graceful degradation
     */
    private fun parseTasksJsonSafely(tasksJson: String): List<JSONObject> {
        val parsedTasks = mutableListOf<JSONObject>()
        
        try {
            // Handle empty, null, or invalid JSON strings
            if (tasksJson.isEmpty() || tasksJson == "null" || tasksJson == "undefined") {
                android.util.Log.w("TaskWidget", "Empty or null tasks JSON, returning empty list")
                return parsedTasks
            }
            
            val jsonArray = JSONArray(tasksJson)
            android.util.Log.d("TaskWidget", "JSONArray length: ${jsonArray.length()}")
            
            for (i in 0 until jsonArray.length()) {
                try {
                    val taskObj = jsonArray.getJSONObject(i)
                    
                    // Validate and standardize task data
                    val validatedTask = validateAndStandardizeTask(taskObj)
                    if (validatedTask != null) {
                        parsedTasks.add(validatedTask)
                    } else {
                        android.util.Log.w("TaskWidget", "Skipping invalid task at index $i: validation failed")
                    }
                } catch (e: Exception) {
                    android.util.Log.w("TaskWidget", "Error parsing task at index $i: ${e.message}")
                    // Continue with other tasks instead of failing completely
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("TaskWidget", "Error parsing tasks JSON: ${e.message}", e)
            // Return empty list on any JSON parsing error
            return emptyList()
        }
        
        return parsedTasks
    }

    /**
     * Validate and standardize task data with fallback values
     * Returns null if task is invalid (missing required fields)
     */
    private fun validateAndStandardizeTask(taskObj: JSONObject): JSONObject? {
        try {
            // Check for required fields
            if (!taskObj.has("id") || !taskObj.has("title")) {
                android.util.Log.w("TaskWidget", "Task missing required fields (id or title)")
                return null
            }
            
            val id = extractStringSafely(taskObj, "id", "")
            val title = extractStringSafely(taskObj, "title", "")
            
            // Ensure required fields are not empty
            if (id.isEmpty() || title.isEmpty()) {
                android.util.Log.w("TaskWidget", "Task has empty required fields")
                return null
            }
            
            // Create standardized task object with validated data
            val standardizedTask = JSONObject()
            standardizedTask.put("id", id)
            standardizedTask.put("title", title)
            standardizedTask.put("dueDate", extractStringSafely(taskObj, "dueDate", ""))
            standardizedTask.put("dueDateIso", extractStringSafely(taskObj, "dueDateIso", ""))
            standardizedTask.put("category_color", extractColorSafely(taskObj, "category_color", ""))
            standardizedTask.put("priority", extractStringSafely(taskObj, "priority", "medium"))
            standardizedTask.put("isCompleted", extractBooleanSafely(taskObj, "isCompleted", false))
            
            return standardizedTask
        } catch (e: Exception) {
            android.util.Log.w("TaskWidget", "Error validating task: ${e.message}")
            return null
        }
    }

    /**
     * Safely extract string value with fallback
     */
    private fun extractStringSafely(jsonObj: JSONObject, key: String, fallback: String): String {
        return try {
            val value = jsonObj.opt(key)
            when {
                value == null -> fallback
                value is String -> if (value.isEmpty()) fallback else value
                else -> value.toString()
            }
        } catch (e: Exception) {
            android.util.Log.w("TaskWidget", "Error extracting string for key '$key': ${e.message}")
            fallback
        }
    }

    /**
     * Safely extract boolean value with fallback
     */
    private fun extractBooleanSafely(jsonObj: JSONObject, key: String, fallback: Boolean): Boolean {
        return try {
            val value = jsonObj.opt(key)
            when {
                value == null -> fallback
                value is Boolean -> value
                value is String -> value.lowercase() == "true"
                value is Number -> value.toInt() != 0
                else -> fallback
            }
        } catch (e: Exception) {
            android.util.Log.w("TaskWidget", "Error extracting boolean for key '$key': ${e.message}")
            fallback
        }
    }

    /**
     * Safely extract and validate color value with fallback
     */
    private fun extractColorSafely(jsonObj: JSONObject, key: String, fallback: String): String {
        return try {
            val value = jsonObj.opt(key)
            if (value == null || value !is String) {
                return fallback
            }
            
            val colorStr = value as String
            if (colorStr.isEmpty()) {
                return fallback
            }
            
            // Validate color format
            if (!colorStr.startsWith("#")) {
                android.util.Log.w("TaskWidget", "Invalid color format (missing #): $colorStr")
                return fallback
            }
            
            // Check hex format (6 or 8 characters after #)
            val hexPart = colorStr.substring(1)
            if (hexPart.length != 6 && hexPart.length != 8) {
                android.util.Log.w("TaskWidget", "Invalid color format (wrong length): $colorStr")
                return fallback
            }
            
            // Try to parse as hex to validate
            hexPart.toLong(16)
            
            return colorStr
        } catch (e: Exception) {
            android.util.Log.w("TaskWidget", "Error extracting color for key '$key': ${e.message}")
            fallback
        }
    }

    override fun onDestroy() {
        android.util.Log.d("TaskWidget", "=== onDestroy CALLED ===")
        tasks.clear()
    }

    override fun getCount(): Int {
        android.util.Log.d("TaskWidget", "=== getCount returning: ${tasks.size} ===")
        return tasks.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        android.util.Log.d("TaskWidget", "=== getViewAt called for position: $position ===")
        
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)
        
        // Improved bounds checking and error handling
        if (position < 0 || position >= tasks.size) {
            android.util.Log.w("TaskWidget", "Position out of bounds: $position, size: ${tasks.size}")
            return createFallbackView(views, "No tasks available")
        }

        try {
            val task = tasks[position]
            populateTaskView(views, task)
        } catch (e: Exception) {
            android.util.Log.e("TaskWidget", "=== ERROR in getViewAt $position ===", e)
            // Provide fallback content instead of crashing
            return createFallbackView(views, "Error loading task")
        }
        
        return views
    }

    /**
     * Populate RemoteViews with standardized task data and proper error handling
     */
    private fun populateTaskView(views: RemoteViews, task: JSONObject) {
        try {
            // Handle title with fallback (already validated, but double-check)
            val title = extractStringSafely(task, "title", "Untitled Task")
            views.setTextViewText(R.id.widget_task_title, title)
            
            // Handle due date with fallback and formatting
            val dueDate = extractStringSafely(task, "dueDate", "")
            val displayDate = if (dueDate.isEmpty()) "No due date" else dueDate
            views.setTextViewText(R.id.widget_task_date, displayDate)
            
            android.util.Log.d("TaskWidget", "Setting title: $title, dueDate: $displayDate")
            
            // Handle category color with improved error handling
            val colorHex = extractStringSafely(task, "category_color", "")
            if (colorHex.isNotEmpty()) {
                try {
                    val color = android.graphics.Color.parseColor(colorHex)
                    views.setInt(R.id.widget_task_category_color, "setBackgroundColor", color)
                    views.setViewVisibility(R.id.widget_task_category_color, android.view.View.VISIBLE)
                    android.util.Log.d("TaskWidget", "Applied color: $colorHex")
                } catch (e: Exception) {
                    android.util.Log.w("TaskWidget", "Invalid color format: $colorHex, error: ${e.message}")
                    views.setViewVisibility(R.id.widget_task_category_color, android.view.View.INVISIBLE)
                }
            } else {
                views.setViewVisibility(R.id.widget_task_category_color, android.view.View.INVISIBLE)
            }

            // Handle click intent with error handling
            val taskId = extractStringSafely(task, "id", "")
            if (taskId.isNotEmpty()) {
                try {
                    val fillInIntent = Intent().apply {
                        data = Uri.parse("rocistasks://task_item?id=$taskId")
                    }
                    views.setOnClickFillInIntent(R.id.widget_task_container, fillInIntent)
                } catch (e: Exception) {
                    android.util.Log.w("TaskWidget", "Error setting click intent for task $taskId: ${e.message}")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("TaskWidget", "Error populating task view: ${e.message}", e)
            // If we can't populate the view, create a fallback
            createFallbackView(views, "Error displaying task")
        }
    }

    /**
     * Create a fallback view with error message
     */
    private fun createFallbackView(views: RemoteViews, message: String): RemoteViews {
        try {
            views.setTextViewText(R.id.widget_task_title, message)
            views.setTextViewText(R.id.widget_task_date, "")
            views.setViewVisibility(R.id.widget_task_category_color, android.view.View.INVISIBLE)
        } catch (e: Exception) {
            android.util.Log.e("TaskWidget", "Error creating fallback view: ${e.message}")
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? {
        android.util.Log.d("TaskWidget", "=== getLoadingView CALLED ===")
        return null
    }
    
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
