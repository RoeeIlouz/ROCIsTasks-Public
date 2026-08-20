package com.rocisapps.tasks

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
        return TaskWidgetFactory(this.applicationContext)
    }
}

class TaskWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var tasks = ArrayList<JSONObject>()

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        tasks.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            
            val tasksJson = widgetData.getString("pending_tasks_list", "[]") ?: "[]"
            val parsedTasks = parseTasksJsonSafely(tasksJson)
            
            // Read sort/filter prefs
            val sortMode = widgetData.getInt(TaskWidgetProvider.PREF_SORT_KEY, 0)
            val filterMode = widgetData.getInt(TaskWidgetProvider.PREF_FILTER_KEY, 0)
            val isPremium = widgetData.getBoolean("is_premium", false)
            
            // Filter
            var processedList = parsedTasks.filter { task ->
                when (filterMode) {
                    1 -> isDueToday(task)
                    2 -> isHighPriority(task)
                    3 -> isPremium && isOverdue(task)
                    4 -> isPremium && isPinned(task)
                    else -> true
                }
            }
            
            // Sort
            processedList = if (sortMode == 1) { // Priority
                processedList.sortedWith(Comparator { a, b ->
                    val pA = getPriorityLevel(a)
                    val pB = getPriorityLevel(b)
                    
                    // If priorities are equal, sort by date
                    if (pA == pB) {
                        val dA = a.optString("dueDate", "9999-99-99")
                        val dB = b.optString("dueDate", "9999-99-99")
                        val d1 = if (dA.isEmpty()) "9999-99-99" else dA
                        val d2 = if (dB.isEmpty()) "9999-99-99" else dB
                        d1.compareTo(d2)
                    } else {
                        pB - pA // Descending (3 > 2)
                    }
                })
            } else { // Date
                processedList.sortedWith(Comparator { a, b ->
                    val dA = a.optString("dueDate", "9999-99-99")
                    val dB = b.optString("dueDate", "9999-99-99")
                    val d1 = if (dA.isEmpty()) "9999-99-99" else dA
                    val d2 = if (dB.isEmpty()) "9999-99-99" else dB
                    d1.compareTo(d2)
                })
            }

            tasks.addAll(processedList)
            
        } catch (e: Exception) {
            tasks.clear()
        }
    }

    private fun isDueToday(task: JSONObject): Boolean {
        val dueDate = task.optString("dueDate", "")
        if (dueDate.isEmpty()) return false
        val sdf = java.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.getDefault())
        val today = sdf.format(java.util.Date())
        return dueDate == today
    }

    private fun isHighPriority(task: JSONObject): Boolean {
        return task.optString("priority", "").equals("high", ignoreCase = true)
    }

    private fun isPinned(task: JSONObject): Boolean {
        return task.optBoolean("isPinned", false)
    }

    private fun isOverdue(task: JSONObject): Boolean {
        val dueIso = task.optString("dueDateIso", "")
        if (dueIso.isEmpty()) return false
        return try {
            val due = try {
                java.time.OffsetDateTime.parse(dueIso).toInstant()
            } catch (e: Exception) {
                java.time.LocalDateTime.parse(dueIso).atZone(java.time.ZoneId.systemDefault()).toInstant()
            }
            val now = java.time.Instant.now()
            due.isBefore(now)
        } catch (e: Exception) {
            false
        }
    }

    private fun getPriorityLevel(task: JSONObject): Int {
        return when (task.optString("priority", "").lowercase()) {
            "high" -> 3
            "medium" -> 2
            "low" -> 1
            else -> 0
        }
    }

    private fun parseTasksJsonSafely(tasksJson: String): List<JSONObject> {
        val parsedTasks = mutableListOf<JSONObject>()
        
        try {
            if (tasksJson.isEmpty() || tasksJson == "null" || tasksJson == "undefined") {
                return parsedTasks
            }
            
            val jsonArray = JSONArray(tasksJson)
            
            for (i in 0 until jsonArray.length()) {
                try {
                    val taskObj = jsonArray.getJSONObject(i)
                    val validatedTask = validateAndStandardizeTask(taskObj)
                    if (validatedTask != null) {
                        parsedTasks.add(validatedTask)
                    }
                } catch (_: Exception) {
                }
            }
        } catch (_: Exception) {
            return emptyList()
        }
        
        return parsedTasks
    }

    private fun validateAndStandardizeTask(taskObj: JSONObject): JSONObject? {
        try {
            if (!taskObj.has("id") || !taskObj.has("title")) {
                return null
            }
            
            val id = extractStringSafely(taskObj, "id", "")
            val title = extractStringSafely(taskObj, "title", "")
            
            if (id.isEmpty() || title.isEmpty()) {
                return null
            }
            
            val standardizedTask = JSONObject()
            standardizedTask.put("id", id)
            standardizedTask.put("title", title)
            standardizedTask.put("dueDate", extractStringSafely(taskObj, "dueDate", ""))
            standardizedTask.put("dueDateIso", extractStringSafely(taskObj, "dueDateIso", ""))
            standardizedTask.put("category_name", extractStringSafely(taskObj, "category_name", ""))
            standardizedTask.put("category_color", extractColorSafely(taskObj, "category_color", ""))
            standardizedTask.put("priority", extractStringSafely(taskObj, "priority", "medium"))
            standardizedTask.put("isCompleted", extractBooleanSafely(taskObj, "isCompleted", false))
            standardizedTask.put("isPinned", extractBooleanSafely(taskObj, "isPinned", false))
            standardizedTask.put("categoryId", extractStringSafely(taskObj, "categoryId", ""))
            
            return standardizedTask
        } catch (e: Exception) {
            return null
        }
    }

    private fun extractStringSafely(jsonObj: JSONObject, key: String, fallback: String): String {
        return try {
            val value = jsonObj.opt(key)
            when {
                value == null -> fallback
                value is String -> if (value.isEmpty()) fallback else value
                else -> value.toString()
            }
        } catch (e: Exception) {
            fallback
        }
    }

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
            fallback
        }
    }

    private fun extractColorSafely(jsonObj: JSONObject, key: String, fallback: String): String {
        return try {
            val value = jsonObj.opt(key)
            if (value == null || value !is String) {
                return fallback
            }
            
            val colorStr = value as String
            if (colorStr.isEmpty() || !colorStr.startsWith("#")) {
                return fallback
            }
            
            val hexPart = colorStr.substring(1)
            if (hexPart.length != 6 && hexPart.length != 8) {
                return fallback
            }
            
            hexPart.toLong(16)
            return colorStr
        } catch (e: Exception) {
            fallback
        }
    }

    override fun onDestroy() {
        tasks.clear()
    }

    override fun getCount(): Int {
        return tasks.size
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)
        
        if (position < 0 || position >= tasks.size) {
            return createFallbackView(views, "No tasks available")
        }

        try {
            val task = tasks[position]
            populateTaskView(views, task)
        } catch (e: Exception) {
            return createFallbackView(views, "Error loading task")
        }
        
        return views
    }

    private fun populateTaskView(views: RemoteViews, task: JSONObject) {
        try {
            val title = extractStringSafely(task, "title", "Untitled Task")
            views.setTextViewText(R.id.widget_task_title, title)

            val categoryName = extractStringSafely(task, "category_name", "")
            val rawPriority = extractStringSafely(task, "priority", "")
            val priority = if (rawPriority.isNotEmpty()) {
                rawPriority.substring(0, 1).uppercase() + rawPriority.substring(1).lowercase()
            } else {
                ""
            }

            val metaParts = listOf(categoryName, priority).filter { it.isNotEmpty() }
            if (metaParts.isNotEmpty()) {
                views.setTextViewText(R.id.widget_task_meta, metaParts.joinToString(" • "))
                views.setViewVisibility(R.id.widget_task_meta, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_task_meta, android.view.View.GONE)
            }
            
            val dueDate = extractStringSafely(task, "dueDate", "")
            val displayDate = if (dueDate.isEmpty()) "No due date" else dueDate
            views.setTextViewText(R.id.widget_task_date, displayDate)
            
            val colorHex = extractStringSafely(task, "category_color", "")
            if (colorHex.isNotEmpty()) {
                try {
                    val color = android.graphics.Color.parseColor(colorHex)
                    views.setInt(R.id.widget_task_category_color, "setBackgroundColor", color)
                    views.setViewVisibility(R.id.widget_task_category_color, android.view.View.VISIBLE)
                } catch (e: Exception) {
                    views.setViewVisibility(R.id.widget_task_category_color, android.view.View.INVISIBLE)
                }
            } else {
                views.setViewVisibility(R.id.widget_task_category_color, android.view.View.INVISIBLE)
            }

            val taskId = extractStringSafely(task, "id", "")
            if (taskId.isNotEmpty()) {
                try {
                    val isCompleted = task.optBoolean("isCompleted", false)
                    if (isCompleted) {
                        views.setImageViewResource(R.id.widget_task_check, R.drawable.ic_check_circle_filled)
                    } else {
                        views.setImageViewResource(R.id.widget_task_check, R.drawable.ic_circle_outline)
                    }

                    // Checkbox clicks trigger instant background task completion
                    val checkFillInIntent = Intent().apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("rocistasks://complete?id=$taskId")
                    }
                    views.setOnClickFillInIntent(R.id.widget_task_check, checkFillInIntent)

                    // Row container clicks open task details in the app
                    val fillInIntent = Intent().apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("rocistasks://task_item?id=$taskId")
                    }
                    views.setOnClickFillInIntent(R.id.widget_task_container, fillInIntent)
                } catch (_: Exception) {
                }
            }
        } catch (e: Exception) {
            createFallbackView(views, "Error displaying task")
        }
    }

    private fun createFallbackView(views: RemoteViews, message: String): RemoteViews {
        try {
            views.setTextViewText(R.id.widget_task_title, message)
            views.setTextViewText(R.id.widget_task_date, "")
            views.setViewVisibility(R.id.widget_task_category_color, android.view.View.INVISIBLE)
        } catch (_: Exception) {
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
