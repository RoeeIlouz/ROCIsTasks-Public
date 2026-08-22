package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class UpNextWidgetProvider : HomeWidgetProvider() {

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
                val views = RemoteViews(context.packageName, R.layout.widget_up_next_layout)

                val theme = widgetData.getString("full_calendar_theme", "system") ?: "system"
                val rootBgRes = when (theme) {
                    "light" -> R.drawable.widget_background_light
                    "dark" -> R.drawable.widget_background_dark
                    "glassmorphic" -> R.drawable.widget_background_glass
                    else -> R.drawable.widget_background
                }
                views.setInt(R.id.widget_up_next_root, "setBackgroundResource", rootBgRes)

                val textColor = when (theme) {
                    "light" -> Color.parseColor("#0F172A")
                    else -> Color.parseColor("#FFFFFF")
                }
                val secondaryColor = when (theme) {
                    "light" -> Color.parseColor("#64748B")
                    else -> Color.parseColor("#94A3B8")
                }

                views.setTextColor(R.id.widget_up_next_title, textColor)
                views.setTextColor(R.id.widget_up_next_subtitle, secondaryColor)

                val type = widgetData.getString("up_next_type", "task") ?: "task"
                val id = widgetData.getString("up_next_id", "") ?: ""
                val title = widgetData.getString("up_next_title", "No upcoming tasks") ?: "No upcoming tasks"
                val subtitle = widgetData.getString("up_next_subtitle", "") ?: ""
                val timeDisplay = widgetData.getString("up_next_time_display", "All caught up") ?: "All caught up"
                val colorHex = widgetData.getString("up_next_color", "") ?: ""

                views.setTextViewText(R.id.widget_up_next_title, title)
                views.setTextViewText(R.id.widget_up_next_subtitle, subtitle)
                views.setTextViewText(R.id.widget_up_next_time_badge, timeDisplay)

                if (colorHex.isNotEmpty() && colorHex.startsWith("#")) {
                    try {
                        val color = Color.parseColor(colorHex)
                        views.setInt(R.id.widget_up_next_color_strip, "setBackgroundColor", color)
                        views.setViewVisibility(R.id.widget_up_next_color_strip, View.VISIBLE)
                    } catch (_: Exception) {
                        views.setViewVisibility(R.id.widget_up_next_color_strip, View.INVISIBLE)
                    }
                } else {
                    views.setViewVisibility(R.id.widget_up_next_color_strip, View.INVISIBLE)
                }

                if (type == "task" && id.isNotEmpty()) {
                    views.setViewVisibility(R.id.widget_up_next_check, View.VISIBLE)
                    views.setViewVisibility(R.id.widget_up_next_event_icon, View.GONE)

                    val checkIntent = HomeWidgetBackgroundIntent.getBroadcast(
                        context,
                        Uri.parse("rocistasks://complete?id=$id")
                    )
                    views.setOnClickPendingIntent(R.id.widget_up_next_check, checkIntent)

                    val itemIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("rocistasks://task_item?id=$id")
                    )
                    views.setOnClickPendingIntent(R.id.widget_up_next_main, itemIntent)
                } else if (type == "event") {
                    views.setViewVisibility(R.id.widget_up_next_check, View.GONE)
                    views.setViewVisibility(R.id.widget_up_next_event_icon, View.VISIBLE)

                    val itemIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("rocistasks://calendar")
                    )
                    views.setOnClickPendingIntent(R.id.widget_up_next_main, itemIntent)
                } else {
                    views.setViewVisibility(R.id.widget_up_next_check, View.GONE)
                    views.setViewVisibility(R.id.widget_up_next_event_icon, View.GONE)

                    val homeIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("rocistasks://home")
                    )
                    views.setOnClickPendingIntent(R.id.widget_up_next_main, homeIntent)
                }

                // Pro limit overlay
                WidgetLimitHelper.setupProOverlay(context, views, isAllowed)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                android.util.Log.e("UpNextWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }
}
