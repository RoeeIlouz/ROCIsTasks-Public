package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class MonthWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_month_layout)
                
                // Navigation Buttons (Background Intents)
                val prevIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("rocistasks://prev_month")
                )
                views.setOnClickPendingIntent(R.id.widget_prev_month, prevIntent)

                val nextIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse("rocistasks://next_month")
                )
                views.setOnClickPendingIntent(R.id.widget_next_month, nextIntent)

                // Month Title
                val monthName = widgetData.getString("month_name", "Calendar")
                views.setTextViewText(R.id.widget_month_title, monthName)

                // Grid Adapter
                val intent = Intent(context, MonthWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME) + "?id=" + appWidgetId)
                }
                views.setRemoteAdapter(R.id.widget_month_grid, intent)

                // Item Click Template
                val appIntent = Intent(context, MainActivity::class.java)
                val appPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    401,
                    appIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_month_grid, appPendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_month_grid)
            } catch (e: Exception) {
            }
        }
    }
}
