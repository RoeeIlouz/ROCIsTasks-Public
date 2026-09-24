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

                // 1. The app's card, tinted icons, RTL.
                val palette = WidgetStyle.palette(context, widgetData)
                val widgetLocale = WidgetLocaleHelper.getWidgetLocale(widgetData)
                WidgetStyle.applyCard(views, palette, R.id.widget_kanban_card_fill, R.id.widget_kanban_card_stroke)
                WidgetStyle.applyDirection(views, R.id.widget_kanban_root, widgetLocale)
                WidgetStyle.tint(views, palette.onSurface, R.id.widget_kanban_prev, R.id.widget_kanban_next, R.id.widget_kanban_add_btn)
                views.setTextColor(R.id.widget_kanban_title, palette.onSurface)
                views.setTextColor(R.id.widget_kanban_subtitle, palette.onSurfaceMuted)
                views.setTextColor(R.id.widget_kanban_empty_title, palette.onSurface)
                views.setTextColor(R.id.widget_kanban_empty_subtitle, palette.onSurfaceMuted)
                WidgetStyle.tint(views, palette.primary, R.id.widget_kanban_empty_icon)

                // 2. Parse Kanban Data & Counts
                val rawJson = widgetData.getString("kanban_data", "{}") ?: "{}"
                val kanbanJson = try {
                    JSONObject(rawJson)
                } catch (_: Exception) {
                    JSONObject()
                }

                val todoCount = kanbanJson.optJSONArray("column_todo")?.length() ?: 0
                val focusCount = kanbanJson.optJSONArray("column_infocus")?.length() ?: 0
                val doneCount = kanbanJson.optJSONArray("column_done")?.length() ?: 0

                val columnIndex = (widgetData.getInt(PREF_KANBAN_COLUMN, 0) % 3 + 3) % 3

                val currentCount = when (columnIndex) {
                    1 -> focusCount
                    2 -> doneCount
                    else -> todoCount
                }

                views.setTextViewText(R.id.widget_kanban_title, WidgetLocaleHelper.getKanbanColumnTitle(columnIndex, widgetLocale))
                views.setTextViewText(R.id.widget_kanban_subtitle, WidgetLocaleHelper.getKanbanSubtitle(currentCount, widgetLocale))

                // Column chips (like the Full Calendar filters): active = 15% accent fill,
                // 35% accent border and accent text; others an outlined muted chip.
                val chips = listOf(
                    ColumnChip(R.id.widget_kanban_tab_todo_fill, R.id.widget_kanban_tab_todo_stroke,
                        R.id.widget_kanban_tab_todo_text, R.id.widget_kanban_tab_todo_count,
                        WidgetLocaleHelper.getKanbanTodoTitle(widgetLocale), todoCount, columnIndex == 0),
                    ColumnChip(R.id.widget_kanban_tab_focus_fill, R.id.widget_kanban_tab_focus_stroke,
                        R.id.widget_kanban_tab_focus_text, R.id.widget_kanban_tab_focus_count,
                        WidgetLocaleHelper.getKanbanFocusTitle(widgetLocale), focusCount, columnIndex == 1),
                    ColumnChip(R.id.widget_kanban_tab_done_fill, R.id.widget_kanban_tab_done_stroke,
                        R.id.widget_kanban_tab_done_text, R.id.widget_kanban_tab_done_count,
                        WidgetLocaleHelper.getKanbanDoneTitle(widgetLocale), doneCount, columnIndex == 2)
                )
                for (chip in chips) {
                    val textColor = if (chip.active) palette.primary else palette.onSurfaceMuted
                    views.setTextViewText(chip.text, chip.label)
                    views.setTextColor(chip.text, textColor)
                    views.setTextViewText(chip.countView, if (chip.count > 99) "99+" else "${chip.count}")
                    views.setTextColor(chip.countView, textColor)
                    views.setInt(chip.fill, "setColorFilter", palette.primary)
                    views.setInt(chip.fill, "setImageAlpha", if (chip.active) 0x26 else 0x00)
                    views.setInt(chip.stroke, "setColorFilter", if (chip.active) palette.primary else palette.onSurface)
                    views.setInt(chip.stroke, "setImageAlpha", if (chip.active) 0x59 else 0x33)
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
                views.setTextViewText(R.id.widget_kanban_empty_title, WidgetLocaleHelper.getNoTasksInColumnText(widgetLocale))
                views.setTextViewText(R.id.widget_kanban_empty_subtitle, WidgetLocaleHelper.getTapPlusToAddText(widgetLocale))
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
                WidgetStyle.setupProOverlay(context, views, isAllowed, palette, widgetLocale)

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

    private data class ColumnChip(
        val fill: Int,
        val stroke: Int,
        val text: Int,
        val countView: Int,
        val label: String,
        val count: Int,
        val active: Boolean
    )

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
