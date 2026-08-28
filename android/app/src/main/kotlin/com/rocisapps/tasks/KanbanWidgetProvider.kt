package com.rocisapps.tasks

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject

class KanbanWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PREV_COLUMN = "com.rocisapps.tasks.ACTION_KANBAN_PREV_COL"
        const val ACTION_NEXT_COLUMN = "com.rocisapps.tasks.ACTION_KANBAN_NEXT_COL"
        const val ACTION_SELECT_TODO = "com.rocisapps.tasks.ACTION_KANBAN_SELECT_TODO"
        const val ACTION_SELECT_FOCUS = "com.rocisapps.tasks.ACTION_KANBAN_SELECT_FOCUS"
        const val ACTION_SELECT_DONE = "com.rocisapps.tasks.ACTION_KANBAN_SELECT_DONE"

        const val PREF_KANBAN_COLUMN = "kanban_column_index"

        private const val REQ_PREV_COL = 601
        private const val REQ_NEXT_COL = 602
        private const val REQ_TAB_TODO = 603
        private const val REQ_TAB_FOCUS = 604
        private const val REQ_TAB_DONE = 605
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isPremium = widgetData.getBoolean("is_premium", false)

        appWidgetIds.forEach { appWidgetId ->
            try {
                val isAllowed = WidgetLimitHelper.isWidgetAllowed(context, appWidgetId, isPremium)
                val views = RemoteViews(context.packageName, R.layout.widget_kanban_layout)

                // 1. Read Theme Settings
                val theme = widgetData.getString("full_calendar_theme", "system") ?: "system"
                val rootBgRes = when (theme) {
                    "light" -> R.drawable.widget_background_light
                    "dark" -> R.drawable.widget_background_dark
                    "glassmorphic" -> R.drawable.widget_background_glass
                    else -> R.drawable.widget_background
                }
                views.setInt(R.id.widget_kanban_root, "setBackgroundResource", rootBgRes)

                val highlightColorHex = widgetData.getString("full_calendar_highlight_color", "#6366F1") ?: "#6366F1"
                val highlightColor = try {
                    android.graphics.Color.parseColor(highlightColorHex)
                } catch (_: Exception) {
                    android.graphics.Color.parseColor("#6366F1")
                }

                val textColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#0F172A")
                    else -> android.graphics.Color.parseColor("#FFFFFF")
                }
                val secondaryColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#64748B")
                    else -> android.graphics.Color.parseColor("#94A3B8")
                }

                views.setTextColor(R.id.widget_kanban_title, textColor)
                views.setTextColor(R.id.widget_kanban_subtitle, secondaryColor)
                views.setTextColor(R.id.widget_kanban_prev, textColor)
                views.setTextColor(R.id.widget_kanban_next, textColor)
                views.setTextColor(R.id.widget_kanban_add_btn, highlightColor)
                views.setTextColor(R.id.widget_kanban_empty, secondaryColor)

                // 2. Parse Kanban Data & Counts
                val rawJson = widgetData.getString("kanban_data", "{}") ?: "{}"
                val kanbanJson = try {
                    JSONObject(rawJson)
                } catch (_: Exception) {
                    JSONObject()
                }

                val todoList = kanbanJson.optJSONArray("column_todo")
                val focusList = kanbanJson.optJSONArray("column_infocus")
                val doneList = kanbanJson.optJSONArray("column_done")

                val todoCount = todoList?.length() ?: 0
                val focusCount = focusList?.length() ?: 0
                val doneCount = doneList?.length() ?: 0

                val columnIndex = (widgetData.getInt(PREF_KANBAN_COLUMN, 0) % 3 + 3) % 3

                val columnTitle = when (columnIndex) {
                    1 -> "In Focus"
                    2 -> "Done"
                    else -> "To Do"
                }

                val currentCount = when (columnIndex) {
                    1 -> focusCount
                    2 -> doneCount
                    else -> todoCount
                }

                views.setTextViewText(R.id.widget_kanban_title, columnTitle)
                views.setTextViewText(R.id.widget_kanban_subtitle, "Kanban Board • $currentCount tasks")

                // Update Segment Tab Titles with counts
                views.setTextViewText(R.id.widget_kanban_tab_todo, "To Do ($todoCount)")
                views.setTextViewText(R.id.widget_kanban_tab_focus, "In Focus ($focusCount)")
                views.setTextViewText(R.id.widget_kanban_tab_done, "Done ($doneCount)")

                // Active tab pill highlighting
                when (columnIndex) {
                    0 -> {
                        views.setInt(R.id.widget_kanban_tab_todo, "setBackgroundResource", R.drawable.widget_pill_bg)
                        views.setInt(R.id.widget_kanban_tab_focus, "setBackgroundResource", 0)
                        views.setInt(R.id.widget_kanban_tab_done, "setBackgroundResource", 0)
                        views.setTextColor(R.id.widget_kanban_tab_todo, textColor)
                        views.setTextColor(R.id.widget_kanban_tab_focus, secondaryColor)
                        views.setTextColor(R.id.widget_kanban_tab_done, secondaryColor)
                    }
                    1 -> {
                        views.setInt(R.id.widget_kanban_tab_todo, "setBackgroundResource", 0)
                        views.setInt(R.id.widget_kanban_tab_focus, "setBackgroundResource", R.drawable.widget_pill_bg)
                        views.setInt(R.id.widget_kanban_tab_done, "setBackgroundResource", 0)
                        views.setTextColor(R.id.widget_kanban_tab_todo, secondaryColor)
                        views.setTextColor(R.id.widget_kanban_tab_focus, textColor)
                        views.setTextColor(R.id.widget_kanban_tab_done, secondaryColor)
                    }
                    2 -> {
                        views.setInt(R.id.widget_kanban_tab_todo, "setBackgroundResource", 0)
                        views.setInt(R.id.widget_kanban_tab_focus, "setBackgroundResource", 0)
                        views.setInt(R.id.widget_kanban_tab_done, "setBackgroundResource", R.drawable.widget_pill_bg)
                        views.setTextColor(R.id.widget_kanban_tab_todo, secondaryColor)
                        views.setTextColor(R.id.widget_kanban_tab_focus, secondaryColor)
                        views.setTextColor(R.id.widget_kanban_tab_done, textColor)
                    }
                }

                // 3. Navigation Pending Intents
                val prevIntent = Intent(context, KanbanWidgetProvider::class.java).apply {
                    action = ACTION_PREV_COLUMN
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_kanban_prev,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_PREV_COL,
                        prevIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val nextIntent = Intent(context, KanbanWidgetProvider::class.java).apply {
                    action = ACTION_NEXT_COLUMN
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_kanban_next,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_NEXT_COL,
                        nextIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val tabTodoIntent = Intent(context, KanbanWidgetProvider::class.java).apply {
                    action = ACTION_SELECT_TODO
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_kanban_tab_todo,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_TAB_TODO,
                        tabTodoIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val tabFocusIntent = Intent(context, KanbanWidgetProvider::class.java).apply {
                    action = ACTION_SELECT_FOCUS
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_kanban_tab_focus,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_TAB_FOCUS,
                        tabFocusIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val tabDoneIntent = Intent(context, KanbanWidgetProvider::class.java).apply {
                    action = ACTION_SELECT_DONE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_kanban_tab_done,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_TAB_DONE,
                        tabDoneIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                // 4. Header Click to open Kanban screen & Add Task Button
                val openKanbanPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://open_kanban")
                )
                views.setOnClickPendingIntent(R.id.widget_kanban_title_container, openKanbanPendingIntent)

                val addTaskPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://add_task")
                )
                views.setOnClickPendingIntent(R.id.widget_kanban_add_btn, addTaskPendingIntent)

                // 5. RemoteViewsService for ListView
                val serviceIntent = Intent(context, KanbanWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/kanban/$appWidgetId/$columnIndex")
                }
                views.setRemoteAdapter(R.id.widget_kanban_list, serviceIntent)
                views.setEmptyView(R.id.widget_kanban_list, R.id.widget_kanban_empty)

                // 6. Template PendingIntent for list item actions
                val itemAppIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val itemPendingIntent = PendingIntent.getActivity(
                    context,
                    650 + appWidgetId,
                    itemAppIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_kanban_list, itemPendingIntent)

                // Apply limit overlay
                WidgetLimitHelper.setupProOverlay(context, views, isAllowed)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_kanban_list)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_kanban_list)
                    } catch (_: Exception) {}
                }, 300)
            } catch (e: Exception) {
                android.util.Log.e("KanbanWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action

        if (action == ACTION_PREV_COLUMN || action == ACTION_NEXT_COLUMN ||
            action == ACTION_SELECT_TODO || action == ACTION_SELECT_FOCUS || action == ACTION_SELECT_DONE
        ) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val currentIndex = widgetData.getInt(PREF_KANBAN_COLUMN, 0)

            when (action) {
                ACTION_PREV_COLUMN -> {
                    val newIndex = (currentIndex - 1 + 3) % 3
                    widgetData.edit().putInt(PREF_KANBAN_COLUMN, newIndex).apply()
                }
                ACTION_NEXT_COLUMN -> {
                    val newIndex = (currentIndex + 1) % 3
                    widgetData.edit().putInt(PREF_KANBAN_COLUMN, newIndex).apply()
                }
                ACTION_SELECT_TODO -> {
                    widgetData.edit().putInt(PREF_KANBAN_COLUMN, 0).apply()
                }
                ACTION_SELECT_FOCUS -> {
                    widgetData.edit().putInt(PREF_KANBAN_COLUMN, 1).apply()
                }
                ACTION_SELECT_DONE -> {
                    widgetData.edit().putInt(PREF_KANBAN_COLUMN, 2).apply()
                }
            }

            // Sync with Dart background handler
            try {
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("rocistasks://kanban_sync")
                )
                backgroundIntent.send()
            } catch (_: Exception) {}

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, KanbanWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, ids, widgetData)
        }
    }
}
