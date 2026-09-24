package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.util.Locale

class KanbanWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return KanbanWidgetFactory(this.applicationContext)
    }
}

class KanbanWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val items = ArrayList<JSONObject>()
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

            val columnIndex = (widgetData.getInt(KanbanWidgetProvider.PREF_KANBAN_COLUMN, 0) % 3 + 3) % 3

            val rawJson = widgetData.getString("kanban_data", "{}") ?: "{}"
            val kanbanJson = JSONObject(rawJson)

            val columnKey = when (columnIndex) {
                1 -> "column_infocus"
                2 -> "column_done"
                else -> "column_todo"
            }

            val jsonArray = kanbanJson.optJSONArray(columnKey) ?: JSONArray()
            val newItems = ArrayList<JSONObject>()
            for (i in 0 until jsonArray.length()) {
                val item = jsonArray.optJSONObject(i) ?: continue
                newItems.add(item)
            }
            items.clear()
            items.addAll(newItems)
        } catch (_: Exception) {
            // Keep existing items on error
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_kanban_item)
        if (position < 0 || position >= items.size) return views
        val palette = palette ?: return views

        try {
            val item = items[position]
            val id = item.optString("id", "")
            val isCompleted = item.optBoolean("isCompleted", false)
            val isOverdue = item.optBoolean("isOverdue", false)
            val dateDisplay = item.optString("dateDisplay", "")
            val category = item.optString("category", "")
            val priority = item.optString("priority", "")
            val accent = WidgetStyle.parseColor(item.optString("category_color", ""), palette.primary)

            // Tile: a faint onSurface wash on the card, like the app's list tiles.
            WidgetStyle.applyTile(views, R.id.widget_kanban_item_fill, palette.onSurface, if (palette.isDark) 0x14 else 0x0D)
            views.setInt(R.id.widget_kanban_color_strip, "setColorFilter", accent)
            views.setInt(R.id.widget_kanban_color_strip, "setImageAlpha", if (isCompleted) 0x66 else 0xFF)

            // Title: done cards are muted and struck through, like the app's completed tasks.
            // setPaintFlags isn't allowed on RemoteViews; strike through with a span.
            val title = item.optString("title", "")
            views.setTextViewText(
                R.id.widget_kanban_item_title,
                if (isCompleted) {
                    android.text.SpannableString(title).apply {
                        setSpan(android.text.style.StrikethroughSpan(), 0, length, android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                    }
                } else title
            )
            views.setTextColor(R.id.widget_kanban_item_title, if (isCompleted) palette.onSurfaceMuted else palette.onSurface)

            // Due date (localized by the app; overdue in red) and category.
            if (dateDisplay.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_kanban_item_date, View.VISIBLE)
                views.setTextViewText(R.id.widget_kanban_item_date, dateDisplay)
                views.setTextColor(
                    R.id.widget_kanban_item_date,
                    if (isOverdue && !isCompleted) WidgetStyle.PRIORITY_HIGH else palette.onSurfaceMuted
                )
            } else {
                views.setViewVisibility(R.id.widget_kanban_item_date, View.GONE)
            }
            views.setTextViewText(R.id.widget_kanban_item_category, category)
            views.setTextColor(R.id.widget_kanban_item_category, palette.onSurfaceMuted)
            views.setViewVisibility(R.id.widget_kanban_item_category, if (category.isEmpty()) View.GONE else View.VISIBLE)
            views.setViewVisibility(
                R.id.widget_kanban_item_meta,
                if (dateDisplay.isEmpty() && category.isEmpty()) View.GONE else View.VISIBLE
            )

            // Priority chip: low is the default, only flag medium and high like the app.
            val priorityColor = WidgetStyle.priorityColor(priority)
            if (!isCompleted && priorityColor != null && !priority.equals("low", ignoreCase = true)) {
                views.setViewVisibility(R.id.widget_kanban_badge_box, View.VISIBLE)
                views.setTextViewText(R.id.widget_kanban_item_priority, WidgetStyle.priorityLabel(priority, locale))
                views.setTextColor(R.id.widget_kanban_item_priority, priorityColor)
                WidgetStyle.applyTile(views, R.id.widget_kanban_badge_fill, priorityColor, 0x26)
            } else {
                views.setViewVisibility(R.id.widget_kanban_badge_box, View.GONE)
            }

            // Checkbox
            views.setImageViewResource(
                R.id.widget_kanban_check,
                if (isCompleted) R.drawable.ic_widget_check_on else R.drawable.ic_widget_check_off
            )
            views.setInt(R.id.widget_kanban_check, "setColorFilter", if (isCompleted) palette.primary else palette.onSurfaceMuted)

            if (id.isNotEmpty()) {
                // Row -> task detail; checkbox -> complete / toggle.
                views.setOnClickFillInIntent(
                    R.id.widget_kanban_item_root,
                    Intent().apply { data = Uri.parse("rocistasks://task_detail?id=$id") }
                )
                views.setOnClickFillInIntent(
                    R.id.widget_kanban_check,
                    Intent().apply { data = Uri.parse("rocistasks://complete?id=$id") }
                )
            }
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
