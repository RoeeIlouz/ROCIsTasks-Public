package com.rocisapps.tasks

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

class TaskWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_SORT_CHANGE = "com.rocisapps.tasks.ACTION_SORT_CHANGE"
        const val ACTION_FILTER_CHANGE = "com.rocisapps.tasks.ACTION_FILTER_CHANGE"
        const val PREF_SORT_KEY = "widget_sort_mode" // 0: Date, 1: Priority
        const val PREF_FILTER_KEY = "widget_filter_mode" // 0: All, 1: Today, 2: High, 3: Overdue (Pro), 4: Pinned (Pro)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            try {
                updateWidget(context, appWidgetManager, appWidgetId, widgetData)
            } catch (e: Exception) {
                android.util.Log.e("TaskWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences
    ) {
        val isPremium = widgetData.getBoolean("is_premium", false)
        val isAllowed = WidgetLimitHelper.isWidgetAllowed(context, appWidgetId, isPremium)
        val views = RemoteViews(context.packageName, R.layout.widget_layout)

        // 1. The app's card, tinted icons, RTL.
        val palette = WidgetStyle.palette(context, widgetData)
        val widgetLocale = WidgetLocaleHelper.getWidgetLocale(widgetData)
        WidgetStyle.applyCard(views, palette, R.id.widget_tasklist_card_fill, R.id.widget_tasklist_card_stroke)
        WidgetStyle.applyDirection(views, R.id.widget_tasklist_root, widgetLocale)
        WidgetStyle.tint(views, palette.onSurface, R.id.widget_tasklist_add_btn)
        WidgetStyle.tint(views, palette.primary, R.id.widget_tasklist_empty_icon)
        views.setTextColor(R.id.widget_tasklist_title, palette.onSurface)
        views.setTextColor(R.id.widget_tasklist_count, palette.primary)
        views.setTextColor(R.id.widget_tasklist_empty_title, palette.onSurface)
        views.setTextColor(R.id.widget_tasklist_empty_subtitle, palette.onSurfaceMuted)

        // 2. Header texts and the number of tasks the current filter shows.
        views.setTextViewText(R.id.widget_tasklist_title, WidgetLocaleHelper.getPendingTasksText(widgetLocale))
        views.setTextViewText(R.id.widget_tasklist_empty_title, WidgetLocaleHelper.getNoPendingTasksText(widgetLocale))
        views.setTextViewText(R.id.widget_tasklist_empty_subtitle, WidgetLocaleHelper.getTapPlusToAddText(widgetLocale))
        views.setContentDescription(R.id.widget_tasklist_add_btn, WidgetLocaleHelper.getNewTaskText(widgetLocale))
        val count = try { TaskListData.load(widgetData).size } catch (_: Exception) { 0 }
        views.setTextViewText(R.id.widget_tasklist_count, if (count > 99) "99+" else count.toString())
        views.setViewVisibility(R.id.widget_tasklist_count, if (count > 0) View.VISIBLE else View.GONE)

        // 3. Sort / filter chips.
        updateChips(views, widgetData, palette, widgetLocale)

        if (isAllowed) {
            // Add task
            views.setOnClickPendingIntent(
                R.id.widget_tasklist_add_btn,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://add_task"))
            )

            // List adapter
            val intent = Intent(context, TaskWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse("widget://rocis/task/$appWidgetId")
            }
            views.setRemoteAdapter(R.id.widget_list_view, intent)
            views.setEmptyView(R.id.widget_list_view, R.id.widget_tasklist_empty)

            // Item click template
            val appIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val appPendingIntent = PendingIntent.getActivity(
                context,
                201 + appWidgetId,
                appIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_list_view, appPendingIntent)

            setupChipIntents(context, views, appWidgetId)
        }

        // Apply limit overlay
        WidgetStyle.setupProOverlay(context, views, isAllowed, palette, widgetLocale)

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list_view)
    }

    /** Chips like the FullCalendar filters: a non-default choice is active (accent). */
    private fun updateChips(
        views: RemoteViews,
        prefs: SharedPreferences,
        palette: FullCalendarWidgetUtils.Palette,
        locale: java.util.Locale
    ) {
        val sortMode = TaskListData.sortMode(prefs)
        val filterMode = TaskListData.filterMode(prefs)
        val isPremium = prefs.getBoolean("is_premium", false)

        styleChip(
            views, palette, R.id.widget_tasklist_sort_fill, R.id.widget_tasklist_sort_stroke, R.id.widget_tasklist_sort_text,
            WidgetLocaleHelper.getSortButtonText(sortMode, locale), sortMode != TaskListData.SORT_DATE
        )
        styleChip(
            views, palette, R.id.widget_tasklist_filter_fill, R.id.widget_tasklist_filter_stroke, R.id.widget_tasklist_filter_text,
            WidgetLocaleHelper.getFilterButtonText(filterMode, isPremium, locale), filterMode != 0
        )
    }

    private fun styleChip(
        views: RemoteViews,
        palette: FullCalendarWidgetUtils.Palette,
        fillId: Int,
        strokeId: Int,
        textId: Int,
        label: String,
        active: Boolean
    ) {
        views.setTextViewText(textId, label)
        views.setTextColor(textId, if (active) palette.primary else palette.onSurfaceMuted)
        views.setInt(fillId, "setColorFilter", palette.primary)
        views.setInt(fillId, "setImageAlpha", if (active) 0x26 else 0x00)
        views.setInt(strokeId, "setColorFilter", if (active) palette.primary else palette.onSurface)
        views.setInt(strokeId, "setImageAlpha", if (active) 0x59 else 0x33)
    }

    private fun setupChipIntents(context: Context, views: RemoteViews, appWidgetId: Int) {
        val sortIntent = Intent(context, TaskWidgetProvider::class.java).apply {
            action = ACTION_SORT_CHANGE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val sortPendingIntent = PendingIntent.getBroadcast(
            context, appWidgetId, sortIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_btn_sort, sortPendingIntent)

        val filterIntent = Intent(context, TaskWidgetProvider::class.java).apply {
            action = ACTION_FILTER_CHANGE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val filterPendingIntent = PendingIntent.getBroadcast(
            context, appWidgetId + 10000, filterIntent, // Offset to avoid collision
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_btn_filter, filterPendingIntent)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == ACTION_SORT_CHANGE || action == ACTION_FILTER_CHANGE) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val editor = widgetData.edit()
            val isPremium = widgetData.getBoolean("is_premium", false)

            if (action == ACTION_SORT_CHANGE) {
                val currentSort = TaskListData.sortMode(widgetData)
                editor.putInt(
                    PREF_SORT_KEY,
                    if (currentSort == TaskListData.SORT_DATE) TaskListData.SORT_PRIORITY else TaskListData.SORT_DATE
                )
            } else {
                // Free: All -> Today -> High; Pro adds Overdue and Pinned.
                val currentFilter = TaskListData.filterMode(widgetData)
                val maxFilter = if (isPremium) 5 else 3
                editor.putInt(PREF_FILTER_KEY, (currentFilter + 1) % maxFilter)
            }
            editor.apply()

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, TaskWidgetProvider::class.java))

            // Re-update all widgets to reflect state
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }
}
