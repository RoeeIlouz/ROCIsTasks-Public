package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TaskWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_SORT_CHANGE = "com.rocisapps.tasks.ACTION_SORT_CHANGE"
        const val ACTION_FILTER_CHANGE = "com.rocisapps.tasks.ACTION_FILTER_CHANGE"
        const val PREF_SORT_KEY = "widget_sort_mode" // 0: Date, 1: Priority
        const val PREF_FILTER_KEY = "widget_filter_mode" // 0: All, 1: Today, 2: High Priority
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

        WidgetLimitHelper.setupProOverlay(context, views, isAllowed)

        if (isAllowed) {
            // Setup List Adapter
            val intent = Intent(context, TaskWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse("widget://rocis/task/$appWidgetId")
            }
            val widgetLocale = WidgetLocaleHelper.getWidgetLocale(widgetData)
            views.setTextViewText(R.id.widget_title, WidgetLocaleHelper.getPendingTasksText(widgetLocale))
            views.setTextViewText(R.id.empty_view, WidgetLocaleHelper.getNoPendingTasksText(widgetLocale))
            views.setRemoteAdapter(R.id.widget_list_view, intent)
            views.setEmptyView(R.id.widget_list_view, R.id.empty_view)

            // Setup Item Click Template
            val appIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val appPendingIntent = android.app.PendingIntent.getActivity(
                context,
                201 + appWidgetId,
                appIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_list_view, appPendingIntent)

            // Setup Sort/Filter Buttons
            updateButtonState(views, widgetData)
            setupButtonIntents(context, views, appWidgetId)
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list_view)
    }

    private fun updateButtonState(views: RemoteViews, prefs: SharedPreferences) {
        val sortMode = prefs.getInt(PREF_SORT_KEY, 0)
        val filterMode = prefs.getInt(PREF_FILTER_KEY, 0)
        val isPremium = prefs.getBoolean("is_premium", false)
        val widgetLocale = WidgetLocaleHelper.getWidgetLocale(prefs)

        val sortText = WidgetLocaleHelper.getSortButtonText(sortMode, widgetLocale)
        val filterText = WidgetLocaleHelper.getFilterButtonText(filterMode, isPremium, widgetLocale)

        views.setTextViewText(R.id.widget_btn_sort, sortText)
        views.setTextViewText(R.id.widget_btn_filter, filterText)
    }

    private fun setupButtonIntents(context: Context, views: RemoteViews, appWidgetId: Int) {
        val sortIntent = Intent(context, TaskWidgetProvider::class.java).apply {
            action = ACTION_SORT_CHANGE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            // Need URI to distinguish intents for different widgets/actions if needed, 
            // but for broadcast usually unique action/request code is enough.
            // However, request code must be unique per pending intent.
        }
        val sortPendingIntent = android.app.PendingIntent.getBroadcast(
            context, appWidgetId, sortIntent, 
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_btn_sort, sortPendingIntent)

        val filterIntent = Intent(context, TaskWidgetProvider::class.java).apply {
            action = ACTION_FILTER_CHANGE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val filterPendingIntent = android.app.PendingIntent.getBroadcast(
            context, appWidgetId + 10000, filterIntent, // Offset to avoid collision
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_btn_filter, filterPendingIntent)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == ACTION_SORT_CHANGE || action == ACTION_FILTER_CHANGE) {
            val widgetData = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            val editor = widgetData.edit()
            val isPremium = widgetData.getBoolean("is_premium", false)

            if (action == ACTION_SORT_CHANGE) {
                val currentSort = widgetData.getInt(PREF_SORT_KEY, 0)
                editor.putInt(PREF_SORT_KEY, if (currentSort == 0) 1 else 0)
            } else if (action == ACTION_FILTER_CHANGE) {
                val currentFilter = widgetData.getInt(PREF_FILTER_KEY, 0)
                val maxFilter = if (isPremium) 5 else 3
                val nextFilter = (currentFilter + 1) % maxFilter
                editor.putInt(PREF_FILTER_KEY, nextFilter)
            }
            editor.apply()

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = android.content.ComponentName(context, TaskWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            
            // Re-update all widgets to reflect state
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }
}
