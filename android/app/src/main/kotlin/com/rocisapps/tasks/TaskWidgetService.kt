package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
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

class TaskWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return TaskWidgetFactory(this.applicationContext)
    }
}

/**
 * The Pending Tasks widget's data: `pending_tasks_list` validated, filtered and sorted by
 * the widget's sort/filter chips. Shared by the list factory and the header count.
 */
internal object TaskListData {

    const val SORT_DATE = 0
    const val SORT_PRIORITY = 1

    fun sortMode(prefs: SharedPreferences): Int =
        if (prefs.getInt(TaskWidgetProvider.PREF_SORT_KEY, SORT_DATE) == SORT_PRIORITY) SORT_PRIORITY else SORT_DATE

    /** Stored filter, falling back to "All" for Pro-only filters once Pro is gone. */
    fun filterMode(prefs: SharedPreferences): Int {
        val isPremium = prefs.getBoolean("is_premium", false)
        val stored = prefs.getInt(TaskWidgetProvider.PREF_FILTER_KEY, 0)
        val max = if (isPremium) 5 else 3
        return if (stored in 0 until max) stored else 0
    }

    fun load(prefs: SharedPreferences): List<JSONObject> {
        val parsed = parseTasksJsonSafely(prefs.getString("pending_tasks_list", "[]") ?: "[]")
        val filterMode = filterMode(prefs)
        val filtered = parsed.filter { task ->
            when (filterMode) {
                1 -> isDueToday(task)
                2 -> isHighPriority(task)
                3 -> isOverdue(task)
                4 -> task.optBoolean("isPinned", false)
                else -> true
            }
        }
        // Undated tasks last; same-day tasks by time.
        val byDate = compareBy<JSONObject>(
            { it.optString("dueDate", "").ifEmpty { "9999-99-99" } },
            { it.optString("dueDateIso", "") }
        )
        return if (sortMode(prefs) == SORT_PRIORITY) {
            filtered.sortedWith(compareByDescending<JSONObject> { priorityLevel(it) }.then(byDate))
        } else {
            filtered.sortedWith(byDate)
        }
    }

    fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)

    private fun isDueToday(task: JSONObject): Boolean {
        val dueDate = task.optString("dueDate", "")
        return dueDate.isNotEmpty() && dueDate == todayKey()
    }

    private fun isHighPriority(task: JSONObject): Boolean =
        task.optString("priority", "").equals("high", ignoreCase = true)

    fun isOverdue(task: JSONObject): Boolean {
        val due = dueMillis(task) ?: return false
        return due < System.currentTimeMillis()
    }

    /** The due instant from `dueDateIso` (with or without an offset), or null. */
    fun dueMillis(task: JSONObject): Long? {
        val dueIso = task.optString("dueDateIso", "")
        if (dueIso.isEmpty()) return null
        return try {
            try {
                java.time.OffsetDateTime.parse(dueIso).toInstant().toEpochMilli()
            } catch (_: Exception) {
                java.time.LocalDateTime.parse(dueIso).atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun priorityLevel(task: JSONObject): Int = when (task.optString("priority", "").lowercase()) {
        "high" -> 3
        "medium" -> 2
        "low" -> 1
        else -> 0
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
                    val validatedTask = validateAndStandardizeTask(jsonArray.getJSONObject(i))
                    if (validatedTask != null) parsedTasks.add(validatedTask)
                } catch (_: Exception) {
                }
            }
        } catch (_: Exception) {
            return emptyList()
        }
        return parsedTasks
    }

    private fun validateAndStandardizeTask(taskObj: JSONObject): JSONObject? {
        return try {
            if (!taskObj.has("id") || !taskObj.has("title")) return null
            val id = extractStringSafely(taskObj, "id", "")
            val title = extractStringSafely(taskObj, "title", "")
            if (id.isEmpty() || title.isEmpty()) return null

            JSONObject().apply {
                put("id", id)
                put("title", title)
                put("dueDate", extractStringSafely(taskObj, "dueDate", ""))
                put("dueDateIso", extractStringSafely(taskObj, "dueDateIso", ""))
                put("category_name", extractStringSafely(taskObj, "category_name", ""))
                put("category_color", extractColorSafely(taskObj, "category_color", ""))
                put("priority", extractStringSafely(taskObj, "priority", "medium"))
                put("isCompleted", extractBooleanSafely(taskObj, "isCompleted", false))
                put("isPinned", extractBooleanSafely(taskObj, "isPinned", false))
                put("categoryId", extractStringSafely(taskObj, "categoryId", ""))
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun extractStringSafely(jsonObj: JSONObject, key: String, fallback: String): String {
        return try {
            when (val value = jsonObj.opt(key)) {
                null, JSONObject.NULL -> fallback
                is String -> value.ifEmpty { fallback }
                else -> value.toString()
            }
        } catch (_: Exception) {
            fallback
        }
    }

    private fun extractBooleanSafely(jsonObj: JSONObject, key: String, fallback: Boolean): Boolean {
        return try {
            when (val value = jsonObj.opt(key)) {
                is Boolean -> value
                is String -> value.lowercase() == "true"
                is Number -> value.toInt() != 0
                else -> fallback
            }
        } catch (_: Exception) {
            fallback
        }
    }

    private fun extractColorSafely(jsonObj: JSONObject, key: String, fallback: String): String {
        return try {
            val colorStr = jsonObj.opt(key) as? String ?: return fallback
            if (colorStr.isEmpty() || !colorStr.startsWith("#")) return fallback
            val hexPart = colorStr.substring(1)
            if (hexPart.length != 6 && hexPart.length != 8) return fallback
            hexPart.toLong(16)
            colorStr
        } catch (_: Exception) {
            fallback
        }
    }
}

class TaskWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val tasks = ArrayList<JSONObject>()
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
            val processed = TaskListData.load(widgetData)
            tasks.clear()
            tasks.addAll(processed)
        } catch (_: Exception) {
            // Keep existing tasks on error instead of clearing
        }
    }

    override fun onDestroy() {
        tasks.clear()
    }

    override fun getCount(): Int = tasks.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_task_item)
        if (position < 0 || position >= tasks.size) return views
        val palette = palette ?: return views

        try {
            val task = tasks[position]
            val id = task.optString("id", "")
            val accent = WidgetStyle.parseColor(task.optString("category_color", ""), palette.primary)

            // Tile: a faint onSurface wash on the card, like the app's list tiles.
            WidgetStyle.applyTile(views, R.id.widget_task_fill, palette.onSurface, if (palette.isDark) 0x14 else 0x0D)
            views.setInt(R.id.widget_task_category_color, "setColorFilter", accent)

            views.setTextViewText(R.id.widget_task_title, task.optString("title", ""))
            views.setTextColor(R.id.widget_task_title, palette.onSurface)

            // Due line: "Today 14:30" in the accent; overdue in red; category muted.
            val dueLabel = dueLabel(task)
            views.setTextViewText(R.id.widget_task_date, dueLabel)
            views.setViewVisibility(R.id.widget_task_date, if (dueLabel.isEmpty()) View.GONE else View.VISIBLE)
            views.setTextColor(
                R.id.widget_task_date,
                if (TaskListData.isOverdue(task)) WidgetStyle.PRIORITY_HIGH else palette.primary
            )
            val category = task.optString("category_name", "")
            views.setTextViewText(R.id.widget_task_meta, category)
            views.setTextColor(R.id.widget_task_meta, palette.onSurfaceMuted)
            views.setViewVisibility(
                R.id.widget_task_meta_row,
                if (dueLabel.isEmpty() && category.isEmpty()) View.GONE else View.VISIBLE
            )

            val done = task.optBoolean("isCompleted", false)
            views.setImageViewResource(
                R.id.widget_task_check,
                if (done) R.drawable.ic_widget_check_on else R.drawable.ic_widget_check_off
            )
            views.setInt(R.id.widget_task_check, "setColorFilter", if (done) palette.primary else palette.onSurfaceMuted)

            val priority = task.optString("priority", "")
            val priorityColor = WidgetStyle.priorityColor(priority)
            // Low priority is the default; only flag medium and high like the app.
            if (priorityColor != null && !priority.equals("low", ignoreCase = true)) {
                views.setViewVisibility(R.id.widget_task_badge_box, View.VISIBLE)
                views.setTextViewText(R.id.widget_task_badge, WidgetStyle.priorityLabel(priority, locale))
                views.setTextColor(R.id.widget_task_badge, priorityColor)
                WidgetStyle.applyTile(views, R.id.widget_task_badge_fill, priorityColor, 0x26)
            } else {
                views.setViewVisibility(R.id.widget_task_badge_box, View.GONE)
            }

            if (id.isNotEmpty()) {
                views.setOnClickFillInIntent(
                    R.id.widget_task_check,
                    Intent().apply { data = Uri.parse("rocistasks://complete?id=$id") }
                )
                views.setOnClickFillInIntent(
                    R.id.widget_task_container,
                    Intent().apply { data = Uri.parse("rocistasks://task_detail?id=$id") }
                )
            }
        } catch (_: Exception) {}

        return views
    }

    /**
     * Localized due label: Today / Tomorrow / Yesterday or a short date, plus the time
     * when one is set; past days read "Overdue · Sep 20".
     */
    private fun dueLabel(task: JSONObject): String {
        val dueDate = task.optString("dueDate", "")
        if (dueDate.isEmpty()) return ""
        val dayFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        val due = Calendar.getInstance()
        try {
            due.time = dayFormat.parse(dueDate) ?: return ""
        } catch (_: Exception) {
            return ""
        }
        val today = TaskListData.todayKey()
        val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }
        val yesterday = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, -1) }

        val day = when (dueDate) {
            today -> WidgetLocaleHelper.getTodayText(locale)
            dayFormat.format(tomorrow.time) -> WidgetLocaleHelper.getTomorrowText(locale)
            dayFormat.format(yesterday.time) -> WidgetLocaleHelper.getYesterdayText(locale)
            else -> WidgetLocaleHelper.getDateTitle(due, locale, false)
        }

        // Time of day, unless the task is due at midnight (date-only).
        val time = TaskListData.dueMillis(task)?.let { millis ->
            val cal = Calendar.getInstance().apply { timeInMillis = millis }
            if (cal.get(Calendar.HOUR_OF_DAY) == 0 && cal.get(Calendar.MINUTE) == 0) null
            else SimpleDateFormat("HH:mm", locale).format(cal.time)
        }
        val label = if (time != null) "$day $time" else day
        return if (dueDate < today) "${WidgetStyle.overdueText(locale)} · $label" else label
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
