package com.rocisapps.tasks

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TimelineAgendaWidgetProvider : HomeWidgetProvider() {

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
                val views = RemoteViews(context.packageName, R.layout.widget_timeline_agenda_layout)

                val theme = widgetData.getString("full_calendar_theme", "system") ?: "system"
                val rootBgRes = when (theme) {
                    "light" -> R.drawable.widget_background_light
                    "dark" -> R.drawable.widget_background_dark
                    "glassmorphic" -> R.drawable.widget_background_glass
                    else -> R.drawable.widget_background
                }
                views.setInt(R.id.widget_timeline_root, "setBackgroundResource", rootBgRes)

                val textColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#1C1C1E")
                    "dark", "glassmorphic" -> android.graphics.Color.parseColor("#FFFFFF")
                    else -> context.getColor(R.color.widget_title_text)
                }
                views.setTextColor(R.id.widget_timeline_title, textColor)

                // Add Task Button
                val addIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://add_task")
                )
                views.setOnClickPendingIntent(R.id.widget_timeline_add_btn, addIntent)

                // Open Calendar Button
                val calIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://calendar")
                )
                views.setOnClickPendingIntent(R.id.widget_timeline_today_btn, calIntent)

                // ListView Adapter - Always configure adapter
                val serviceIntent = Intent(context, TimelineAgendaWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/timeline_agenda/$appWidgetId")
                }
                views.setRemoteAdapter(R.id.widget_timeline_list, serviceIntent)
                views.setEmptyView(R.id.widget_timeline_list, R.id.widget_timeline_empty)

                // Item Click Template
                val itemAppIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val itemPendingIntent = PendingIntent.getActivity(
                    context,
                    800 + appWidgetId,
                    itemAppIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_timeline_list, itemPendingIntent)

                // Pro limit overlay
                WidgetLimitHelper.setupProOverlay(context, views, isAllowed)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                if (isAllowed) {
                    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_timeline_list)
                }
            } catch (e: Exception) {
                android.util.Log.e("TimelineAgendaWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }
}
