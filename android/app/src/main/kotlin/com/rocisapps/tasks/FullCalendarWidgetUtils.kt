package com.rocisapps.tasks

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Shared utility functions, constants, theme resolvers, and calendar date math
 * for Full Calendar Android home widgets.
 */
object FullCalendarWidgetUtils {
    private const val TAG = "FullCalendarWidgetUtils"

    // Filter toggle and navigation actions
    const val ACTION_FILTER_TASKS = "com.rocisapps.tasks.ACTION_FILTER_TASKS"
    const val ACTION_FILTER_GOOGLE = "com.rocisapps.tasks.ACTION_FILTER_GOOGLE"
    const val ACTION_FILTER_ROCIS = "com.rocisapps.tasks.ACTION_FILTER_ROCIS"
    const val ACTION_PREV_MONTH = "com.rocisapps.tasks.ACTION_PREV_MONTH"
    const val ACTION_NEXT_MONTH = "com.rocisapps.tasks.ACTION_NEXT_MONTH"
    const val ACTION_TODAY = "com.rocisapps.tasks.ACTION_TODAY"

    // SharedPreferences keys
    const val PREF_SHOW_TASKS = "full_calendar_show_tasks"
    const val PREF_SHOW_GOOGLE = "full_calendar_show_google"
    const val PREF_SHOW_SCHEDULE = "full_calendar_show_schedule"
    const val PREF_OFFSET = "full_calendar_offset"
    const val PREF_THEME = "full_calendar_theme"
    const val PREF_SHOW_WEEK_NUMBERS = "full_calendar_show_week_numbers"
    const val PREF_WEEKEND_HIGHLIGHT = "full_calendar_weekend_highlight"
    const val PREF_HIGHLIGHT_COLOR = "full_calendar_highlight_color"
    const val PREF_START_OF_WEEK = "full_calendar_start_of_week"
    const val PREF_SELECTED_DATE = "full_calendar_selected_date"
    const val PREF_GRID_DATA = "full_calendar_grid_data"
    const val PREF_IS_PREMIUM = "is_premium"

    // Defaults
    const val DEFAULT_HIGHLIGHT_COLOR = "#EF3842"
    const val DEFAULT_THEME = "system"
    const val DEFAULT_START_OF_WEEK = 7 // Sunday

    // Unique PendingIntent request codes
    const val REQUEST_CODE_FILTER_TASKS = 301
    const val REQUEST_CODE_FILTER_GOOGLE = 302
    const val REQUEST_CODE_FILTER_ROCIS = 303
    const val REQUEST_CODE_PREV_MONTH = 304
    const val REQUEST_CODE_NEXT_MONTH = 305
    const val REQUEST_CODE_TODAY = 306

    /**
     * Parse highlight color safely from SharedPreferences with fallback to [DEFAULT_HIGHLIGHT_COLOR].
     */
    fun parseHighlightColor(widgetData: SharedPreferences, defaultHex: String = DEFAULT_HIGHLIGHT_COLOR): Int {
        val hex = widgetData.getString(PREF_HIGHLIGHT_COLOR, defaultHex) ?: defaultHex
        return try {
            Color.parseColor(hex)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse highlight color '$hex', falling back to default $defaultHex", e)
            Color.parseColor(defaultHex)
        }
    }

    /**
     * Resolves the title / primary text color based on widget theme.
     */
    fun getTextColor(theme: String, context: Context): Int {
        return when (theme) {
            "light" -> Color.parseColor("#1C1C1E")
            "dark", "glassmorphic" -> Color.parseColor("#FFFFFF")
            else -> context.getColor(R.color.widget_title_text)
        }
    }

    /**
     * Resolves weekday header text color based on widget theme.
     */
    fun getWeekdayColor(theme: String, context: Context): Int {
        return when (theme) {
            "light" -> Color.parseColor("#2C2C2E")
            "dark", "glassmorphic" -> Color.parseColor("#E5E5EA")
            else -> context.getColor(R.color.widget_body_text)
        }
    }

    /**
     * Resolves secondary text color (e.g. week numbers, inactive filter buttons) based on widget theme.
     */
    fun getSecondaryTextColor(theme: String, context: Context): Int {
        return when (theme) {
            "light" -> Color.parseColor("#8E8E93")
            "dark", "glassmorphic" -> Color.parseColor("#AEAEB2")
            else -> context.getColor(R.color.widget_secondary_text)
        }
    }

    /**
     * Resolves text color for days outside the current month (30% opacity).
     */
    fun getFadedTextColor(theme: String): Int {
        return when (theme) {
            "light" -> Color.parseColor("#4D1C1C1E")
            "dark", "glassmorphic" -> Color.parseColor("#4DFFFFFF")
            else -> Color.parseColor("#4D8E8E93")
        }
    }

