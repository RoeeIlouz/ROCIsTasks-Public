package com.rocisapps.tasks

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.Typeface
import android.net.Uri
import android.text.SpannableString
import android.text.Spanned
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Draws the FullCalendar widget's week rows the same way the in-app calendar
 * draws its cells: day number at the top; at the bottom 1-2 event pills, or
 * three dots plus "+N" for busier days. Only the weeks the month needs are
 * shown (4-6), and they share the widget's height.
 */
object FullCalendarGridRenderer {

    private data class CellIds(
        val root: Int, val fill: Int, val stroke: Int, val text: Int,
        val pills: List<Triple<Int, Int, Int>>, // box, fill, stroke
        val pillTexts: List<Int>,
        val dots: Int, val dotIds: List<Int>, val more: Int
    )

    // Explicit ids (no reflection: R8 may strip or rename R fields in release).
    private val dayIds = listOf(
        CellIds(
            root = R.id.widget_full_day_0,
            fill = R.id.widget_full_day_fill_0,
            stroke = R.id.widget_full_day_stroke_0,
            text = R.id.widget_full_day_text_0,
            pills = listOf(
                Triple(R.id.widget_full_event_box_0_1, R.id.widget_full_event_fill_0_1, R.id.widget_full_event_stroke_0_1),
                Triple(R.id.widget_full_event_box_0_2, R.id.widget_full_event_fill_0_2, R.id.widget_full_event_stroke_0_2)
            ),
            pillTexts = listOf(R.id.widget_full_event_text_0_1, R.id.widget_full_event_text_0_2),
            dots = R.id.widget_full_dots_0,
            dotIds = listOf(R.id.widget_full_dot_0_1, R.id.widget_full_dot_0_2, R.id.widget_full_dot_0_3),
            more = R.id.widget_full_more_0
        ),
        CellIds(
            root = R.id.widget_full_day_1,
            fill = R.id.widget_full_day_fill_1,
            stroke = R.id.widget_full_day_stroke_1,
            text = R.id.widget_full_day_text_1,
            pills = listOf(
                Triple(R.id.widget_full_event_box_1_1, R.id.widget_full_event_fill_1_1, R.id.widget_full_event_stroke_1_1),
                Triple(R.id.widget_full_event_box_1_2, R.id.widget_full_event_fill_1_2, R.id.widget_full_event_stroke_1_2)
            ),
            pillTexts = listOf(R.id.widget_full_event_text_1_1, R.id.widget_full_event_text_1_2),
            dots = R.id.widget_full_dots_1,
            dotIds = listOf(R.id.widget_full_dot_1_1, R.id.widget_full_dot_1_2, R.id.widget_full_dot_1_3),
            more = R.id.widget_full_more_1
        ),
        CellIds(
            root = R.id.widget_full_day_2,
            fill = R.id.widget_full_day_fill_2,
            stroke = R.id.widget_full_day_stroke_2,
            text = R.id.widget_full_day_text_2,
            pills = listOf(
                Triple(R.id.widget_full_event_box_2_1, R.id.widget_full_event_fill_2_1, R.id.widget_full_event_stroke_2_1),
                Triple(R.id.widget_full_event_box_2_2, R.id.widget_full_event_fill_2_2, R.id.widget_full_event_stroke_2_2)
            ),
            pillTexts = listOf(R.id.widget_full_event_text_2_1, R.id.widget_full_event_text_2_2),
            dots = R.id.widget_full_dots_2,
            dotIds = listOf(R.id.widget_full_dot_2_1, R.id.widget_full_dot_2_2, R.id.widget_full_dot_2_3),
            more = R.id.widget_full_more_2
        ),
        CellIds(
            root = R.id.widget_full_day_3,
            fill = R.id.widget_full_day_fill_3,
            stroke = R.id.widget_full_day_stroke_3,
            text = R.id.widget_full_day_text_3,
            pills = listOf(
                Triple(R.id.widget_full_event_box_3_1, R.id.widget_full_event_fill_3_1, R.id.widget_full_event_stroke_3_1),
                Triple(R.id.widget_full_event_box_3_2, R.id.widget_full_event_fill_3_2, R.id.widget_full_event_stroke_3_2)
            ),
            pillTexts = listOf(R.id.widget_full_event_text_3_1, R.id.widget_full_event_text_3_2),
            dots = R.id.widget_full_dots_3,
            dotIds = listOf(R.id.widget_full_dot_3_1, R.id.widget_full_dot_3_2, R.id.widget_full_dot_3_3),
            more = R.id.widget_full_more_3
        ),
        CellIds(
            root = R.id.widget_full_day_4,
            fill = R.id.widget_full_day_fill_4,
            stroke = R.id.widget_full_day_stroke_4,
            text = R.id.widget_full_day_text_4,
            pills = listOf(
                Triple(R.id.widget_full_event_box_4_1, R.id.widget_full_event_fill_4_1, R.id.widget_full_event_stroke_4_1),
                Triple(R.id.widget_full_event_box_4_2, R.id.widget_full_event_fill_4_2, R.id.widget_full_event_stroke_4_2)
            ),
            pillTexts = listOf(R.id.widget_full_event_text_4_1, R.id.widget_full_event_text_4_2),
            dots = R.id.widget_full_dots_4,
            dotIds = listOf(R.id.widget_full_dot_4_1, R.id.widget_full_dot_4_2, R.id.widget_full_dot_4_3),
            more = R.id.widget_full_more_4
        ),
        CellIds(
            root = R.id.widget_full_day_5,
            fill = R.id.widget_full_day_fill_5,
            stroke = R.id.widget_full_day_stroke_5,
            text = R.id.widget_full_day_text_5,
            pills = listOf(
                Triple(R.id.widget_full_event_box_5_1, R.id.widget_full_event_fill_5_1, R.id.widget_full_event_stroke_5_1),
                Triple(R.id.widget_full_event_box_5_2, R.id.widget_full_event_fill_5_2, R.id.widget_full_event_stroke_5_2)
            ),
            pillTexts = listOf(R.id.widget_full_event_text_5_1, R.id.widget_full_event_text_5_2),
            dots = R.id.widget_full_dots_5,
            dotIds = listOf(R.id.widget_full_dot_5_1, R.id.widget_full_dot_5_2, R.id.widget_full_dot_5_3),
            more = R.id.widget_full_more_5
        ),
        CellIds(
            root = R.id.widget_full_day_6,
            fill = R.id.widget_full_day_fill_6,
            stroke = R.id.widget_full_day_stroke_6,
            text = R.id.widget_full_day_text_6,
            pills = listOf(
                Triple(R.id.widget_full_event_box_6_1, R.id.widget_full_event_fill_6_1, R.id.widget_full_event_stroke_6_1),
                Triple(R.id.widget_full_event_box_6_2, R.id.widget_full_event_fill_6_2, R.id.widget_full_event_stroke_6_2)
            ),
            pillTexts = listOf(R.id.widget_full_event_text_6_1, R.id.widget_full_event_text_6_2),
            dots = R.id.widget_full_dots_6,
            dotIds = listOf(R.id.widget_full_dot_6_1, R.id.widget_full_dot_6_2, R.id.widget_full_dot_6_3),
            more = R.id.widget_full_more_6
        )
    )

