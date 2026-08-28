package com.rocisapps.tasks

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class FullCalendarWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return FullCalendarWidgetFactory(this.applicationContext)
    }
}

private data class FullCalendarCellIds(
    val rootId: Int,
    val fillId: Int,
    val strokeId: Int,
    val textId: Int,
    val eventBox1Id: Int,
    val eventFill1Id: Int,
    val eventStroke1Id: Int,
    val eventText1Id: Int,
    val eventBox2Id: Int,
    val eventFill2Id: Int,
    val eventStroke2Id: Int,
    val eventText2Id: Int,
    val dotsContainerId: Int,
    val dotIds: List<Int>
)

class FullCalendarWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val days = ArrayList<JSONObject>()
    private var showTasks = true
    private var showGoogle = true
    private var selectedDateStr = ""
    private var widgetTheme = "system"
    private var showWeekNumbers = true
    private var weekendHighlight = true
    private var highlightColor = Color.parseColor("#EF3842")

    private val dayCells = listOf(
        FullCalendarCellIds(
            R.id.widget_full_day_0,
            R.id.widget_full_day_fill_0,
            R.id.widget_full_day_stroke_0,
            R.id.widget_full_day_text_0,
            R.id.widget_full_event_box_0_1,
            R.id.widget_full_event_fill_0_1,
            R.id.widget_full_event_stroke_0_1,
            R.id.widget_full_event_text_0_1,
            R.id.widget_full_event_box_0_2,
            R.id.widget_full_event_fill_0_2,
            R.id.widget_full_event_stroke_0_2,
            R.id.widget_full_event_text_0_2,
            R.id.widget_full_dots_0,
            listOf(R.id.widget_full_dot_0_1, R.id.widget_full_dot_0_2, R.id.widget_full_dot_0_3, R.id.widget_full_dot_0_4)
        ),
        FullCalendarCellIds(
            R.id.widget_full_day_1,
            R.id.widget_full_day_fill_1,
            R.id.widget_full_day_stroke_1,
            R.id.widget_full_day_text_1,
            R.id.widget_full_event_box_1_1,
            R.id.widget_full_event_fill_1_1,
            R.id.widget_full_event_stroke_1_1,
            R.id.widget_full_event_text_1_1,
            R.id.widget_full_event_box_1_2,
            R.id.widget_full_event_fill_1_2,
            R.id.widget_full_event_stroke_1_2,
            R.id.widget_full_event_text_1_2,
            R.id.widget_full_dots_1,
            listOf(R.id.widget_full_dot_1_1, R.id.widget_full_dot_1_2, R.id.widget_full_dot_1_3, R.id.widget_full_dot_1_4)
        ),
        FullCalendarCellIds(
            R.id.widget_full_day_2,
            R.id.widget_full_day_fill_2,
            R.id.widget_full_day_stroke_2,
            R.id.widget_full_day_text_2,
            R.id.widget_full_event_box_2_1,
            R.id.widget_full_event_fill_2_1,
            R.id.widget_full_event_stroke_2_1,
            R.id.widget_full_event_text_2_1,
            R.id.widget_full_event_box_2_2,
            R.id.widget_full_event_fill_2_2,
            R.id.widget_full_event_stroke_2_2,
            R.id.widget_full_event_text_2_2,
            R.id.widget_full_dots_2,
            listOf(R.id.widget_full_dot_2_1, R.id.widget_full_dot_2_2, R.id.widget_full_dot_2_3, R.id.widget_full_dot_2_4)
        ),
        FullCalendarCellIds(
            R.id.widget_full_day_3,
            R.id.widget_full_day_fill_3,
            R.id.widget_full_day_stroke_3,
            R.id.widget_full_day_text_3,
            R.id.widget_full_event_box_3_1,
            R.id.widget_full_event_fill_3_1,
            R.id.widget_full_event_stroke_3_1,
            R.id.widget_full_event_text_3_1,
            R.id.widget_full_event_box_3_2,
            R.id.widget_full_event_fill_3_2,
            R.id.widget_full_event_stroke_3_2,
            R.id.widget_full_event_text_3_2,
            R.id.widget_full_dots_3,
            listOf(R.id.widget_full_dot_3_1, R.id.widget_full_dot_3_2, R.id.widget_full_dot_3_3, R.id.widget_full_dot_3_4)
        ),
        FullCalendarCellIds(
            R.id.widget_full_day_4,
            R.id.widget_full_day_fill_4,
            R.id.widget_full_day_stroke_4,
            R.id.widget_full_day_text_4,
            R.id.widget_full_event_box_4_1,
            R.id.widget_full_event_fill_4_1,
            R.id.widget_full_event_stroke_4_1,
            R.id.widget_full_event_text_4_1,
            R.id.widget_full_event_box_4_2,
            R.id.widget_full_event_fill_4_2,
            R.id.widget_full_event_stroke_4_2,
            R.id.widget_full_event_text_4_2,
            R.id.widget_full_dots_4,
            listOf(R.id.widget_full_dot_4_1, R.id.widget_full_dot_4_2, R.id.widget_full_dot_4_3, R.id.widget_full_dot_4_4)
        ),
        FullCalendarCellIds(
            R.id.widget_full_day_5,
            R.id.widget_full_day_fill_5,
            R.id.widget_full_day_stroke_5,
            R.id.widget_full_day_text_5,
            R.id.widget_full_event_box_5_1,
            R.id.widget_full_event_fill_5_1,
            R.id.widget_full_event_stroke_5_1,
            R.id.widget_full_event_text_5_1,
            R.id.widget_full_event_box_5_2,
            R.id.widget_full_event_fill_5_2,
            R.id.widget_full_event_stroke_5_2,
            R.id.widget_full_event_text_5_2,
            R.id.widget_full_dots_5,
            listOf(R.id.widget_full_dot_5_1, R.id.widget_full_dot_5_2, R.id.widget_full_dot_5_3, R.id.widget_full_dot_5_4)
        ),
        FullCalendarCellIds(
            R.id.widget_full_day_6,
            R.id.widget_full_day_fill_6,
            R.id.widget_full_day_stroke_6,
            R.id.widget_full_day_text_6,
            R.id.widget_full_event_box_6_1,
            R.id.widget_full_event_fill_6_1,
            R.id.widget_full_event_stroke_6_1,
            R.id.widget_full_event_text_6_1,
            R.id.widget_full_event_box_6_2,
            R.id.widget_full_event_fill_6_2,
            R.id.widget_full_event_stroke_6_2,
            R.id.widget_full_event_text_6_2,
            R.id.widget_full_dots_6,
            listOf(R.id.widget_full_dot_6_1, R.id.widget_full_dot_6_2, R.id.widget_full_dot_6_3, R.id.widget_full_dot_6_4)
        )
    )

    override fun onCreate() {
        onDataSetChanged()
    }

    override fun onDataSetChanged() {
        days.clear()
        try {
            val widgetData = HomeWidgetPlugin.getData(context)
            
            showTasks = widgetData.getBoolean(FullCalendarWidgetProvider.PREF_SHOW_TASKS, true)
            showGoogle = widgetData.getBoolean(FullCalendarWidgetProvider.PREF_SHOW_GOOGLE, true)
            selectedDateStr = widgetData.getString("full_calendar_selected_date", "") ?: ""
            if (selectedDateStr.isEmpty()) {
                val today = Calendar.getInstance()
                selectedDateStr = String.format("%04d-%02d-%02d", 
                    today.get(Calendar.YEAR),
                    today.get(Calendar.MONTH) + 1,
                    today.get(Calendar.DAY_OF_MONTH))
            }
            widgetTheme = widgetData.getString("full_calendar_theme", "system") ?: "system"
            showWeekNumbers = widgetData.getBoolean("full_calendar_show_week_numbers", true)
            weekendHighlight = widgetData.getBoolean("full_calendar_weekend_highlight", true)
            
            val highlightColorStr = widgetData.getString("full_calendar_highlight_color", "#EF3842") ?: "#EF3842"
            try {
                highlightColor = Color.parseColor(highlightColorStr)
            } catch (_: Exception) {
                highlightColor = Color.parseColor("#EF3842")
            }
            
            val gridDataJson = widgetData.getString("full_calendar_grid_data", "[]") ?: "[]"
            val gridData = JSONArray(gridDataJson)
            for (i in 0 until gridData.length()) {
                val day = gridData.getJSONObject(i)
                
                if (!day.optBoolean("isWeekNumber", false)) {
                    val summaries = day.optJSONArray("summaries")
                    if (summaries != null) {
                        val filteredSummaries = JSONArray()
                        for (j in 0 until summaries.length()) {
                            val summary = summaries.getJSONObject(j)
                            val type = summary.optString("type", "")
                            
                            val shouldInclude = when (type) {
                                "task" -> showTasks
                                "google" -> showGoogle
                                else -> true
                            }
                            
                            if (shouldInclude) {
                                filteredSummaries.put(summary)
                            }
                        }
                        day.put("summaries", filteredSummaries)
                    }
                }
                
                days.add(day)
            }

            if (days.isEmpty()) {
                generateFallbackCalendar(widgetData)
            }
        } catch (e: Exception) {
            android.util.Log.e("FullCalendarWidget", "Error parsing widget data", e)
            try {
                val widgetData = HomeWidgetPlugin.getData(context)
                generateFallbackCalendar(widgetData)
            } catch (_: Exception) {}
        }
    }

    private fun generateFallbackCalendar(widgetData: android.content.SharedPreferences) {
        days.clear()
        val offset = widgetData.getInt(FullCalendarWidgetProvider.PREF_OFFSET, 0)
        val startOfWeek = widgetData.getInt("full_calendar_start_of_week", 7) // 7 = Sun, 1 = Mon, 6 = Sat

        val cal = Calendar.getInstance()
        cal.set(Calendar.DAY_OF_MONTH, 1)
        cal.add(Calendar.MONTH, offset)
        val targetMonth = cal.get(Calendar.MONTH)

        // Find difference for startOfWeek
        val javaDayOfWeek = cal.get(Calendar.DAY_OF_WEEK) // 1=Sun, 2=Mon...
        val dayOfWeekNormalized = if (javaDayOfWeek == Calendar.SUNDAY) 7 else javaDayOfWeek - 1 // 1=Mon, ..., 7=Sun
        val diff = (dayOfWeekNormalized - startOfWeek + 7) % 7
        cal.add(Calendar.DAY_OF_MONTH, -diff)

        val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        for (row in 0 until 6) {
            val weekObj = JSONObject()
            weekObj.put("isWeekNumber", true)
            weekObj.put("weekNumber", cal.get(Calendar.WEEK_OF_YEAR))
            days.add(weekObj)

            for (col in 0 until 7) {
                val dayObj = JSONObject()
                dayObj.put("isWeekNumber", false)
                dayObj.put("date", dateFormat.format(cal.time))
                dayObj.put("day", cal.get(Calendar.DAY_OF_MONTH))
                dayObj.put("isCurrentMonth", cal.get(Calendar.MONTH) == targetMonth)
                dayObj.put("summaries", JSONArray())
                days.add(dayObj)

                cal.add(Calendar.DAY_OF_MONTH, 1)
            }
        }
    }

    override fun onDestroy() {
        days.clear()
    }

    override fun getCount(): Int {
        return days.size / 8
    }

    override fun getViewAt(position: Int): RemoteViews {
        val rowViews = RemoteViews(context.packageName, R.layout.widget_full_calendar_row)
        try {
            val startIndex = position * 8
            if (startIndex >= days.size) return rowViews

            // 1. Week Number Column
            val weekObj = days[startIndex]
            val weekNum = weekObj.optInt("weekNumber", 0)
            rowViews.setTextViewText(R.id.widget_full_week_num_text, weekNum.toString())
            rowViews.setViewVisibility(
                R.id.widget_full_week_num_root,
                if (showWeekNumbers) View.VISIBLE else View.GONE
            )

            val weekColor = when (widgetTheme) {
                "light" -> Color.parseColor("#8E8E93")
                "dark", "glassmorphic" -> Color.parseColor("#AEAEB2")
                else -> context.getColor(R.color.widget_secondary_text)
            }
            rowViews.setTextColor(R.id.widget_full_week_num_text, weekColor)

            // Current date calculation
            val today = Calendar.getInstance()
            val currentTodayStr = String.format("%04d-%02d-%02d", 
                today.get(Calendar.YEAR),
                today.get(Calendar.MONTH) + 1,
                today.get(Calendar.DAY_OF_MONTH))

            // 2. 7 Days in the Row
            val dateFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            for (d in 0 until 7) {
                val cell = dayCells[d]
                val cellIndex = startIndex + 1 + d
                if (cellIndex >= days.size) {
                    rowViews.setViewVisibility(cell.rootId, View.INVISIBLE)
                    continue
                }
                rowViews.setViewVisibility(cell.rootId, View.VISIBLE)

                val day = days[cellIndex]
                val dayNum = day.optInt("day", 1)
                val dateStr = day.optString("date", "")
                val isCurrentMonth = day.optBoolean("isCurrentMonth", true)

                val isToday = dateStr == currentTodayStr
                val isSelected = dateStr.isNotEmpty() && dateStr == selectedDateStr && !isToday

                var dayOfWeek = 0
                try {
                    val dateObj = dateFormat.parse(dateStr)
                    if (dateObj != null) {
                        val cal = Calendar.getInstance()
                        cal.time = dateObj
                        dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
                    }
                } catch (_: Exception) {}

                rowViews.setTextViewText(cell.textId, dayNum.toString())

                // Background & Stroke highlights
                if (isToday) {
                    val fillColor = (highlightColor and 0x00FFFFFF) or (0xFF shl 24)
                    rowViews.setViewVisibility(cell.fillId, View.VISIBLE)
                    rowViews.setInt(cell.fillId, "setColorFilter", fillColor)
                    rowViews.setInt(cell.fillId, "setImageAlpha", 0x33) // 20% opacity for today
                    rowViews.setViewVisibility(cell.strokeId, View.GONE)
                } else if (isSelected) {
                    val strokeColor = (highlightColor and 0x00FFFFFF) or (0xFF shl 24)
                    rowViews.setViewVisibility(cell.strokeId, View.VISIBLE)
                    rowViews.setInt(cell.strokeId, "setColorFilter", strokeColor)
                    rowViews.setViewVisibility(cell.fillId, View.GONE)
                } else {
                    rowViews.setViewVisibility(cell.fillId, View.GONE)
                    rowViews.setViewVisibility(cell.strokeId, View.GONE)
                }

                // Text Color matching in-app TableCalendar cell
                val textColor = if (isToday || isSelected) {
                    highlightColor
                } else if (isCurrentMonth) {
                    if (weekendHighlight && dayOfWeek == Calendar.SUNDAY) {
                        Color.parseColor("#EF4444") // Coral red
                    } else if (weekendHighlight && dayOfWeek == Calendar.SATURDAY) {
                        Color.parseColor("#3B82F6") // Electric blue
                    } else {
                        when (widgetTheme) {
                            "light" -> Color.parseColor("#1C1C1E")
                            "dark", "glassmorphic" -> Color.parseColor("#FFFFFF")
                            else -> context.getColor(R.color.widget_title_text)
                        }
                    }
                } else {
                    // Outside current month (30% faded opacity)
                    when (widgetTheme) {
                        "light" -> Color.parseColor("#4D1C1C1E")
                        "dark", "glassmorphic" -> Color.parseColor("#4DFFFFFF")
                        else -> Color.parseColor("#4D8E8E93")
                    }
                }
                rowViews.setTextColor(cell.textId, textColor)

                // Event micro-pills / dots
                val summaries = day.optJSONArray("summaries") ?: JSONArray()
                val count = summaries.length()

                if (count == 1) {
                    // 1 Event: Show single event snippet box with tint fill, colored border and text
                    val ev1 = summaries.getJSONObject(0)
                    val title1 = ev1.optString("text", "")
                    val colorHex1 = ev1.optString("color", "")
                    val evColor1 = if (colorHex1.isNotEmpty()) {
                        try { Color.parseColor(colorHex1) } catch (_: Exception) { highlightColor }
                    } else highlightColor

                    val alphaColor1 = (evColor1 and 0x00FFFFFF) or (0xFF shl 24)
                    rowViews.setInt(cell.eventFill1Id, "setColorFilter", alphaColor1)
                    rowViews.setInt(cell.eventFill1Id, "setImageAlpha", 0x26) // 15% opacity tint fill

                    rowViews.setInt(cell.eventStroke1Id, "setColorFilter", alphaColor1)
                    rowViews.setInt(cell.eventStroke1Id, "setImageAlpha", 0x80) // 50% opacity colored border

                    rowViews.setTextViewText(cell.eventText1Id, title1)
                    rowViews.setTextColor(cell.eventText1Id, alphaColor1)

                    rowViews.setViewVisibility(cell.eventBox1Id, View.VISIBLE)
                    rowViews.setViewVisibility(cell.eventBox2Id, View.GONE)
                    rowViews.setViewVisibility(cell.dotsContainerId, View.GONE)
                    for (k in 0 until 4) {
                        rowViews.setViewVisibility(cell.dotIds[k], View.GONE)
                    }
                } else if (count == 2) {
                    // 2 Events: Show two event snippet boxes with tint fill, colored border and text
                    val ev1 = summaries.getJSONObject(0)
                    val title1 = ev1.optString("text", "")
                    val colorHex1 = ev1.optString("color", "")
                    val evColor1 = if (colorHex1.isNotEmpty()) {
                        try { Color.parseColor(colorHex1) } catch (_: Exception) { highlightColor }
                    } else highlightColor

                    val alphaColor1 = (evColor1 and 0x00FFFFFF) or (0xFF shl 24)
                    rowViews.setInt(cell.eventFill1Id, "setColorFilter", alphaColor1)
                    rowViews.setInt(cell.eventFill1Id, "setImageAlpha", 0x26)
                    rowViews.setInt(cell.eventStroke1Id, "setColorFilter", alphaColor1)
                    rowViews.setInt(cell.eventStroke1Id, "setImageAlpha", 0x80)
                    rowViews.setTextViewText(cell.eventText1Id, title1)
                    rowViews.setTextColor(cell.eventText1Id, alphaColor1)
                    rowViews.setViewVisibility(cell.eventBox1Id, View.VISIBLE)

                    val ev2 = summaries.getJSONObject(1)
                    val title2 = ev2.optString("text", "")
                    val colorHex2 = ev2.optString("color", "")
                    val evColor2 = if (colorHex2.isNotEmpty()) {
                        try { Color.parseColor(colorHex2) } catch (_: Exception) { highlightColor }
                    } else highlightColor

                    val alphaColor2 = (evColor2 and 0x00FFFFFF) or (0xFF shl 24)
                    rowViews.setInt(cell.eventFill2Id, "setColorFilter", alphaColor2)
                    rowViews.setInt(cell.eventFill2Id, "setImageAlpha", 0x26)
                    rowViews.setInt(cell.eventStroke2Id, "setColorFilter", alphaColor2)
                    rowViews.setInt(cell.eventStroke2Id, "setImageAlpha", 0x80)
                    rowViews.setTextViewText(cell.eventText2Id, title2)
                    rowViews.setTextColor(cell.eventText2Id, alphaColor2)
                    rowViews.setViewVisibility(cell.eventBox2Id, View.VISIBLE)

                    rowViews.setViewVisibility(cell.dotsContainerId, View.GONE)
                    for (k in 0 until 4) {
                        rowViews.setViewVisibility(cell.dotIds[k], View.GONE)
                    }
                } else if (count > 2) {
                    // > 2 Events: Hide snippet boxes and show glowing colored dots row
                    rowViews.setViewVisibility(cell.eventBox1Id, View.GONE)
                    rowViews.setViewVisibility(cell.eventBox2Id, View.GONE)
                    rowViews.setViewVisibility(cell.dotsContainerId, View.VISIBLE)
                    val maxDots = minOf(4, count)
                    for (k in 0 until 4) {
                        val dotViewId = cell.dotIds[k]
                        if (k < maxDots) {
                            val summary = summaries.getJSONObject(k)
                            val colorHex = summary.optString("color", "")
                            val dotColor = if (colorHex.isNotEmpty()) {
                                try {
                                    Color.parseColor(colorHex)
                                } catch (_: Exception) {
                                    highlightColor
                                }
                            } else {
                                highlightColor
                            }
                            val alphaColor = (dotColor and 0x00FFFFFF) or (0xFF shl 24)
                            rowViews.setViewVisibility(dotViewId, View.VISIBLE)
                            rowViews.setInt(dotViewId, "setColorFilter", alphaColor)
                        } else {
                            rowViews.setViewVisibility(dotViewId, View.GONE)
                        }
                    }
                } else {
                    // 0 Events
                    rowViews.setViewVisibility(cell.eventBox1Id, View.GONE)
                    rowViews.setViewVisibility(cell.eventBox2Id, View.GONE)
                    rowViews.setViewVisibility(cell.dotsContainerId, View.GONE)
                    for (k in 0 until 4) {
                        rowViews.setViewVisibility(cell.dotIds[k], View.GONE)
                    }
                }

                // Click Intent to open app directly to calendar
                if (dateStr.isNotEmpty()) {
                    val fillInIntent = Intent().apply {
                        action = Intent.ACTION_VIEW
                        data = Uri.parse("rocistasks://calendar")
                    }
                    rowViews.setOnClickFillInIntent(cell.rootId, fillInIntent)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("FullCalendarWidget", "Error rendering row", e)
        }

        return rowViews
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}
