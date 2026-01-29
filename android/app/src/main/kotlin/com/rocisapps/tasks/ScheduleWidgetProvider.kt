package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class ScheduleWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_schedule_layout)

                // Set up the intent that starts the ScheduleWidgetService
                val intent = Intent(context, ScheduleWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/schedule/$appWidgetId")
                }

                views.setRemoteAdapter(R.id.widget_schedule_list, intent)
                views.setEmptyView(R.id.widget_schedule_list, R.id.empty_schedule_view)

                // Template for item clicks
                val appIntent = Intent(context, MainActivity::class.java)
                val appPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    301,
                    appIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_schedule_list, appPendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_schedule_list)
            } catch (e: Exception) {
            }
        }
    }
}
