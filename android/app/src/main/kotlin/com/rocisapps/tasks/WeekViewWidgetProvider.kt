package com.rocisapps.tasks

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.net.Uri
import android.os.Bundle
import android.text.format.DateUtils
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar
import java.util.Formatter
import java.util.Locale

/**
 * Week View widget: ROCIs Schedule's weekly timetable on the home screen, with the
 * week's classes, calendar events and tasks (drawn by [WeekViewRenderer]). Reads
 * `today_agenda_data`, which spans 60 days back to 120 ahead, so paging weeks is
 * computed and persisted here without waking Dart.
 */
class WeekViewWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PREV_WEEK = "com.rocisapps.tasks.ACTION_WEEK_PREV"
        const val ACTION_NEXT_WEEK = "com.rocisapps.tasks.ACTION_WEEK_NEXT"
        const val ACTION_THIS_WEEK = "com.rocisapps.tasks.ACTION_WEEK_THIS"

        const val PREF_WEEK_OFFSET = "week_view_offset"

        // Weeks inside the agenda data window (-60 / +120 days).
        private const val MIN_OFFSET = -8
        private const val MAX_OFFSET = 16

        // Fixed layout chrome around the grid (widget_week_view_layout).
        private const val PAD_H_DP = 20
        private const val CHROME_V_DP = 8 + 10 + 40 + 4

        private const val REQ_PREV = 701
        private const val REQ_NEXT = 702
        private const val REQ_THIS = 703

        private val columnIds = intArrayOf(
            R.id.widget_week_col_0, R.id.widget_week_col_1, R.id.widget_week_col_2, R.id.widget_week_col_3,
            R.id.widget_week_col_4, R.id.widget_week_col_5, R.id.widget_week_col_6
        )
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
                val views = buildViews(context, appWidgetManager, appWidgetId, widgetData)
                WidgetStyle.setupProOverlay(context, views, isAllowed, WidgetStyle.palette(context, widgetData), WidgetLocaleHelper.getWidgetLocale(widgetData))
                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                android.util.Log.e("WeekViewWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId), HomeWidgetPlugin.getData(context))
    }

    private fun buildViews(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        widgetData: SharedPreferences
    ): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_week_view_layout)

        // 1. The app's card, tinted icons, RTL.
        val palette = WidgetStyle.palette(context, widgetData)
        val locale = WidgetLocaleHelper.getWidgetLocale(widgetData)
        WidgetStyle.applyCard(views, palette, R.id.widget_week_card_fill, R.id.widget_week_card_stroke)
        WidgetStyle.applyDirection(views, R.id.widget_week_root, locale)
        WidgetStyle.tint(
            views, palette.onSurface,
            R.id.widget_week_prev, R.id.widget_week_next, R.id.widget_week_jump_btn, R.id.widget_week_add_btn
        )

        // 2. Header: the week's date range, "This week" or its month.
        val offset = widgetData.getInt(PREF_WEEK_OFFSET, 0).coerceIn(MIN_OFFSET, MAX_OFFSET)
        val startOfWeek = widgetData.getInt(FullCalendarWidgetUtils.PREF_START_OF_WEEK, FullCalendarWidgetUtils.DEFAULT_START_OF_WEEK)
        val weekStart = WeekViewRenderer.weekStart(offset, startOfWeek)
        val weekEnd = (weekStart.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 6) }
        views.setTextViewText(R.id.widget_week_title, rangeTitle(context, weekStart, weekEnd, locale))
        views.setTextColor(R.id.widget_week_title, palette.onSurface)
        views.setTextViewText(
            R.id.widget_week_subtitle,
            if (offset == 0) WidgetLocaleHelper.getThisWeekText(locale) else WidgetLocaleHelper.getMonthYearTitle(weekStart, locale)
        )
        // "This week" reads in the accent, other weeks muted (like the app's day header).
        views.setTextColor(R.id.widget_week_subtitle, if (offset == 0) palette.primary else palette.onSurfaceMuted)

        // 3. The timetable, sized to the widget so text isn't stretched.
        val dayKeys = (0..6).map { i ->
            WeekViewRenderer.dayKey((weekStart.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, i) })
        }
        val items = WeekViewRenderer.loadItems(
            widgetData.getString("today_agenda_data", "[]") ?: "[]", dayKeys, palette.primary
        )
        val (widthDp, heightDp) = widgetSizeDp(context, appWidgetManager, appWidgetId)
        val bitmap = WeekViewRenderer.render(
            items, weekStart, offset == 0, palette, locale, startOfWeek,
            widgetData.getBoolean("use_24h_format", false),
            (widthDp - PAD_H_DP).toFloat(), (heightDp - CHROME_V_DP).toFloat(),
            context.resources.displayMetrics.density
        )
        if (bitmap != null) views.setImageViewBitmap(R.id.widget_week_grid, bitmap)

        // 4. Taps: a day opens the in-app calendar on it, the title on the week's first day.
        for (col in 0..6) {
            views.setOnClickPendingIntent(columnIds[col], calendarIntent(context, dayKeys[col]))
        }
        views.setOnClickPendingIntent(R.id.widget_week_title_container, calendarIntent(context, dayKeys[0]))
        views.setOnClickPendingIntent(
            R.id.widget_week_add_btn,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://add_task"))
        )
        views.setOnClickPendingIntent(R.id.widget_week_prev, navIntent(context, ACTION_PREV_WEEK, REQ_PREV))
        views.setOnClickPendingIntent(R.id.widget_week_next, navIntent(context, ACTION_NEXT_WEEK, REQ_NEXT))
        views.setOnClickPendingIntent(R.id.widget_week_jump_btn, navIntent(context, ACTION_THIS_WEEK, REQ_THIS))
        return views
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action != ACTION_PREV_WEEK && action != ACTION_NEXT_WEEK && action != ACTION_THIS_WEEK) return

        val widgetData = HomeWidgetPlugin.getData(context)
        val current = widgetData.getInt(PREF_WEEK_OFFSET, 0)
        val next = when (action) {
            ACTION_PREV_WEEK -> current - 1
            ACTION_NEXT_WEEK -> current + 1
            else -> 0
        }.coerceIn(MIN_OFFSET, MAX_OFFSET)
        widgetData.edit().putInt(PREF_WEEK_OFFSET, next).apply()

        val appWidgetManager = AppWidgetManager.getInstance(context)
        val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, WeekViewWidgetProvider::class.java))
        onUpdate(context, appWidgetManager, ids, widgetData)
    }

    private fun calendarIntent(context: Context, dateKey: String): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://calendar?date=$dateKey"))

    private fun navIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, WeekViewWidgetProvider::class.java).apply { this.action = action }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** The widget's current size: portrait uses min width / max height, landscape the reverse. */
    private fun widgetSizeDp(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int): Pair<Int, Int> {
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val landscape = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val width = options?.getInt(
            if (landscape) AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH else AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH
        ) ?: 0
        val height = options?.getInt(
            if (landscape) AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT else AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT
        ) ?: 0
        return Pair(if (width > 0) width else 250, if (height > 0) height else 250)
    }

    /** "Oct 4 – 10", "Sep 28 – Oct 4" in the widget's language. */
    private fun rangeTitle(context: Context, start: Calendar, end: Calendar, locale: Locale): String {
        return try {
            val flags = DateUtils.FORMAT_SHOW_DATE or DateUtils.FORMAT_ABBREV_MONTH or DateUtils.FORMAT_NO_YEAR
            DateUtils.formatDateRange(
                context, Formatter(StringBuilder(), locale),
                start.timeInMillis, end.timeInMillis + 1, flags, null
            ).toString()
        } catch (_: Exception) {
            "${WidgetLocaleHelper.getDateTitle(start, locale)} – ${WidgetLocaleHelper.getDateTitle(end, locale)}"
        }
    }
}
