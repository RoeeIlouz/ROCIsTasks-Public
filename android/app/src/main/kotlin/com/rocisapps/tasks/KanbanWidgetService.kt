package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Paint
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class KanbanWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return KanbanWidgetFactory(this.applicationContext)
    }
}

class KanbanWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val items = ArrayList<JSONObject>()
    private var widgetTheme = "system"
    private var highlightColor = Color.parseColor("#6366F1")

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        items.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            widgetTheme = widgetData.getString("full_calendar_theme", "system") ?: "system"
            val colorHex = widgetData.getString("full_calendar_highlight_color", "#6366F1") ?: "#6366F1"
            highlightColor = try {
                Color.parseColor(colorHex)
            } catch (_: Exception) {
                Color.parseColor("#6366F1")
            }

            val columnIndex = (widgetData.getInt(KanbanWidgetProvider.PREF_KANBAN_COLUMN, 0) % 3 + 3) % 3

            val rawJson = widgetData.getString("kanban_data", "{}") ?: "{}"
            val kanbanJson = JSONObject(rawJson)

            val columnKey = when (columnIndex) {
                1 -> "column_infocus"
                2 -> "column_done"
                else -> "column_todo"
            }

            val jsonArray = kanbanJson.optJSONArray(columnKey) ?: JSONArray()
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.optJSONObject(i) ?: continue
                items.add(item)
            }
        } catch (_: Exception) {
            items.clear()
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_kanban_item)
        if (position < 0 || position >= items.size) return views

        try {
            val item = items[position]
            val id = item.optString("id", "")
            val title = item.optString("title", "Untitled")
            val isCompleted = item.optBoolean("isCompleted", false)
            val isOverdue = item.optBoolean("isOverdue", false)
            val dateDisplay = item.optString("dateDisplay", "")
            val category = item.optString("category", "")
            val priority = item.optString("priority", "")
            val categoryColorHex = item.optString("category_color", "#6366F1")

            val titleColor = when (widgetTheme) {
                "light" -> if (isCompleted) Color.parseColor("#94A3B8") else Color.parseColor("#0F172A")
                else -> if (isCompleted) Color.parseColor("#64748B") else Color.parseColor("#F8FAFC")
            }

            val secondaryColor = when (widgetTheme) {
                "light" -> Color.parseColor("#64748B")
                else -> Color.parseColor("#94A3B8")
            }

            views.setTextViewText(R.id.widget_kanban_item_title, title)
            views.setTextColor(R.id.widget_kanban_item_title, titleColor)

            // Category accent strip
            val catColor = try {
                Color.parseColor(categoryColorHex)
            } catch (_: Exception) {
                highlightColor
            }
            views.setInt(R.id.widget_kanban_color_strip, "setBackgroundColor", catColor)

            // Category Subtitle
            if (category.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_kanban_item_category, View.VISIBLE)
                views.setTextViewText(R.id.widget_kanban_item_category, category)
                views.setTextColor(R.id.widget_kanban_item_category, secondaryColor)
            } else {
                views.setViewVisibility(R.id.widget_kanban_item_category, View.GONE)
            }

            // Due Date / Status Chip
            if (dateDisplay.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_kanban_item_date, View.VISIBLE)
                views.setTextViewText(R.id.widget_kanban_item_date, dateDisplay)
                val dateColor = if (isOverdue && !isCompleted) Color.parseColor("#EF4444") else secondaryColor
                views.setTextColor(R.id.widget_kanban_item_date, dateColor)
            } else {
                views.setViewVisibility(R.id.widget_kanban_item_date, View.GONE)
            }

            // Priority Badge
            if (priority.isNotEmpty() && priority.uppercase() != "NONE") {
                views.setViewVisibility(R.id.widget_kanban_item_priority, View.VISIBLE)
                views.setTextViewText(R.id.widget_kanban_item_priority, priority.uppercase())
                val priorityColor = when (priority.lowercase()) {
                    "high" -> Color.parseColor("#EF4444")
                    "medium" -> Color.parseColor("#F59E0B")
                    "low" -> Color.parseColor("#3B82F6")
                    else -> highlightColor
                }
                views.setTextColor(R.id.widget_kanban_item_priority, priorityColor)
            } else {
                views.setViewVisibility(R.id.widget_kanban_item_priority, View.GONE)
            }

            // Checkbox Icon & Tint
            val checkIcon = if (isCompleted) R.drawable.ic_check_circle_filled else R.drawable.ic_circle_outline
            views.setImageViewResource(R.id.widget_kanban_check, checkIcon)
            val checkTint = if (isCompleted) highlightColor else secondaryColor
            views.setInt(R.id.widget_kanban_check, "setColorFilter", checkTint)

            // Fill-in Intent for whole row click -> Open task detail
            val rowFillInIntent = Intent().apply {
                data = Uri.parse("rocistasks://task_detail?id=$id")
            }
            views.setOnClickFillInIntent(R.id.widget_kanban_item_root, rowFillInIntent)

            // Fill-in Intent for checkmark click -> Complete / Toggle task
            val checkFillInIntent = Intent().apply {
                data = Uri.parse("rocistasks://complete?id=$id")
            }
            views.setOnClickFillInIntent(R.id.widget_kanban_check, checkFillInIntent)

        } catch (e: Exception) {
            android.util.Log.e("KanbanWidgetService", "Error binding view at $position", e)
        }

        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
