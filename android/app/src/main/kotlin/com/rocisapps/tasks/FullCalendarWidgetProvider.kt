package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class FullCalendarWidgetProvider : HomeWidgetProvider() {

    companion object {
        // Filter toggle actions
        const val ACTION_FILTER_TASKS = "com.rocisapps.tasks.ACTION_FILTER_TASKS"
        const val ACTION_FILTER_GOOGLE = "com.rocisapps.tasks.ACTION_FILTER_GOOGLE"
        const val ACTION_FILTER_ROCIS = "com.rocisapps.tasks.ACTION_FILTER_ROCIS"
        
        // Preference keys
        const val PREF_SHOW_TASKS = "full_calendar_show_tasks"
        const val PREF_SHOW_GOOGLE = "full_calendar_show_google"
        const val PREF_SHOW_ROCIS = "full_calendar_show_rocis"
        const val PREF_OFFSET = "full_calendar_offset"
        
        // Unique request codes
        private const val REQUEST_CODE_FILTER_TASKS = 301
        private const val REQUEST_CODE_FILTER_GOOGLE = 302
        private const val REQUEST_CODE_FILTER_ROCIS = 303
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        
        appWidgetIds.forEach { appWidgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_full_calendar_layout)

                // 1. Title Update
                val monthName = widgetData.getString("full_calendar_month_name", "Calendar")
                views.setTextViewText(R.id.widget_full_calendar_title, monthName)

                // 2. Navigation Buttons - use direct background intent
                val prevIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("rocistasks://full_calendar_prev")
                )
                views.setOnClickPendingIntent(R.id.widget_full_calendar_prev, prevIntent)

                val nextIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("rocistasks://full_calendar_next")
                )
                views.setOnClickPendingIntent(R.id.widget_full_calendar_next, nextIntent)

                // 3. Add Task Button - Use HomeWidgetLaunchIntent for proper Flutter handling
                val addTaskPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://add_task")
                )
                views.setOnClickPendingIntent(R.id.widget_add_task_btn, addTaskPendingIntent)

                // 4. Filter Buttons - read state and setup click handlers
                val showTasks = widgetData.getBoolean(PREF_SHOW_TASKS, true)
                val showGoogle = widgetData.getBoolean(PREF_SHOW_GOOGLE, true)
                val showRocis = widgetData.getBoolean(PREF_SHOW_ROCIS, true)

                // Update filter button appearance based on state (alpha for enabled/disabled)
                // Tasks filter
                views.setFloat(R.id.widget_filter_tasks, "setAlpha", if (showTasks) 1.0f else 0.4f)

                // Google filter
                views.setFloat(R.id.widget_filter_google, "setAlpha", if (showGoogle) 1.0f else 0.4f)

                // ROCIs Schedule filter
                views.setFloat(R.id.widget_filter_rocis, "setAlpha", if (showRocis) 1.0f else 0.4f)

                // Filter button click handlers - broadcast to this widget provider
                setupFilterButtonIntents(context, views, appWidgetId)

                // 5. List Adapter
                val serviceIntent = Intent(context, FullCalendarWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/full_calendar/$appWidgetId")
                }
                views.setRemoteAdapter(R.id.widget_full_calendar_list, serviceIntent)
                views.setEmptyView(R.id.widget_full_calendar_list, R.id.empty_full_calendar_view)

                // Use a mutable PendingIntent template that can be combined with fill-in intents
                // The fill-in intent will provide the specific date URI
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val appPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    100 + appWidgetId, // Unique request code per widget
                    appIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_full_calendar_list, appPendingIntent)

                // 6. Finalize Update
                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_full_calendar_list)
            } catch (e: Exception) {
            }
        }
    }

    private fun setupFilterButtonIntents(context: Context, views: RemoteViews, appWidgetId: Int) {
        // Tasks filter button
        val filterTasksIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
            action = ACTION_FILTER_TASKS
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val filterTasksPendingIntent = android.app.PendingIntent.getBroadcast(
            context, REQUEST_CODE_FILTER_TASKS, filterTasksIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_filter_tasks, filterTasksPendingIntent)

        // Google filter button
        val filterGoogleIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
            action = ACTION_FILTER_GOOGLE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val filterGooglePendingIntent = android.app.PendingIntent.getBroadcast(
            context, REQUEST_CODE_FILTER_GOOGLE, filterGoogleIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_filter_google, filterGooglePendingIntent)

        // ROCIs Schedule filter button
        val filterRocisIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
            action = ACTION_FILTER_ROCIS
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val filterRocisPendingIntent = android.app.PendingIntent.getBroadcast(
            context, REQUEST_CODE_FILTER_ROCIS, filterRocisIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_filter_rocis, filterRocisPendingIntent)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        
        if (action == ACTION_FILTER_TASKS || action == ACTION_FILTER_GOOGLE || action == ACTION_FILTER_ROCIS) {
            
            val widgetData = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            val editor = widgetData.edit()
            
            when (action) {
                ACTION_FILTER_TASKS -> {
                    val current = widgetData.getBoolean(PREF_SHOW_TASKS, true)
                    editor.putBoolean(PREF_SHOW_TASKS, !current)
                }
                ACTION_FILTER_GOOGLE -> {
                    val current = widgetData.getBoolean(PREF_SHOW_GOOGLE, true)
                    editor.putBoolean(PREF_SHOW_GOOGLE, !current)
                }
                ACTION_FILTER_ROCIS -> {
                    val current = widgetData.getBoolean(PREF_SHOW_ROCIS, true)
                    editor.putBoolean(PREF_SHOW_ROCIS, !current)
                }
            }
            editor.apply()
            
            // Update all widgets to reflect the new filter state
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = android.content.ComponentName(context, FullCalendarWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }
}
