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
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

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

                // 1. The app's card, tinted icons, RTL.
                val palette = WidgetStyle.palette(context, widgetData)
                val widgetLocale = WidgetLocaleHelper.getWidgetLocale(widgetData)
                WidgetStyle.applyCard(views, palette, R.id.widget_timeline_card_fill, R.id.widget_timeline_card_stroke)
                WidgetStyle.applyDirection(views, R.id.widget_timeline_root, widgetLocale)
                WidgetStyle.tint(views, palette.onSurface, R.id.widget_timeline_today_btn, R.id.widget_timeline_add_btn)
                WidgetStyle.tint(views, palette.primary, R.id.widget_timeline_empty_icon)
                views.setTextColor(R.id.widget_timeline_header_title, palette.onSurface)
                views.setTextColor(R.id.widget_timeline_empty_title, palette.onSurface)
                views.setTextColor(R.id.widget_timeline_empty_subtitle, palette.onSurfaceMuted)

                // 2. Header: title opens the calendar, "today" opens it on today, + adds a task.
                views.setTextViewText(R.id.widget_timeline_header_title, WidgetLocaleHelper.getScheduleTimelineText(widgetLocale))
                views.setContentDescription(R.id.widget_timeline_today_btn, WidgetLocaleHelper.getTodayText(widgetLocale))
                views.setContentDescription(R.id.widget_timeline_add_btn, WidgetLocaleHelper.getNewTaskText(widgetLocale))

                val todayKey = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
                views.setOnClickPendingIntent(
                    R.id.widget_timeline_header_title,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://calendar"))
                )
                views.setOnClickPendingIntent(
                    R.id.widget_timeline_today_btn,
                    HomeWidgetLaunchIntent.getActivity(
                        context, MainActivity::class.java, Uri.parse("rocistasks://calendar?date=$todayKey")
                    )
                )
                views.setOnClickPendingIntent(
                    R.id.widget_timeline_add_btn,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://add_task"))
                )

                // 3. RemoteViewsService for the ListView (always configured).
                val serviceIntent = Intent(context, TimelineAgendaWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/timeline_agenda/$appWidgetId")
                }
                views.setRemoteAdapter(R.id.widget_timeline_list, serviceIntent)
                views.setTextViewText(R.id.widget_timeline_empty_title, WidgetLocaleHelper.getNoTasksOrEventsText(widgetLocale))
                views.setTextViewText(R.id.widget_timeline_empty_subtitle, WidgetLocaleHelper.getTapPlusToAddText(widgetLocale))
                views.setEmptyView(R.id.widget_timeline_list, R.id.widget_timeline_empty)

                // 4. Template PendingIntent for list rows and day sections.
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

                // Apply limit overlay
                WidgetStyle.setupProOverlay(context, views, isAllowed, palette, widgetLocale)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_timeline_list)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_timeline_list)
                    } catch (_: Exception) {}
                }, 300)
            } catch (e: Exception) {
                android.util.Log.e("TimelineAgendaWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }
}
