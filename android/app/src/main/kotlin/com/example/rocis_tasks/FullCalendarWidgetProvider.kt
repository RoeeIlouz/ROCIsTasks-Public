package com.example.rocis_tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class FullCalendarWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        android.util.Log.d("FullCalendarWidget", "onUpdate started for ${appWidgetIds.size} widgets")
        
        appWidgetIds.forEach { appWidgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_full_calendar_layout)

                // 1. Title Update
                val monthName = widgetData.getString("full_calendar_month_name", "Calendar")
                views.setTextViewText(R.id.widget_full_calendar_title, monthName)

                // 2. Navigation Buttons
                val prevIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("rocistasks://full_calendar_prev")
                )
                views.setOnClickPendingIntent(R.id.widget_full_calendar_prev, prevIntent)

                val nextIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("rocistasks://full_calendar_next")
                )
                views.setOnClickPendingIntent(R.id.widget_full_calendar_next, nextIntent)

                // 3. Add Task Button
                val addTaskIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("rocistasks://add_task")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val addTaskPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    102, // Unique request code for Add Task
                    addTaskIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_add_task_btn, addTaskPendingIntent)

                // 4. List Adapter
                val serviceIntent = Intent(context, FullCalendarWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/full_calendar/$appWidgetId")
                }
                views.setRemoteAdapter(R.id.widget_full_calendar_list, serviceIntent)
                views.setEmptyView(R.id.widget_full_calendar_list, R.id.empty_full_calendar_view)

                val appIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val appPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    100, // Request code for calendar row template
                    appIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_full_calendar_list, appPendingIntent)

                // 5. Finalize Update
                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_full_calendar_list)
                android.util.Log.d("FullCalendarWidget", "Widget $appWidgetId updated successfully")
            } catch (e: Exception) {
                android.util.Log.e("FullCalendarWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }
}
