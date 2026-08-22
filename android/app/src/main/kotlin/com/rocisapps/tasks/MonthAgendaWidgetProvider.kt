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

class MonthAgendaWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PREV_MONTH = "com.rocisapps.tasks.ACTION_MONTH_AGENDA_PREV_MONTH"
        const val ACTION_NEXT_MONTH = "com.rocisapps.tasks.ACTION_MONTH_AGENDA_NEXT_MONTH"
        const val ACTION_TODAY = "com.rocisapps.tasks.ACTION_MONTH_AGENDA_TODAY"
        const val ACTION_SELECT_DATE = "com.rocisapps.tasks.ACTION_MONTH_AGENDA_SELECT_DATE"

        const val PREF_MONTH_OFFSET = "month_agenda_offset"
        const val PREF_SELECTED_DATE = "month_agenda_selected_date"

        private const val REQ_PREV_MONTH = 701
        private const val REQ_NEXT_MONTH = 702
        private const val REQ_TODAY = 703
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
                val views = RemoteViews(context.packageName, R.layout.widget_month_agenda_layout)

                val theme = widgetData.getString("full_calendar_theme", "system") ?: "system"
                val rootBgRes = when (theme) {
                    "light" -> R.drawable.widget_background_light
                    "dark" -> R.drawable.widget_background_dark
                    "glassmorphic" -> R.drawable.widget_background_glass
                    else -> R.drawable.widget_background
                }
                views.setInt(R.id.widget_month_agenda_root, "setBackgroundResource", rootBgRes)

                val highlightColorHex = widgetData.getString("full_calendar_highlight_color", "#6366F1") ?: "#6366F1"
                val highlightColor = try {
                    android.graphics.Color.parseColor(highlightColorHex)
                } catch (_: Exception) {
                    android.graphics.Color.parseColor("#6366F1")
                }

                val textColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#0F172A")
                    else -> android.graphics.Color.parseColor("#FFFFFF")
                }

                views.setTextColor(R.id.widget_month_agenda_month_title, textColor)
                views.setTextColor(R.id.widget_month_agenda_selected_title, textColor)
                views.setTextColor(R.id.widget_month_agenda_prev, textColor)
                views.setTextColor(R.id.widget_month_agenda_next, textColor)
                views.setTextColor(R.id.widget_month_agenda_today_btn, highlightColor)
                views.setTextColor(R.id.widget_month_agenda_add_btn, highlightColor)

                val offset = widgetData.getInt(PREF_MONTH_OFFSET, 0)
                val cal = Calendar.getInstance()
                if (offset != 0) {
                    cal.add(Calendar.MONTH, offset)
                }
                val monthTitleStr = SimpleDateFormat("MMMM yyyy", Locale.getDefault()).format(cal.time)
                views.setTextViewText(R.id.widget_month_agenda_month_title, monthTitleStr)

                // Selected Date Display
                var selectedDate = widgetData.getString(PREF_SELECTED_DATE, "") ?: ""
                if (selectedDate.isEmpty()) {
                    selectedDate = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
                }
                val selectedDateDisplay = try {
                    val parsed = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(selectedDate)
                    SimpleDateFormat("EEE, MMM d", Locale.getDefault()).format(parsed!!)
                } catch (_: Exception) {
                    "Today"
                }
                views.setTextViewText(R.id.widget_month_agenda_selected_title, selectedDateDisplay)

                // Navigation pending intents
                val prevIntent = Intent(context, MonthAgendaWidgetProvider::class.java).apply {
                    action = ACTION_PREV_MONTH
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_month_agenda_prev,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_PREV_MONTH,
                        prevIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val nextIntent = Intent(context, MonthAgendaWidgetProvider::class.java).apply {
                    action = ACTION_NEXT_MONTH
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_month_agenda_next,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_NEXT_MONTH,
                        nextIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val todayIntent = Intent(context, MonthAgendaWidgetProvider::class.java).apply {
                    action = ACTION_TODAY
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                views.setOnClickPendingIntent(
                    R.id.widget_month_agenda_today_btn,
                    PendingIntent.getBroadcast(
                        context,
                        REQ_TODAY,
                        todayIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                )

                val addIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://add_task")
                )
                views.setOnClickPendingIntent(R.id.widget_month_agenda_add_btn, addIntent)

                // Month Grid List (Left half) - Always configure adapter
                val gridServiceIntent = Intent(context, MonthAgendaGridService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/month_agenda_grid/$appWidgetId/$offset")
                }
                views.setRemoteAdapter(R.id.widget_month_grid_list, gridServiceIntent)

                // Grid Item Click Template
                val gridClickIntent = Intent(context, MonthAgendaWidgetProvider::class.java).apply {
                    action = ACTION_SELECT_DATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val gridPendingIntent = PendingIntent.getBroadcast(
                    context,
                    750 + appWidgetId,
                    gridClickIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_month_grid_list, gridPendingIntent)

                // Day Agenda List (Right half) - Always configure adapter
                val agendaServiceIntent = Intent(context, MonthAgendaWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/month_agenda_list/$appWidgetId/$selectedDate")
                }
                views.setRemoteAdapter(R.id.widget_month_agenda_list, agendaServiceIntent)
                views.setEmptyView(R.id.widget_month_agenda_list, R.id.widget_month_agenda_empty)

                // Day Agenda Item Click Template (direct completion or view)
                val itemAppIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val itemPendingIntent = PendingIntent.getActivity(
                    context,
                    780 + appWidgetId,
                    itemAppIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_month_agenda_list, itemPendingIntent)

                WidgetLimitHelper.setupProOverlay(context, views, isAllowed)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_month_grid_list)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_month_agenda_list)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_month_grid_list)
                        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_month_agenda_list)
                    } catch (_: Exception) {}
                }, 300)
            } catch (e: Exception) {
                android.util.Log.e("MonthAgendaWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action

        if (action == ACTION_PREV_MONTH || action == ACTION_NEXT_MONTH || action == ACTION_TODAY || action == ACTION_SELECT_DATE) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val currentOffset = widgetData.getInt(PREF_MONTH_OFFSET, 0)

            when (action) {
                ACTION_PREV_MONTH -> {
                    widgetData.edit().putInt(PREF_MONTH_OFFSET, currentOffset - 1).apply()
                }
                ACTION_NEXT_MONTH -> {
                    widgetData.edit().putInt(PREF_MONTH_OFFSET, currentOffset + 1).apply()
                }
                ACTION_TODAY -> {
                    val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Calendar.getInstance().time)
                    widgetData.edit().putInt(PREF_MONTH_OFFSET, 0).putString(PREF_SELECTED_DATE, todayStr).apply()
                }
                ACTION_SELECT_DATE -> {
                    val date = intent.getStringExtra("date") ?: intent.data?.getQueryParameter("date")
                    if (!date.isNullOrEmpty()) {
                        widgetData.edit().putString(PREF_SELECTED_DATE, date).apply()
                    }
                }
            }

            val uriStr = when (action) {
                ACTION_PREV_MONTH -> "rocistasks://month_agenda_prev"
                ACTION_NEXT_MONTH -> "rocistasks://month_agenda_next"
                ACTION_TODAY -> "rocistasks://month_agenda_today"
                else -> "rocistasks://month_agenda_select_date"
            }
            try {
                val backgroundIntent = HomeWidgetBackgroundIntent.getBroadcast(
                    context, Uri.parse(uriStr)
                )
                backgroundIntent.send()
            } catch (_: Exception) {}

            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, MonthAgendaWidgetProvider::class.java)
            val ids = appWidgetManager.getAppWidgetIds(thisWidget)
            onUpdate(context, appWidgetManager, ids, widgetData)
        }
    }
}
