package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import es.antonborri.home_widget.HomeWidgetLaunchIntent

class FullCalendarWidgetProvider : HomeWidgetProvider() {

    companion object {
        // Filter toggle actions
        const val ACTION_FILTER_TASKS = FullCalendarWidgetUtils.ACTION_FILTER_TASKS
        const val ACTION_FILTER_GOOGLE = FullCalendarWidgetUtils.ACTION_FILTER_GOOGLE
        const val ACTION_FILTER_ROCIS = FullCalendarWidgetUtils.ACTION_FILTER_ROCIS
        const val ACTION_PREV_MONTH = FullCalendarWidgetUtils.ACTION_PREV_MONTH
        const val ACTION_NEXT_MONTH = FullCalendarWidgetUtils.ACTION_NEXT_MONTH
        const val ACTION_TODAY = FullCalendarWidgetUtils.ACTION_TODAY
        
        // Preference keys
        const val PREF_SHOW_TASKS = FullCalendarWidgetUtils.PREF_SHOW_TASKS
        const val PREF_SHOW_GOOGLE = FullCalendarWidgetUtils.PREF_SHOW_GOOGLE
        const val PREF_SHOW_SCHEDULE = FullCalendarWidgetUtils.PREF_SHOW_SCHEDULE
        const val PREF_OFFSET = FullCalendarWidgetUtils.PREF_OFFSET
        
        // Unique request codes
        private const val REQUEST_CODE_FILTER_TASKS = FullCalendarWidgetUtils.REQUEST_CODE_FILTER_TASKS
        private const val REQUEST_CODE_FILTER_GOOGLE = FullCalendarWidgetUtils.REQUEST_CODE_FILTER_GOOGLE
        private const val REQUEST_CODE_FILTER_ROCIS = FullCalendarWidgetUtils.REQUEST_CODE_FILTER_ROCIS
        private const val REQUEST_CODE_PREV_MONTH = FullCalendarWidgetUtils.REQUEST_CODE_PREV_MONTH
        private const val REQUEST_CODE_NEXT_MONTH = FullCalendarWidgetUtils.REQUEST_CODE_NEXT_MONTH
        private const val REQUEST_CODE_TODAY = FullCalendarWidgetUtils.REQUEST_CODE_TODAY

        private var pendingNavRunnable: Runnable? = null
        private val navHandler by lazy { android.os.Handler(android.os.Looper.getMainLooper()) }

        private fun scheduleBackgroundNav(context: Context, uriString: String, immediate: Boolean) {
            val pending = pendingNavRunnable
            if (pending != null) {
                navHandler.removeCallbacks(pending)
            }
            if (immediate) {
                try {
                    val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                        context.applicationContext, Uri.parse(uriString)
                    )
                    backgroundIntent.send()
                } catch (e: Exception) {}
            } else {
                val runnable = Runnable {
                    try {
                        val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                            context.applicationContext, Uri.parse(uriString)
                        )
                        backgroundIntent.send()
                    } catch (e: Exception) {}
                }
                pendingNavRunnable = runnable
                navHandler.postDelayed(runnable, 1200)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            try {
                appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, appWidgetId, widgetData))
            } catch (e: Exception) {
                android.util.Log.e("FullCalendarWidget", "Failed to update widget $appWidgetId", e)
            }
        }
    }

    private fun buildViews(context: Context, appWidgetId: Int, widgetData: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_full_calendar_layout)
        val theme = widgetData.getString(FullCalendarWidgetUtils.PREF_THEME, FullCalendarWidgetUtils.DEFAULT_THEME)
            ?: FullCalendarWidgetUtils.DEFAULT_THEME
        val palette = FullCalendarWidgetUtils.resolvePalette(widgetData, theme, context)
        val widgetLocale = WidgetLocaleHelper.getWidgetLocale(widgetData)
        val isRtl = WidgetLocaleHelper.isRtl(widgetLocale)

        // 1. Card: the app's calendar card (surfaceContainerLow + 12% accent border).
        views.setInt(R.id.widget_fc_card_fill, "setColorFilter", palette.surface)
        views.setInt(R.id.widget_fc_card_fill, "setImageAlpha", if (palette.translucent) 0xCC else 0xFF)
        views.setInt(R.id.widget_fc_card_stroke, "setColorFilter", palette.primary)
        views.setInt(R.id.widget_fc_card_stroke, "setImageAlpha", 0x1F)
        views.setInt(
            R.id.widget_full_calendar_root, "setLayoutDirection",
            if (isRtl) android.view.View.LAYOUT_DIRECTION_RTL else android.view.View.LAYOUT_DIRECTION_LTR
        )

        // 2. Header: localized month title and actions tinted like the app's icons.
        val cal = java.util.Calendar.getInstance()
        val offset = widgetData.getInt(PREF_OFFSET, 0)
        if (offset != 0) cal.add(java.util.Calendar.MONTH, offset)
        views.setTextViewText(R.id.widget_full_calendar_title, WidgetLocaleHelper.getMonthYearTitle(cal, widgetLocale))
        views.setTextColor(R.id.widget_full_calendar_title, palette.onSurface)
        listOf(
            R.id.widget_full_calendar_prev, R.id.widget_full_calendar_next,
            R.id.widget_full_calendar_today, R.id.widget_add_task_btn
        ).forEach { views.setInt(it, "setColorFilter", palette.onSurface) }

        views.setOnClickPendingIntent(R.id.widget_full_calendar_prev, broadcast(context, ACTION_PREV_MONTH, REQUEST_CODE_PREV_MONTH, appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_full_calendar_next, broadcast(context, ACTION_NEXT_MONTH, REQUEST_CODE_NEXT_MONTH, appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_full_calendar_today, broadcast(context, ACTION_TODAY, REQUEST_CODE_TODAY, appWidgetId))
        views.setOnClickPendingIntent(
            R.id.widget_full_calendar_title,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://calendar"))
        )
        views.setOnClickPendingIntent(
            R.id.widget_add_task_btn,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://add_task"))
        )

        // 3. Source filter chips (widget-only): active = 15% accent fill + accent text.
        val chips = listOf(
            ChipSpec(R.id.widget_filter_tasks_fill, R.id.widget_filter_tasks_stroke, R.id.widget_filter_tasks_text,
                widgetData.getBoolean(PREF_SHOW_TASKS, true), WidgetLocaleHelper.getTasksFilterText(widgetLocale)),
            ChipSpec(R.id.widget_filter_google_fill, R.id.widget_filter_google_stroke, R.id.widget_filter_google_text,
                widgetData.getBoolean(PREF_SHOW_GOOGLE, true), WidgetLocaleHelper.getGoogleFilterText(widgetLocale)),
            ChipSpec(R.id.widget_filter_rocis_fill, R.id.widget_filter_rocis_stroke, R.id.widget_filter_rocis_text,
                widgetData.getBoolean(PREF_SHOW_SCHEDULE, true), WidgetLocaleHelper.getScheduleFilterText(widgetLocale))
        )
        for (chip in chips) {
            views.setTextViewText(chip.text, chip.label)
            views.setTextColor(chip.text, if (chip.active) palette.primary else palette.onSurfaceMuted)
            views.setInt(chip.fill, "setColorFilter", palette.primary)
            views.setInt(chip.fill, "setImageAlpha", if (chip.active) 0x26 else 0x00)
            views.setInt(chip.stroke, "setColorFilter", if (chip.active) palette.primary else palette.onSurface)
            views.setInt(chip.stroke, "setImageAlpha", if (chip.active) 0x59 else 0x33)
        }
        setupFilterButtonIntents(context, views, appWidgetId)

        // 4. Weekday header: localized short names, weekend colors like the app.
        val startOfWeek = widgetData.getInt(FullCalendarWidgetUtils.PREF_START_OF_WEEK, FullCalendarWidgetUtils.DEFAULT_START_OF_WEEK)
        val weekendHighlight = widgetData.getBoolean(FullCalendarWidgetUtils.PREF_WEEKEND_HIGHLIGHT, true)
        val showWeekNumbers = widgetData.getBoolean(
            FullCalendarWidgetUtils.PREF_SHOW_WEEK_NUMBERS, FullCalendarWidgetUtils.DEFAULT_SHOW_WEEK_NUMBERS
        )
        val names = WidgetLocaleHelper.getWeekdayShortNames(startOfWeek, widgetLocale)
        val weekdayViewIds = listOf(
            R.id.widget_weekday_sun_header, R.id.widget_weekday_mon_header, R.id.widget_weekday_tue_header,
            R.id.widget_weekday_wed_header, R.id.widget_weekday_thu_header, R.id.widget_weekday_fri_header,
            R.id.widget_weekday_sat_header
        )
        for (col in 0..6) {
            val dayOfWeek = (startOfWeek + col - 1) % 7 + 1 // 1=Mon .. 7=Sun
            views.setTextViewText(weekdayViewIds[col], names[col])
            views.setTextColor(
                weekdayViewIds[col],
                when {
                    weekendHighlight && dayOfWeek == 7 -> FullCalendarWidgetUtils.SUNDAY_COLOR
                    weekendHighlight && dayOfWeek == 6 -> FullCalendarWidgetUtils.SATURDAY_COLOR
                    else -> palette.onSurface
                }
            )
        }
        views.setViewVisibility(R.id.widget_weekday_num_header, if (showWeekNumbers) android.view.View.VISIBLE else android.view.View.GONE)
        views.setTextColor(R.id.widget_weekday_num_header, palette.onSurfaceFaded)

        // 5. Weeks of the month.
        views.removeAllViews(R.id.widget_full_calendar_grid)
        FullCalendarGridRenderer.buildRows(context, widgetData, palette, isRtl).forEach {
            views.addView(R.id.widget_full_calendar_grid, it)
        }

        // 6. Premium gate.
        views.setTextViewText(R.id.widget_premium_overlay_text, WidgetLocaleHelper.getPremiumFeatureText(widgetLocale))
        val isPremium = widgetData.getBoolean(FullCalendarWidgetUtils.PREF_IS_PREMIUM, false)
        val isAllowed = WidgetLimitHelper.isWidgetAllowed(context, appWidgetId, isPremium)
        val contentVisibility = if (isAllowed) android.view.View.VISIBLE else android.view.View.GONE
        listOf(
            R.id.widget_full_calendar_grid, R.id.widget_full_calendar_header,
            R.id.widget_full_calendar_filters, R.id.widget_full_calendar_weekdays
        ).forEach { views.setViewVisibility(it, contentVisibility) }
        views.setViewVisibility(R.id.widget_premium_overlay, if (isAllowed) android.view.View.GONE else android.view.View.VISIBLE)
        if (!isAllowed) {
            views.setOnClickPendingIntent(
                R.id.widget_premium_overlay,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://paywall"))
            )
        }
        return views
    }

    private data class ChipSpec(val fill: Int, val stroke: Int, val text: Int, val active: Boolean, val label: String)

    private fun broadcast(context: Context, action: String, requestCode: Int, appWidgetId: Int): android.app.PendingIntent {
        val intent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        return android.app.PendingIntent.getBroadcast(
            context, requestCode, intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun setupFilterButtonIntents(context: Context, views: RemoteViews, appWidgetId: Int) {
        val filterTasksIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
            action = ACTION_FILTER_TASKS
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val filterTasksPendingIntent = android.app.PendingIntent.getBroadcast(
            context, REQUEST_CODE_FILTER_TASKS, filterTasksIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_filter_tasks, filterTasksPendingIntent)

        val filterGoogleIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
            action = ACTION_FILTER_GOOGLE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val filterGooglePendingIntent = android.app.PendingIntent.getBroadcast(
            context, REQUEST_CODE_FILTER_GOOGLE, filterGoogleIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_filter_google, filterGooglePendingIntent)

        val filterRocisIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
            action = ACTION_FILTER_ROCIS
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        val filterRocisPendingIntent = android.app.PendingIntent.getBroadcast(
            context, REQUEST_CODE_FILTER_ROCIS, filterRocisIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_filter_rocis, filterRocisPendingIntent)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        
        if (action == ACTION_FILTER_TASKS || action == ACTION_FILTER_GOOGLE || action == ACTION_FILTER_ROCIS ||
            action == ACTION_PREV_MONTH || action == ACTION_NEXT_MONTH || 
            action == ACTION_TODAY) {
            
            val widgetData = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            val editor = widgetData.edit()
            
            when (action) {
                ACTION_FILTER_TASKS -> {
                    val current = widgetData.getBoolean(PREF_SHOW_TASKS, true)
                    editor.putBoolean(PREF_SHOW_TASKS, !current).apply()
                    val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                        context, Uri.parse("rocistasks://full_calendar_filter_tasks")
                    )
                    try {
                        backgroundIntent.send()
                    } catch (e: Exception) {}
                }
                ACTION_FILTER_GOOGLE -> {
                    val current = widgetData.getBoolean(PREF_SHOW_GOOGLE, true)
                    editor.putBoolean(PREF_SHOW_GOOGLE, !current).apply()
                    val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                        context, Uri.parse("rocistasks://full_calendar_filter_google")
                    )
                    try {
                        backgroundIntent.send()
                    } catch (e: Exception) {}
                }
                ACTION_FILTER_ROCIS -> {
                    val current = widgetData.getBoolean(PREF_SHOW_SCHEDULE, true)
                    editor.putBoolean(PREF_SHOW_SCHEDULE, !current).apply()
                    val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                        context, Uri.parse("rocistasks://full_calendar_filter_rocis")
                    )
                    try {
                        backgroundIntent.send()
                    } catch (e: Exception) {}
                }
                ACTION_PREV_MONTH -> {
                    val currentOffset = widgetData.getInt(PREF_OFFSET, 0)
                    val newOffset = currentOffset - 1
                    editor.putInt(PREF_OFFSET, newOffset)
                        .putString(FullCalendarWidgetUtils.PREF_SELECTED_DATE, "")
                        .apply()
                    
                    // Pre-buffered range is -3 to +6. If within -2..5, debounce Flutter background engine boot
                    // to prevent UI frame drops and launcher stutter during fast tapping.
                    val isWithinBuffer = newOffset >= -2 && newOffset <= 5
                    scheduleBackgroundNav(context, "rocistasks://full_calendar_prev?offset=$newOffset", immediate = !isWithinBuffer)
                }
                ACTION_NEXT_MONTH -> {
                    val currentOffset = widgetData.getInt(PREF_OFFSET, 0)
                    val newOffset = currentOffset + 1
                    editor.putInt(PREF_OFFSET, newOffset)
                        .putString(FullCalendarWidgetUtils.PREF_SELECTED_DATE, "")
                        .apply()
                    
                    val isWithinBuffer = newOffset >= -2 && newOffset <= 5
                    scheduleBackgroundNav(context, "rocistasks://full_calendar_next?offset=$newOffset", immediate = !isWithinBuffer)
                }
                ACTION_TODAY -> {
                    editor.putInt(PREF_OFFSET, 0)
                        .putString(FullCalendarWidgetUtils.PREF_SELECTED_DATE, "")
                        .apply()
                    
                    scheduleBackgroundNav(context, "rocistasks://full_calendar_today?offset=0", immediate = false)
                }
            }
            
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = android.content.ComponentName(context, FullCalendarWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }
}
