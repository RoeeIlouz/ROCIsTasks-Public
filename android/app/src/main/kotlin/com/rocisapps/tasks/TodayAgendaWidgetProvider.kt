package com.rocisapps.tasks

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class TodayAgendaWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PREV_DAY = "com.rocisapps.tasks.ACTION_TODAY_PREV_DAY"
        const val ACTION_NEXT_DAY = "com.rocisapps.tasks.ACTION_TODAY_NEXT_DAY"
        const val ACTION_JUMP_TODAY = "com.rocisapps.tasks.ACTION_TODAY_JUMP_TODAY"
        const val ACTION_COMPLETE_TASK = "com.rocisapps.tasks.ACTION_TODAY_COMPLETE_TASK"

        const val PREF_TODAY_OFFSET = "today_agenda_offset"

        private const val REQ_PREV_DAY = 501
        private const val REQ_NEXT_DAY = 502
        private const val REQ_JUMP_TODAY = 503
    }

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
                val views = RemoteViews(context.packageName, R.layout.widget_today_agenda_layout)

                // 1. Read Theme Settings
                val theme = widgetData.getString("full_calendar_theme", "system") ?: "system"
                val rootBgRes = when (theme) {
                    "light" -> R.drawable.widget_background_light
                    "dark" -> R.drawable.widget_background_dark
                    "glassmorphic" -> R.drawable.widget_background_glass
                    else -> R.drawable.widget_background
                }
                views.setInt(R.id.widget_today_root, "setBackgroundResource", rootBgRes)

                val textColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#1C1C1E")
                    "dark", "glassmorphic" -> android.graphics.Color.parseColor("#FFFFFF")
                    else -> context.getColor(R.color.widget_title_text)
                }
                val secondaryColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#8E8E93")
                    "dark", "glassmorphic" -> android.graphics.Color.parseColor("#AEAEB2")
                    else -> context.getColor(R.color.widget_secondary_text)
                }

                views.setTextColor(R.id.widget_today_date_title, textColor)
                views.setTextColor(R.id.widget_today_date_subtitle, secondaryColor)
                views.setTextColor(R.id.widget_today_prev, textColor)
                views.setTextColor(R.id.widget_today_next, textColor)

                // 2. Calculate and Render Date Headers
                val offset = widgetData.getInt(PREF_TODAY_OFFSET, 0)
                val cal = Calendar.getInstance()
                if (offset != 0) {
                    cal.add(Calendar.DAY_OF_YEAR, offset)
                }

                val titleFormat = SimpleDateFormat("EEEE, MMM d", Locale.getDefault())
                val titleStr = titleFormat.format(cal.time)

                val subtitleStr = when (offset) {
                    0 -> "Today"
                    1 -> "Tomorrow"
                    -1 -> "Yesterday"
                    else -> {
                        val diffFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                        diffFormat.format(cal.time)
                    }
                }

                views.setTextViewText(R.id.widget_today_date_title, titleStr)
                views.setTextViewText(R.id.widget_today_date_subtitle, subtitleStr)

                // 3. Navigation Pending Intents
                val prevIntent = Intent(context, TodayAgendaWidgetProvider::class.java).apply {
                    action = ACTION_PREV_DAY
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_today_prev,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_PREV_DAY,
                        prevIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val nextIntent = Intent(context, TodayAgendaWidgetProvider::class.java).apply {
                    action = ACTION_NEXT_DAY
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_today_next,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_NEXT_DAY,
                        nextIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val todayIntent = Intent(context, TodayAgendaWidgetProvider::class.java).apply {
                    action = ACTION_JUMP_TODAY
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_today_jump_btn,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_JUMP_TODAY,
                        todayIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                // 4. Add Task Button
                val addTaskPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://add_task")
                )
                views.setOnClickPendingIntent(R.id.widget_today_add_btn, addTaskPendingIntent)

                // 5. ListView Adapter Setup (always bound so launcher never encounters uninitialized adapter)
                val serviceIntent = Intent(context, TodayAgendaWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/today_agenda/$appWidgetId/$offset")
                }
                views.setRemoteAdapter(R.id.widget_today_list, serviceIntent)
                views.setEmptyView(R.id.widget_today_list, R.id.widget_today_empty)

                // 6. Item Click Template (handles both item tap and task completion)
                val appIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val itemPendingIntent = PendingIntent.getActivity(
                    context,
                    600 + appWidgetId,
                    appIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_today_list, itemPendingIntent)

                WidgetLimitHelper.setupProOverlay(context, views, isAllowed)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_today_list)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_today_list)
                    } catch (_: Exception) {}
                }, 300)
            } catch (e: Exception) {
                android.util.Log.e("TodayAgendaWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action

        if (action == ACTION_PREV_DAY || action == ACTION_NEXT_DAY || action == ACTION_JUMP_TODAY) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val currentOffset = widgetData.getInt(PREF_TODAY_OFFSET, 0)
            val newOffset = when (action) {
                ACTION_PREV_DAY -> currentOffset - 1
                ACTION_NEXT_DAY -> currentOffset + 1
                ACTION_JUMP_TODAY -> 0
                else -> currentOffset
            }

            widgetData.edit().putInt(PREF_TODAY_OFFSET, newOffset).apply()

            // Trigger Dart background synchronization
            val uriStr = when (action) {
                ACTION_PREV_DAY -> "rocistasks://today_agenda_prev"
                ACTION_NEXT_DAY -> "rocistasks://today_agenda_next"
                ACTION_JUMP_TODAY -> "rocistasks://today_agenda_today"
                else -> "rocistasks://today_agenda_refresh"
            }
            try {
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse(uriStr)
                )
                backgroundIntent.send()
            } catch (_: Exception) {}

            // Re-render widgets immediately
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, TodayAgendaWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, ids, widgetData)
        }
    }
}
