package com.example.rocis_tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class CalendarWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        android.util.Log.d("CalendarWidget", "onUpdate started for ${appWidgetIds.size} widgets")
        appWidgetIds.forEach { appWidgetId ->
            try {
                android.util.Log.d("CalendarWidget", "Updating widget ID: $appWidgetId")
                val views = RemoteViews(context.packageName, R.layout.widget_calendar_layout)

                // Set up the intent that starts the CalendarWidgetService
                val intent = android.content.Intent(context, CalendarWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = android.net.Uri.parse(
                        toUri(android.content.Intent.URI_INTENT_SCHEME) + "?id=" + appWidgetId
                    )
                }

                // Update header with Date and Week Number
                try {
                    val now = java.time.LocalDate.now()
                    val formatter = java.time.format.DateTimeFormatter.ofPattern("EEE, MMM d")
                    val dateText = now.format(formatter)
                    val weekFields = java.time.temporal.WeekFields.of(java.util.Locale.getDefault())
                    val weekNumber = now.get(weekFields.weekOfWeekBasedYear())
                    
                    val weekLabel = if (context.resources.configuration.locales[0].language == "he") "שבוע" else "Week"
                    views.setTextViewText(R.id.widget_calendar_title, "$weekLabel $weekNumber • $dateText")
                } catch (e: Exception) {
                    android.util.Log.e("CalendarWidget", "Error updating header", e)
                }

                // Bind the remote adapter
                views.setRemoteAdapter(R.id.widget_calendar_list_view, intent)
                views.setEmptyView(R.id.widget_calendar_list_view, R.id.empty_calendar_view)

                // PendingIntent Template for Interactivity (Opening App)
                val appIntent = android.content.Intent(context, MainActivity::class.java)
                val appPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    501,
                    appIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_calendar_list_view, appPendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_calendar_list_view)
                android.util.Log.d("CalendarWidget", "Widget ID $appWidgetId update finished")
            } catch (e: Exception) {
                android.util.Log.e("CalendarWidget", "Error in onUpdate for ID $appWidgetId", e)
            }
        }
    }
}
