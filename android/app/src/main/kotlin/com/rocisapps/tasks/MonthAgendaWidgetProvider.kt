package com.rocisapps.tasks

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Typeface
import android.net.Uri
import android.os.Bundle
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Month + day agenda widget: a compact month grid styled like the FullCalendar widget
 * beside the selected day's tasks and events (rows served by [MonthAgendaWidgetService]).
 * Tapping a day selects it; the header navigates months.
 */
class MonthAgendaWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_PREV_MONTH = "com.rocisapps.tasks.ACTION_MONTH_AGENDA_PREV_MONTH"
        const val ACTION_NEXT_MONTH = "com.rocisapps.tasks.ACTION_MONTH_AGENDA_NEXT_MONTH"
        const val ACTION_TODAY = "com.rocisapps.tasks.ACTION_MONTH_AGENDA_TODAY"
        const val ACTION_SELECT_DATE = "com.rocisapps.tasks.ACTION_MONTH_AGENDA_SELECT_DATE"

        const val PREF_MONTH_OFFSET = "month_agenda_offset"
        const val PREF_SELECTED_DATE = "month_agenda_selected_date"
        private const val EXTRA_DATE = "date"

        private const val REQ_PREV_MONTH = 701
        private const val REQ_NEXT_MONTH = 702
        private const val REQ_TODAY = 703
        private const val REQ_SELECT_DATE = 704

        // Short weekday names need ~26dp columns; narrower grids use single letters.
        private const val SHORT_WEEKDAY_MIN_WIDTH_DP = 400

        fun dateKey(cal: Calendar): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(cal.time)

        /** The selected day ("yyyy-MM-dd"), or today when none is stored. */
        fun selectedDate(widgetData: SharedPreferences): String =
            widgetData.getString(PREF_SELECTED_DATE, null)?.takeIf { it.length == 10 }
                ?: dateKey(Calendar.getInstance())

        /** The "yyyy-MM-dd" day an agenda item belongs to. */
        fun dayOf(item: JSONObject): String =
            item.optString("dateOnly", "").ifEmpty { item.optString("dateDisplay", "") }

        private fun parseDate(date: String): Calendar? = try {
            Calendar.getInstance().apply { time = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(date)!! }
        } catch (_: Exception) {
            null
        }
    }

    private data class CellIds(
        val root: Int, val fill: Int, val stroke: Int, val text: Int,
        val pillIds: List<Int>, val dots: Int, val dotIds: List<Int>
    )

    // Explicit ids (no reflection: R8 may strip or rename R fields in release).
    private val cellIds = listOf(
        CellIds(R.id.widget_month_day_0, R.id.widget_month_fill_0, R.id.widget_month_stroke_0, R.id.widget_month_text_0,
            listOf(R.id.widget_month_pill_0_1, R.id.widget_month_pill_0_2),
            R.id.widget_month_dots_0, listOf(R.id.widget_month_dot_0_1, R.id.widget_month_dot_0_2, R.id.widget_month_dot_0_3)),
        CellIds(R.id.widget_month_day_1, R.id.widget_month_fill_1, R.id.widget_month_stroke_1, R.id.widget_month_text_1,
            listOf(R.id.widget_month_pill_1_1, R.id.widget_month_pill_1_2),
            R.id.widget_month_dots_1, listOf(R.id.widget_month_dot_1_1, R.id.widget_month_dot_1_2, R.id.widget_month_dot_1_3)),
        CellIds(R.id.widget_month_day_2, R.id.widget_month_fill_2, R.id.widget_month_stroke_2, R.id.widget_month_text_2,
            listOf(R.id.widget_month_pill_2_1, R.id.widget_month_pill_2_2),
            R.id.widget_month_dots_2, listOf(R.id.widget_month_dot_2_1, R.id.widget_month_dot_2_2, R.id.widget_month_dot_2_3)),
        CellIds(R.id.widget_month_day_3, R.id.widget_month_fill_3, R.id.widget_month_stroke_3, R.id.widget_month_text_3,
            listOf(R.id.widget_month_pill_3_1, R.id.widget_month_pill_3_2),
            R.id.widget_month_dots_3, listOf(R.id.widget_month_dot_3_1, R.id.widget_month_dot_3_2, R.id.widget_month_dot_3_3)),
        CellIds(R.id.widget_month_day_4, R.id.widget_month_fill_4, R.id.widget_month_stroke_4, R.id.widget_month_text_4,
            listOf(R.id.widget_month_pill_4_1, R.id.widget_month_pill_4_2),
            R.id.widget_month_dots_4, listOf(R.id.widget_month_dot_4_1, R.id.widget_month_dot_4_2, R.id.widget_month_dot_4_3)),
        CellIds(R.id.widget_month_day_5, R.id.widget_month_fill_5, R.id.widget_month_stroke_5, R.id.widget_month_text_5,
            listOf(R.id.widget_month_pill_5_1, R.id.widget_month_pill_5_2),
            R.id.widget_month_dots_5, listOf(R.id.widget_month_dot_5_1, R.id.widget_month_dot_5_2, R.id.widget_month_dot_5_3)),
        CellIds(R.id.widget_month_day_6, R.id.widget_month_fill_6, R.id.widget_month_stroke_6, R.id.widget_month_text_6,
            listOf(R.id.widget_month_pill_6_1, R.id.widget_month_pill_6_2),
            R.id.widget_month_dots_6, listOf(R.id.widget_month_dot_6_1, R.id.widget_month_dot_6_2, R.id.widget_month_dot_6_3))
    )

    private val weekdayIds = listOf(
        R.id.widget_month_agenda_wd_0, R.id.widget_month_agenda_wd_1, R.id.widget_month_agenda_wd_2,
        R.id.widget_month_agenda_wd_3, R.id.widget_month_agenda_wd_4, R.id.widget_month_agenda_wd_5,
        R.id.widget_month_agenda_wd_6
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { appWidgetId ->
            try {
                appWidgetManager.updateAppWidget(appWidgetId, buildViews(context, appWidgetManager, appWidgetId, widgetData))
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_month_agenda_list)
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_month_agenda_list)
                    } catch (_: Exception) {}
                }, 300)
            } catch (e: Exception) {
                android.util.Log.e("MonthAgendaWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    /** Re-renders on resize: the weekday header switches between letters and short names. */
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
        val views = RemoteViews(context.packageName, R.layout.widget_month_agenda_layout)

        // 1. The app's card, tinted icons, RTL.
        val palette = WidgetStyle.palette(context, widgetData)
        val locale = WidgetLocaleHelper.getWidgetLocale(widgetData)
        val isRtl = WidgetLocaleHelper.isRtl(locale)
        WidgetStyle.applyCard(views, palette, R.id.widget_month_agenda_card_fill, R.id.widget_month_agenda_card_stroke)
        WidgetStyle.applyDirection(views, R.id.widget_month_agenda_root, locale)
        WidgetStyle.tint(
            views, palette.onSurface,
            R.id.widget_month_agenda_prev, R.id.widget_month_agenda_next,
            R.id.widget_month_agenda_today_btn, R.id.widget_month_agenda_add_btn
        )
        views.setInt(R.id.widget_month_agenda_divider, "setColorFilter", palette.onSurface)
        views.setInt(R.id.widget_month_agenda_divider, "setImageAlpha", 0x1F)

        // 2. Header: localized month title and actions.
        val offset = widgetData.getInt(PREF_MONTH_OFFSET, 0)
        val month = Calendar.getInstance().apply {
            set(Calendar.DAY_OF_MONTH, 1)
            add(Calendar.MONTH, offset)
        }
        views.setTextViewText(R.id.widget_month_agenda_month_title, WidgetLocaleHelper.getMonthYearTitle(month, locale))
        views.setTextColor(R.id.widget_month_agenda_month_title, palette.onSurface)
        views.setOnClickPendingIntent(
            R.id.widget_month_agenda_month_title,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://calendar?date=${dateKey(month)}"))
        )
        views.setOnClickPendingIntent(R.id.widget_month_agenda_prev, broadcast(context, ACTION_PREV_MONTH, REQ_PREV_MONTH, appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_month_agenda_next, broadcast(context, ACTION_NEXT_MONTH, REQ_NEXT_MONTH, appWidgetId))
        views.setOnClickPendingIntent(R.id.widget_month_agenda_today_btn, broadcast(context, ACTION_TODAY, REQ_TODAY, appWidgetId))
        views.setOnClickPendingIntent(
            R.id.widget_month_agenda_add_btn,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://add_task"))
        )

        // 3. Weekday header: short names when columns allow, else letters; weekend colors like the app.
        val startOfWeek = widgetData.getInt(FullCalendarWidgetUtils.PREF_START_OF_WEEK, FullCalendarWidgetUtils.DEFAULT_START_OF_WEEK)
        val weekendHighlight = widgetData.getBoolean(FullCalendarWidgetUtils.PREF_WEEKEND_HIGHLIGHT, true)
        val widthDp = appWidgetManager.getAppWidgetOptions(appWidgetId)?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val lang = WidgetLocaleHelper.getNormalizedLanguage(locale)
        // Hebrew/Arabic/Hindi short names ("יום א׳") never fit a half-width grid.
        val names = if (widthDp >= SHORT_WEEKDAY_MIN_WIDTH_DP && lang !in setOf("he", "ar", "hi")) {
            WidgetLocaleHelper.getWeekdayShortNames(startOfWeek, locale)
        } else {
            WidgetLocaleHelper.getWeekdayLetters(startOfWeek, locale)
        }
        for (col in 0..6) {
            views.setTextViewText(weekdayIds[col], names[col])
            views.setTextColor(weekdayIds[col], weekdayColor(isoWeekday(startOfWeek, col), weekendHighlight, palette.onSurface))
        }

        // 4. Weeks of the month.
        val selected = selectedDate(widgetData)
        views.removeAllViews(R.id.widget_month_agenda_grid)
        buildGridRows(context, widgetData, palette, isRtl, offset, startOfWeek, weekendHighlight, selected).forEach {
            views.addView(R.id.widget_month_agenda_grid, it)
        }

        // 5. Selected day header: date plus a Today/Tomorrow/Yesterday chip.
        val selectedCal = parseDate(selected) ?: Calendar.getInstance()
        views.setTextViewText(R.id.widget_month_agenda_selected_title, WidgetLocaleHelper.getDateTitle(selectedCal, locale, false))
        views.setTextColor(R.id.widget_month_agenda_selected_title, palette.onSurface)
        val relative = relativeDayLabel(selected, locale)
        if (relative != null) {
            views.setViewVisibility(R.id.widget_month_agenda_selected_chip, View.VISIBLE)
            views.setTextViewText(R.id.widget_month_agenda_selected_subtitle, relative)
            views.setTextColor(R.id.widget_month_agenda_selected_subtitle, palette.primary)
            WidgetStyle.applyTile(views, R.id.widget_month_agenda_selected_chip_fill, palette.primary, 0x26)
        } else {
            views.setViewVisibility(R.id.widget_month_agenda_selected_chip, View.GONE)
        }
        views.setOnClickPendingIntent(
            R.id.widget_month_agenda_day_header,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://calendar?date=$selected"))
        )

        // 6. Day agenda list.
        val serviceIntent = Intent(context, MonthAgendaWidgetService::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            data = Uri.parse("widget://rocis/month_agenda_list/$appWidgetId/$selected")
        }
        views.setRemoteAdapter(R.id.widget_month_agenda_list, serviceIntent)
        views.setTextViewText(R.id.widget_month_agenda_empty_title, WidgetLocaleHelper.getNoEventsOrTasksText(locale))
        views.setTextViewText(R.id.widget_month_agenda_empty_subtitle, WidgetLocaleHelper.getTapPlusToAddText(locale))
        views.setTextColor(R.id.widget_month_agenda_empty_title, palette.onSurface)
        views.setTextColor(R.id.widget_month_agenda_empty_subtitle, palette.onSurfaceMuted)
        WidgetStyle.tint(views, palette.primary, R.id.widget_month_agenda_empty_icon)
        views.setEmptyView(R.id.widget_month_agenda_list, R.id.widget_month_agenda_empty)

        // Row taps: task / event deep links, checkbox completes (fill-ins set by the factory).
        val itemAppIntent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        views.setPendingIntentTemplate(
            R.id.widget_month_agenda_list,
            PendingIntent.getActivity(
                context, 780 + appWidgetId, itemAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
        )

        // 7. Free-tier gate.
        val isPremium = widgetData.getBoolean(FullCalendarWidgetUtils.PREF_IS_PREMIUM, false)
        val isAllowed = WidgetLimitHelper.isWidgetAllowed(context, appWidgetId, isPremium)
        WidgetStyle.setupProOverlay(context, views, isAllowed, palette, locale)
        return views
    }

    /** Week rows like the FullCalendar widget; weeks without a day of the month are skipped. */
    private fun buildGridRows(
        context: Context,
        widgetData: SharedPreferences,
        palette: FullCalendarWidgetUtils.Palette,
        isRtl: Boolean,
        offset: Int,
        startOfWeek: Int,
        weekendHighlight: Boolean,
        selected: String
    ): List<RemoteViews> {
        val grid = FullCalendarWidgetUtils.buildCalendarGrid(offset, startOfWeek)
        val markers = loadDayMarkers(widgetData, palette.primary)
        val today = dateKey(Calendar.getInstance())

        val rows = ArrayList<RemoteViews>()
        for (row in 0 until grid.size / 8) {
            val days = grid.subList(row * 8 + 1, row * 8 + 8)
            if (days.none { it.optBoolean("isCurrentMonth", false) }) continue

            val views = RemoteViews(context.packageName, R.layout.widget_month_agenda_row)
            views.setInt(
                R.id.widget_month_agenda_row_root, "setLayoutDirection",
                if (isRtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
            )
            days.forEachIndexed { col, day ->
                renderCell(
                    context, views, cellIds[col], day, palette, today, selected,
                    weekdayColor(isoWeekday(startOfWeek, col), weekendHighlight, palette.onSurface), markers
                )
            }
            rows.add(views)
        }
        return rows
    }

    private fun renderCell(
        context: Context,
        views: RemoteViews,
        ids: CellIds,
        day: JSONObject,
        palette: FullCalendarWidgetUtils.Palette,
        today: String,
        selected: String,
        weekdayColor: Int,
        markers: Map<String, List<Int>>
    ) {
        val date = day.optString("date", "")
        val isCurrentMonth = day.optBoolean("isCurrentMonth", true)
        val isToday = date == today
        val isSelected = date.isNotEmpty() && date == selected && !isToday

        // Today = 10% accent tint, selected = accent outline (as in the app).
        views.setViewVisibility(ids.fill, if (isToday) View.VISIBLE else View.GONE)
        views.setViewVisibility(ids.stroke, if (isSelected) View.VISIBLE else View.GONE)
        if (isToday) {
            views.setInt(ids.fill, "setColorFilter", palette.primary)
            views.setInt(ids.fill, "setImageAlpha", 0x1A)
        }
        if (isSelected) views.setInt(ids.stroke, "setColorFilter", palette.primary)

        val label = SpannableString(day.optInt("day", 1).toString())
        if (isToday || isSelected) {
            label.setSpan(StyleSpan(Typeface.BOLD), 0, label.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        views.setTextViewText(ids.text, label)
        views.setTextColor(
            ids.text,
            when {
                isToday || isSelected -> palette.primary
                !isCurrentMonth -> palette.onSurfaceFaded
                else -> weekdayColor
            }
        )

        // Like the FullCalendar widget: 1-2 items -> colored pills, 3+ -> colored dots
        // (pills are title-less here; the half-width grid has no room for text).
        val colors = markers[date].orEmpty()
        val usePills = colors.size in 1..2
        val alpha = if (isCurrentMonth) 0xFF else 0x66
        ids.pillIds.forEachIndexed { k, pillId ->
            if (usePills && k < colors.size) {
                views.setViewVisibility(pillId, View.VISIBLE)
                views.setInt(pillId, "setColorFilter", colors[k])
                views.setInt(pillId, "setImageAlpha", alpha)
            } else {
                views.setViewVisibility(pillId, View.GONE)
            }
        }
        views.setViewVisibility(ids.dots, if (colors.size > 2) View.VISIBLE else View.GONE)
        ids.dotIds.forEachIndexed { k, dotId ->
            if (colors.size > 2 && k < colors.size) {
                views.setViewVisibility(dotId, View.VISIBLE)
                views.setInt(dotId, "setColorFilter", colors[k])
                views.setInt(dotId, "setImageAlpha", alpha)
            } else {
                views.setViewVisibility(dotId, View.GONE)
            }
        }

        // Tapping a day selects it (unique data keeps each cell's PendingIntent distinct).
        if (date.isNotEmpty()) {
            val intent = Intent(context, MonthAgendaWidgetProvider::class.java).apply {
                action = ACTION_SELECT_DATE
                data = Uri.parse("widget://rocis/month_agenda_select?date=$date")
                putExtra(EXTRA_DATE, date)
            }
            views.setOnClickPendingIntent(
                ids.root,
                PendingIntent.getBroadcast(
                    context, REQ_SELECT_DATE, intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
            )
        }
    }

    /**
     * Marker colors per day: one per agenda item (max 3). Days the Dart month grid flags
     * as busy but outside the agenda's range get a single accent dot.
     */
    private fun loadDayMarkers(widgetData: SharedPreferences, accent: Int): Map<String, List<Int>> {
        val result = HashMap<String, MutableList<Int>>()
        try {
            val items = JSONArray(widgetData.getString("today_agenda_data", "[]") ?: "[]")
            for (i in 0 until items.length()) {
                val item = items.optJSONObject(i) ?: continue
                val day = dayOf(item)
                if (day.isEmpty()) continue
                val colors = result.getOrPut(day) { mutableListOf() }
                if (colors.size < 3) {
                    colors.add(WidgetStyle.withAlpha(WidgetStyle.parseColor(item.optString("category_color", ""), accent), 0xFF))
                }
            }
        } catch (_: Exception) {}
        try {
            val grid = JSONArray(widgetData.getString("month_agenda_grid_data", "[]") ?: "[]")
            for (i in 0 until grid.length()) {
                val day = grid.optJSONObject(i) ?: continue
                val date = day.optString("date", "")
                if (!day.optBoolean("hasEvents", false) || date.isEmpty()) continue
                val colors = result.getOrPut(date) { mutableListOf() }
                if (colors.isEmpty()) colors.add(accent)
            }
        } catch (_: Exception) {}
        return result
    }

    /** ISO weekday (1 = Mon .. 7 = Sun) of grid column [col]. */
    private fun isoWeekday(startOfWeek: Int, col: Int): Int = (startOfWeek + col - 1) % 7 + 1

    private fun weekdayColor(isoWeekday: Int, weekendHighlight: Boolean, default: Int): Int = when {
        weekendHighlight && isoWeekday == 7 -> FullCalendarWidgetUtils.SUNDAY_COLOR
        weekendHighlight && isoWeekday == 6 -> FullCalendarWidgetUtils.SATURDAY_COLOR
        else -> default
    }

    private fun relativeDayLabel(date: String, locale: Locale): String? {
        fun shifted(days: Int) = dateKey(Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, days) })
        return when (date) {
            shifted(0) -> WidgetLocaleHelper.getTodayText(locale)
            shifted(1) -> WidgetLocaleHelper.getTomorrowText(locale)
            shifted(-1) -> WidgetLocaleHelper.getYesterdayText(locale)
            else -> null
        }
    }

    private fun broadcast(context: Context, action: String, requestCode: Int, appWidgetId: Int): PendingIntent {
        val intent = Intent(context, MonthAgendaWidgetProvider::class.java).apply {
            this.action = action
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action != ACTION_PREV_MONTH && action != ACTION_NEXT_MONTH && action != ACTION_TODAY && action != ACTION_SELECT_DATE) return

        val widgetData = HomeWidgetPlugin.getData(context)
        val currentOffset = widgetData.getInt(PREF_MONTH_OFFSET, 0)
        when (action) {
            ACTION_PREV_MONTH, ACTION_NEXT_MONTH -> {
                val newOffset = currentOffset + if (action == ACTION_NEXT_MONTH) 1 else -1
                // Keep the agenda on the visible month: today there, else its 1st.
                val selected = if (newOffset == 0) {
                    Calendar.getInstance()
                } else {
                    Calendar.getInstance().apply {
                        set(Calendar.DAY_OF_MONTH, 1)
                        add(Calendar.MONTH, newOffset)
                    }
                }
                widgetData.edit()
                    .putInt(PREF_MONTH_OFFSET, newOffset)
                    .putString(PREF_SELECTED_DATE, dateKey(selected))
                    .apply()
            }
            ACTION_TODAY -> {
                widgetData.edit()
                    .putInt(PREF_MONTH_OFFSET, 0)
                    .putString(PREF_SELECTED_DATE, dateKey(Calendar.getInstance()))
                    .apply()
            }
            ACTION_SELECT_DATE -> {
                val date = intent.getStringExtra(EXTRA_DATE) ?: intent.data?.getQueryParameter("date")
                if (!date.isNullOrEmpty()) widgetData.edit().putString(PREF_SELECTED_DATE, date).apply()
            }
        }

        // Sync with the Dart background handler (refreshes month_agenda_grid_data).
        val uriStr = when (action) {
            ACTION_PREV_MONTH -> "rocistasks://month_agenda_prev"
            ACTION_NEXT_MONTH -> "rocistasks://month_agenda_next"
            ACTION_TODAY -> "rocistasks://month_agenda_today"
            else -> "rocistasks://month_agenda_select_date"
        }
        try {
            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse(uriStr)).send()
        } catch (_: Exception) {}

        val appWidgetManager = AppWidgetManager.getInstance(context)
        val ids = appWidgetManager.getAppWidgetIds(ComponentName(context, MonthAgendaWidgetProvider::class.java))
        onUpdate(context, appWidgetManager, ids, widgetData)
    }
}
