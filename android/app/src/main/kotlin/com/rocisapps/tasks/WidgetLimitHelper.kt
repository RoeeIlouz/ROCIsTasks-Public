package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin

object WidgetLimitHelper {

    val ALL_PROVIDERS = listOf(
        TaskWidgetProvider::class.java,
        FullCalendarWidgetProvider::class.java,
        TodayAgendaWidgetProvider::class.java,
        MonthAgendaWidgetProvider::class.java,
        TimelineAgendaWidgetProvider::class.java,
        QuickActionWidgetProvider::class.java,
        UpNextWidgetProvider::class.java,
        KanbanWidgetProvider::class.java
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
}
