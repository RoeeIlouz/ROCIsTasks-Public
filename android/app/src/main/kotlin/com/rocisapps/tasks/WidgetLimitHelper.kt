package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin

object WidgetLimitHelper {

    val ALL_PROVIDERS = listOf(
        TaskWidgetProvider::class.java,
        FullCalendarWidgetProvider::class.java,
        TodayAgendaWidgetProvider::class.java,
        MonthAgendaWidgetProvider::class.java,
        TimelineAgendaWidgetProvider::class.java,
        QuickActionWidgetProvider::class.java,
        UpNextWidgetProvider::class.java
    )

    /**
     * Determines whether the given widget ID is allowed to render.
     * Pro users can have unlimited widgets.
     * Free users are permitted 1 active home screen widget.
     */
    fun isWidgetAllowed(context: Context, appWidgetId: Int, isPremium: Boolean): Boolean {
        if (isPremium) return true

        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val allActiveIds = mutableListOf<Int>()
            for (providerClass in ALL_PROVIDERS) {
                try {
                    val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, providerClass))
                    allActiveIds.addAll(ids.toList())
                } catch (_: Exception) {}
            }

            if (allActiveIds.size <= 1) return true

            val widgetData = HomeWidgetPlugin.getData(context)
            var primaryId = widgetData.getInt("primary_active_widget_id", -1)

            if (primaryId == -1 || !allActiveIds.contains(primaryId)) {
                primaryId = allActiveIds.first()
                widgetData.edit().putInt("primary_active_widget_id", primaryId).apply()
            }

            return appWidgetId == primaryId
        } catch (e: Exception) {
            return true
        }
    }

    /**
     * Helper to show or hide the Pro Upgrade overlay on the widget.
     */
    fun setupProOverlay(context: Context, views: RemoteViews, isAllowed: Boolean) {
        try {
            if (isAllowed) {
                views.setViewVisibility(R.id.widget_pro_overlay, View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_pro_overlay, View.VISIBLE)
                val paywallIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://paywall")
                )
                views.setOnClickPendingIntent(R.id.widget_pro_overlay_btn, paywallIntent)
                views.setOnClickPendingIntent(R.id.widget_pro_overlay, paywallIntent)
            }
        } catch (_: Exception) {}
    }
}