    /**
     * Resolves root background drawable resource based on widget theme.
     */
    fun getThemeBackgroundRes(theme: String): Int {
        return when (theme) {
            "light" -> R.drawable.widget_background_light
            "dark" -> R.drawable.widget_background_dark
            "glassmorphic" -> R.drawable.widget_background_glass
            else -> R.drawable.widget_background
        }
    }

    /**
     * Filter predicate determining whether an event summary should be displayed based on active filters.
     */
    fun shouldIncludeSummary(
        type: String,
        showTasks: Boolean,
        showGoogle: Boolean,
        showSchedule: Boolean
    ): Boolean {
        return when (type) {
            "task" -> showTasks
            "google" -> showGoogle
            "schedule", "rocis" -> showSchedule
            else -> true
        }
    }

    /**
     * Builds a 6-row by 7-column calendar grid (48 objects total: 6 week headers + 42 day cells).
     * If an error occurs, logs an error message and falls back to a populated empty grid so the
     * widget layout never collapses.
     */
    fun buildCalendarGrid(
        offset: Int,
        startOfWeek: Int,
        summariesByDate: Map<String, JSONArray> = emptyMap()
    ): ArrayList<JSONObject> {
        val days = ArrayList<JSONObject>()
        try {
            val cal = Calendar.getInstance()
            cal.set(Calendar.DAY_OF_MONTH, 1)
            if (offset != 0) {
                cal.add(Calendar.MONTH, offset)
            }
            val targetMonth = cal.get(Calendar.MONTH)

            val javaDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) // 1=Sun, 2=Mon...
            val dayOfWeekNormalized = if (javaDayOfWeek == Calendar.SUNDAY) 7 else javaDayOfWeek - 1 // 1=Mon, ..., 7=Sun
            val diff = (dayOfWeekNormalized - startOfWeek + 7) % 7
            cal.add(Calendar.DAY_OF_MONTH, -diff)

            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            for (row in 0 until 6) {
                val weekObj = JSONObject().apply {
                    put("isWeekNumber", true)
                    put("weekNumber", cal.get(Calendar.WEEK_OF_YEAR))
                }
                days.add(weekObj)

                for (col in 0 until 7) {
                    val dateStr = dateFormat.format(cal.time)
                    val dayObj = JSONObject().apply {
                        put("isWeekNumber", false)
                        put("date", dateStr)
                        put("day", cal.get(Calendar.DAY_OF_MONTH))
                        put("isCurrentMonth", cal.get(Calendar.MONTH) == targetMonth)
                        put("summaries", summariesByDate[dateStr] ?: JSONArray())
                    }
                    days.add(dayObj)

                    cal.add(Calendar.DAY_OF_MONTH, 1)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error building calendar grid (offset=$offset, startOfWeek=$startOfWeek). Generating fallback grid.", e)
            if (days.size < 48) {
                days.clear()
                buildEmptyFallbackGrid(days, offset, startOfWeek)
            }
        }
        return days
    }

    private fun buildEmptyFallbackGrid(
        days: ArrayList<JSONObject>,
        offset: Int,
        startOfWeek: Int
    ) {
        try {
            val cal = Calendar.getInstance()
            cal.set(Calendar.DAY_OF_MONTH, 1)
            if (offset != 0) {
                cal.add(Calendar.MONTH, offset)
            }
            val targetMonth = cal.get(Calendar.MONTH)
            val javaDayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
            val dayOfWeekNormalized = if (javaDayOfWeek == Calendar.SUNDAY) 7 else javaDayOfWeek - 1
            val diff = (dayOfWeekNormalized - startOfWeek + 7) % 7
            cal.add(Calendar.DAY_OF_MONTH, -diff)

            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            for (row in 0 until 6) {
                days.add(JSONObject().apply {
                    put("isWeekNumber", true)
                    put("weekNumber", cal.get(Calendar.WEEK_OF_YEAR))
                })
                for (col in 0 until 7) {
                    days.add(JSONObject().apply {
                        put("isWeekNumber", false)
                        put("date", dateFormat.format(cal.time))
                        put("day", cal.get(Calendar.DAY_OF_MONTH))
                        put("isCurrentMonth", cal.get(Calendar.MONTH) == targetMonth)
                        put("summaries", JSONArray())
                    })
                    cal.add(Calendar.DAY_OF_MONTH, 1)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Critical failure generating emergency fallback calendar grid", e)
        }
    }
}