    /** Summaries per date from the Dart-built map, filtered by the widget's source toggles. */
    fun loadSummariesByDate(widgetData: SharedPreferences): Map<String, JSONArray> {
        val showTasks = widgetData.getBoolean(FullCalendarWidgetUtils.PREF_SHOW_TASKS, true)
        val showGoogle = widgetData.getBoolean(FullCalendarWidgetUtils.PREF_SHOW_GOOGLE, true)
        val showSchedule = widgetData.getBoolean(FullCalendarWidgetUtils.PREF_SHOW_SCHEDULE, true)
        val result = HashMap<String, JSONArray>()
        try {
            val json = widgetData.getString(FullCalendarWidgetUtils.PREF_EVENTS_BY_DATE, "") ?: ""
            if (json.isEmpty()) return result
            val byDate = JSONObject(json)
            for (date in byDate.keys()) {
                val all = byDate.optJSONArray(date) ?: continue
                val kept = JSONArray()
                for (i in 0 until all.length()) {
                    val summary = all.optJSONObject(i) ?: continue
                    val type = summary.optString("type", "")
                    if (FullCalendarWidgetUtils.shouldIncludeSummary(type, showTasks, showGoogle, showSchedule)) {
                        kept.put(summary)
                    }
                }
                result[date] = kept
            }
        } catch (e: Exception) {
            android.util.Log.e("FullCalendarWidget", "Error reading summaries", e)
        }
        return result
    }

