package com.example.rocis_tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class TaskWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        android.util.Log.d("TaskWidget", "onUpdate started for ${appWidgetIds.size} widgets")
        appWidgetIds.forEach { appWidgetId ->
            try {
                android.util.Log.d("TaskWidget", "Processing widget ID: $appWidgetId")
                val views = RemoteViews(context.packageName, R.layout.widget_layout)
                android.util.Log.d("TaskWidget", "Created RemoteViews for widget_layout")

                // Set up the intent that starts the TaskWidgetService
                val intent = Intent(context, TaskWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/task/$appWidgetId")
                }
                android.util.Log.d("TaskWidget", "Created service intent with URI: ${intent.data}")

                android.util.Log.d("TaskWidget", "Calling setRemoteAdapter for R.id.widget_list_view")
                views.setRemoteAdapter(R.id.widget_list_view, intent)
                
                android.util.Log.d("TaskWidget", "Calling setEmptyView")
                views.setEmptyView(R.id.widget_list_view, R.id.empty_view)

                // Template for item clicks
                val appIntent = Intent(context, MainActivity::class.java)
                val appPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    201,
                    appIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_list_view, appPendingIntent)
                android.util.Log.d("TaskWidget", "Set PendingIntentTemplate")

                android.util.Log.d("TaskWidget", "Calling updateAppWidget")
                appWidgetManager.updateAppWidget(appWidgetId, views)
                
                android.util.Log.d("TaskWidget", "Calling notifyAppWidgetViewDataChanged")
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_list_view)
                
                android.util.Log.d("TaskWidget", "=== Widget $appWidgetId updated successfully ===")
            } catch (e: Exception) {
                android.util.Log.e("TaskWidget", "=== ERROR updating widget $appWidgetId ===", e)
            }
        }
    }
}