    fun buildRows(
        context: Context,
        widgetData: SharedPreferences,
        palette: FullCalendarWidgetUtils.Palette,
        isRtl: Boolean
    ): List<RemoteViews> {
        val offset = widgetData.getInt(FullCalendarWidgetUtils.PREF_OFFSET, 0)
        val startOfWeek = widgetData.getInt(
            FullCalendarWidgetUtils.PREF_START_OF_WEEK, FullCalendarWidgetUtils.DEFAULT_START_OF_WEEK
        )
        val showWeekNumbers = widgetData.getBoolean(
            FullCalendarWidgetUtils.PREF_SHOW_WEEK_NUMBERS, FullCalendarWidgetUtils.DEFAULT_SHOW_WEEK_NUMBERS
        )
        val weekendHighlight = widgetData.getBoolean(FullCalendarWidgetUtils.PREF_WEEKEND_HIGHLIGHT, true)
        val selectedDate = widgetData.getString(FullCalendarWidgetUtils.PREF_SELECTED_DATE, "") ?: ""

        val grid = FullCalendarWidgetUtils.buildCalendarGrid(offset, startOfWeek, loadSummariesByDate(widgetData))
        val today = Calendar.getInstance()
        val todayStr = String.format(
            java.util.Locale.US, "%04d-%02d-%02d",
            today.get(Calendar.YEAR), today.get(Calendar.MONTH) + 1, today.get(Calendar.DAY_OF_MONTH)
        )

        val rows = ArrayList<RemoteViews>()
        for (row in 0 until grid.size / 8) {
            val week = grid.subList(row * 8, row * 8 + 8)
            val days = week.drop(1)
            // Like the app, skip weeks with no day of the displayed month.
            if (days.none { it.optBoolean("isCurrentMonth", false) }) continue

            val views = RemoteViews(context.packageName, R.layout.widget_full_calendar_row)
            views.setInt(
                R.id.widget_full_calendar_row_root, "setLayoutDirection",
                if (isRtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
            )
            views.setViewVisibility(R.id.widget_full_week_num_root, if (showWeekNumbers) View.VISIBLE else View.GONE)
            views.setTextViewText(R.id.widget_full_week_num_text, week[0].optInt("weekNumber", 0).toString())
            views.setTextColor(R.id.widget_full_week_num_text, palette.onSurfaceFaded)

            days.forEachIndexed { col, day ->
                renderCell(context, views, dayIds[col], day, palette, todayStr, selectedDate, weekendHighlight)
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
        todayStr: String,
        selectedDate: String,
        weekendHighlight: Boolean
    ) {
        val dateStr = day.optString("date", "")
        val isCurrentMonth = day.optBoolean("isCurrentMonth", true)
        val isToday = dateStr == todayStr
        val isSelected = dateStr.isNotEmpty() && dateStr == selectedDate && !isToday

        // Background: today = 10% accent tint, selected = accent outline (as in the app).
        views.setViewVisibility(ids.fill, if (isToday) View.VISIBLE else View.GONE)
        views.setViewVisibility(ids.stroke, if (isSelected) View.VISIBLE else View.GONE)
        if (isToday) {
            views.setInt(ids.fill, "setColorFilter", palette.primary)
            views.setInt(ids.fill, "setImageAlpha", 0x1A)
        }
        if (isSelected) views.setInt(ids.stroke, "setColorFilter", palette.primary)

        val weekday = weekdayOf(dateStr)
        val textColor = when {
            isToday || isSelected -> palette.primary
            !isCurrentMonth -> palette.onSurfaceFaded
            weekendHighlight && weekday == Calendar.SUNDAY -> FullCalendarWidgetUtils.SUNDAY_COLOR
            weekendHighlight && weekday == Calendar.SATURDAY -> FullCalendarWidgetUtils.SATURDAY_COLOR
            else -> palette.onSurface
        }
        val label = SpannableString(day.optInt("day", 1).toString())
        if (isToday || isSelected) {
            label.setSpan(StyleSpan(Typeface.BOLD), 0, label.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
        }
        views.setTextViewText(ids.text, label)
        views.setTextColor(ids.text, textColor)

        // Markers
        val summaries = day.optJSONArray("summaries") ?: JSONArray()
        val count = summaries.length()
        val showPills = count in 1..2
        for (i in 0..1) {
            val (box, fill, stroke) = ids.pills[i]
            if (showPills && i < count) {
                val summary = summaries.getJSONObject(i)
                val color = parseColor(summary.optString("color", ""), palette.primary)
                views.setInt(fill, "setColorFilter", color)
                views.setInt(fill, "setImageAlpha", 0x26) // 15% fill
                views.setInt(stroke, "setColorFilter", color)
                views.setInt(stroke, "setImageAlpha", 0x59) // 35% border
                views.setTextViewText(ids.pillTexts[i], summary.optString("text", ""))
                views.setTextColor(ids.pillTexts[i], color)
                views.setViewVisibility(box, View.VISIBLE)
            } else {
                views.setViewVisibility(box, View.GONE)
            }
        }

        if (count > 2) {
            views.setViewVisibility(ids.dots, View.VISIBLE)
            for (k in 0..2) {
                val color = parseColor(summaries.getJSONObject(k).optString("color", ""), palette.primary)
                views.setInt(ids.dotIds[k], "setColorFilter", color)
                views.setViewVisibility(ids.dotIds[k], View.VISIBLE)
            }
            if (count > 3) {
                views.setTextViewText(ids.more, "+${count - 3}")
                views.setTextColor(ids.more, palette.onSurfaceMuted)
                views.setViewVisibility(ids.more, View.VISIBLE)
            } else {
                views.setViewVisibility(ids.more, View.GONE)
            }
        } else {
            views.setViewVisibility(ids.dots, View.GONE)
        }

        // Tapping a day opens the calendar on that date.
        if (dateStr.isNotEmpty()) {
            views.setOnClickPendingIntent(
                ids.root,
                HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java, Uri.parse("rocistasks://calendar?date=$dateStr")
                )
            )
        }
    }

    private fun weekdayOf(dateStr: String): Int = try {
        val parts = dateStr.split("-")
        Calendar.getInstance().apply {
            set(parts[0].toInt(), parts[1].toInt() - 1, parts[2].toInt())
        }.get(Calendar.DAY_OF_WEEK)
    } catch (_: Exception) {
        0
    }

    private fun parseColor(hex: String, fallback: Int): Int {
        if (hex.isEmpty()) return fallback
        return try {
            (Color.parseColor(hex) and 0x00FFFFFF) or (0xFF shl 24)
        } catch (_: Exception) {
            fallback
        }
    }
}
