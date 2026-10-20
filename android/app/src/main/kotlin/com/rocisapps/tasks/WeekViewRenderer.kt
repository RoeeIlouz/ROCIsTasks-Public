package com.rocisapps.tasks

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Draws the Week View widget like ROCIs Schedule's weekly timetable: a day header
 * (today in an accent pill), an all-day strip when the week has any, an hour axis and
 * the week's classes, events and timed tasks as tinted blocks with a start-side accent
 * bar, overlapping items side by side. RemoteViews can't position views freely, so the
 * grid is one bitmap; the layout's column overlays handle taps.
 */
object WeekViewRenderer {

    /** Width of the hour axis; the layout's tap overlay spacer must match. */
    const val TIME_AXIS_DP = 26f

    // Like the Schedule grid: at least 08:00-20:00, grown to fit the week's items.
    private const val DEFAULT_START_HOUR = 8
    private const val DEFAULT_END_HOUR = 20
    // Below this an hour is unreadable; the grid then shows a window of hours instead.
    private const val MIN_HOUR_DP = 22f
    private const val HEADER_DP = 34f
    private const val ALL_DAY_ROW_DP = 14f
    private const val MIN_BLOCK_MINUTES = 30
    // Keeps the bitmap well under the RemoteViews bitmap memory limit.
    private const val MAX_PIXELS = 1_000_000f

    data class Item(
        val type: String,
        val title: String,
        val color: Int,
        val day: Int,
        val allDay: Boolean,
        val startMin: Int,
        val endMin: Int,
        /** All category colors (gradient when 2+); [color] is the first. */
        val colors: List<Int> = emptyList()
    )

    private data class Lane(val lane: Int, val lanes: Int)

    private val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss", Locale.US)
    private val keyFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US)

    fun dayKey(cal: Calendar): String = keyFormat.format(cal.time)

    /** Midnight of the first day of the week [offset] weeks from this one. */
    fun weekStart(offset: Int, startOfWeek: Int): Calendar {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val isoDay = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 + 1 // 1=Mon .. 7=Sun
        cal.add(Calendar.DAY_OF_YEAR, -((isoDay - startOfWeek + 7) % 7) + offset * 7)
        return cal
    }

    /**
     * The week's items from `today_agenda_data` (tasks, calendar events split per day,
     * Schedule classes). Items without an `end` (tasks) get the minimum block length.
     */
    fun loadItems(json: String, dayKeys: List<String>, fallbackColor: Int): List<Item> {
        val items = mutableListOf<Item>()
        val array = try { JSONArray(json) } catch (_: Exception) { return items }
        for (i in 0 until array.length()) {
            val obj = array.optJSONObject(i) ?: continue
            val dateOnly = obj.optString("dateOnly")
            val day = dayKeys.indexOf(dateOnly)
            if (day < 0) continue
            val allDay = obj.optBoolean("isAllDay", false)
            val start = parse(obj.optString("date"))
            var startMin = if (start == null || dayKey(start) != dateOnly) 0 else minuteOf(start)
            val end = parse(obj.optString("end"))
            var endMin = when {
                end == null -> startMin + MIN_BLOCK_MINUTES
                dayKey(end) > dateOnly -> 24 * 60
                dayKey(end) == dateOnly -> minuteOf(end)
                else -> startMin + MIN_BLOCK_MINUTES
            }
            startMin = startMin.coerceAtMost(24 * 60 - MIN_BLOCK_MINUTES)
            endMin = endMin.coerceIn(startMin + MIN_BLOCK_MINUTES, 24 * 60)
            items.add(
                Item(
                    type = obj.optString("type"),
                    title = obj.optString("title"),
                    color = WidgetStyle.parseColor(obj.optString("category_color"), fallbackColor),
                    day = day,
                    allDay = allDay,
                    startMin = startMin,
                    endMin = endMin,
                    colors = WidgetStyle.parseColors(obj)
                )
            )
        }
        return items
    }

    fun render(
        items: List<Item>,
        weekStart: Calendar,
        isCurrentWeek: Boolean,
        palette: FullCalendarWidgetUtils.Palette,
        locale: Locale,
        startOfWeek: Int,
        use24h: Boolean,
        widthDp: Float,
        heightDp: Float,
        density: Float
    ): Bitmap? {
        if (widthDp <= TIME_AXIS_DP || heightDp <= HEADER_DP) return null
        val scale = min(1f, sqrt(MAX_PIXELS / (widthDp * heightDp * density * density)))
        val d = density * scale
        val w = (widthDp * d).toInt().coerceAtLeast(1)
        val h = (heightDp * d).toInt().coerceAtLeast(1)
        return try {
            val bitmap = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            draw(Canvas(bitmap), w.toFloat(), h.toFloat(), d, items, weekStart, isCurrentWeek, palette, locale, startOfWeek, use24h)
            bitmap
        } catch (e: Exception) {
            android.util.Log.e("WeekViewRenderer", "Failed to draw week grid", e)
            null
        }
    }

    private fun draw(
        canvas: Canvas,
        w: Float,
        h: Float,
        d: Float,
        items: List<Item>,
        weekStart: Calendar,
        isCurrentWeek: Boolean,
        palette: FullCalendarWidgetUtils.Palette,
        locale: Locale,
        startOfWeek: Int,
        use24h: Boolean
    ) {
        val rtl = WidgetLocaleHelper.isRtl(locale)
        val onSurface = palette.onSurface
        val gridLine = WidgetStyle.withAlpha(onSurface, if (palette.isDark) 0x2E else 0x1F)
        val axisW = TIME_AXIS_DP * d
        val colW = (w - axisW) / 7f
        fun colLeft(col: Int): Float = if (rtl) w - axisW - (col + 1) * colW else axisW + col * colW
        val axisLeft = if (rtl) w - axisW else 0f

        val fill = Paint(Paint.ANTI_ALIAS_FLAG)
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = max(1f, 0.7f * d) }
        val text = TextPaint(Paint.ANTI_ALIAS_FLAG)

        // The rounded grid container (the Schedule grid's card), everything clipped to it.
        val radius = 12 * d
        val outer = RectF(0.5f, 0.5f, w - 0.5f, h - 0.5f)
        val clip = Path().apply { addRoundRect(outer, radius, radius, Path.Direction.CW) }
        canvas.save()
        canvas.clipPath(clip)

        // 1. Day header: weekday + day number, today highlighted like the Schedule's selected day.
        val headerH = HEADER_DP * d
        fill.color = WidgetStyle.withAlpha(onSurface, 0x0A)
        canvas.drawRect(0f, 0f, w, headerH, fill)
        val todayCol = if (isCurrentWeek) todayColumn(weekStart) else -1
        val lang = WidgetLocaleHelper.getNormalizedLanguage(locale)
        val names = if (colW >= 40 * d && lang !in setOf("he", "ar", "hi")) {
            WidgetLocaleHelper.getWeekdayShortNames(startOfWeek, locale).map { it.uppercase(locale) }
        } else {
            WidgetLocaleHelper.getWeekdayLetters(startOfWeek, locale)
        }
        val day = weekStart.clone() as Calendar
        for (col in 0..6) {
            val left = colLeft(col)
            val cx = left + colW / 2
            val isToday = col == todayCol
            if (isToday) {
                fill.color = WidgetStyle.withAlpha(palette.primary, 0x14)
                canvas.drawRect(left, 0f, left + colW, headerH, fill)
                fill.color = palette.primary
                canvas.drawRect(left, headerH - 2.5f * d, left + colW, headerH, fill)
            }
            text.textAlign = Paint.Align.CENTER
            text.typeface = Typeface.create("sans-serif", Typeface.BOLD)
            text.textSize = 9 * d
            text.color = if (isToday) palette.primary else WidgetStyle.withAlpha(onSurface, 0x99)
            canvas.drawText(fit(names[col], text, colW - 2 * d), cx, 12 * d, text)

            val number = day.get(Calendar.DAY_OF_MONTH).toString()
            text.textSize = 11 * d
            text.typeface = Typeface.create("sans-serif", if (isToday) Typeface.BOLD else Typeface.NORMAL)
            val numberY = 26 * d
            if (isToday) {
                val pillW = max(text.measureText(number) + 10 * d, 20 * d)
                fill.color = palette.primary
                canvas.drawRoundRect(cx - pillW / 2, numberY - 11 * d, cx + pillW / 2, numberY + 3.5f * d, 8 * d, 8 * d, fill)
                text.color = WidgetStyle.onColor(palette.primary)
            } else {
                text.color = onSurface
            }
            canvas.drawText(number, cx, numberY, text)
            day.add(Calendar.DAY_OF_YEAR, 1)
        }
        line.color = gridLine
        canvas.drawLine(0f, headerH, w, headerH, line)

        // 2. All-day strip (all-day events, undated tasks): up to two pills, then "+N".
        val allDay = items.filter { it.allDay }.groupBy { it.day }
        val rows = min(2, allDay.values.maxOfOrNull { it.size } ?: 0)
        var top = headerH
        if (rows > 0) {
            val stripH = rows * ALL_DAY_ROW_DP * d + 3 * d
            for ((col, dayItems) in allDay) {
                val left = colLeft(col)
                val shown = if (dayItems.size > rows) rows - 1 else rows
                for (row in 0 until rows) {
                    val pillTop = top + 2 * d + row * ALL_DAY_ROW_DP * d
                    val rect = RectF(left + 1.5f * d, pillTop, left + colW - 1.5f * d, pillTop + (ALL_DAY_ROW_DP - 2) * d)
                    text.textSize = 7.5f * d
                    text.typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                    if (row < shown && row < dayItems.size) {
                        val item = dayItems[row]
                        fill.color = blend(item.color, palette)
                        canvas.drawRoundRect(rect, 4 * d, 4 * d, fill)
                        text.color = onSurface
                        text.textAlign = Paint.Align.LEFT
                        val label = fit(item.title, text, rect.width() - 4 * d)
                        val labelW = text.measureText(label)
                        // Each title reads from its own script's side.
                        val labelX = if (startsRtl(item.title)) rect.right - 2 * d - labelW else rect.left + 2 * d
                        canvas.drawText(label, labelX, rect.centerY() + text.textSize / 3, text)
                    } else if (row == rows - 1 && dayItems.size > rows) {
                        text.color = WidgetStyle.withAlpha(onSurface, 0x99)
                        text.textAlign = Paint.Align.CENTER
                        canvas.drawText("+${dayItems.size - shown}", rect.centerX(), rect.centerY() + text.textSize / 3, text)
                    }
                }
            }
            top += stripH
            canvas.drawLine(0f, top, w, top, line)
        }

        // 3. Hour window: the Schedule's range, or as many readable hours as fit.
        val timed = items.filter { !it.allDay }
        var startHour = DEFAULT_START_HOUR
        var endHour = DEFAULT_END_HOUR
        for (item in timed) {
            startHour = min(startHour, item.startMin / 60)
            endHour = max(endHour, ceil(item.endMin / 60.0).toInt())
        }
        endHour = endHour.coerceAtMost(24)
        val gridH = h - top
        val total = endHour - startHour
        val fitHours = floor(gridH / (MIN_HOUR_DP * d)).toInt().coerceAtLeast(4)
        val visible = min(total, fitHours)
        var windowStart = startHour
        if (visible < total) {
            val anchor = if (isCurrentWeek) {
                Calendar.getInstance().get(Calendar.HOUR_OF_DAY) - 1
            } else {
                timed.minOfOrNull { it.startMin / 60 } ?: startHour
            }
            windowStart = anchor.coerceIn(startHour, endHour - visible)
        }
        val windowEnd = windowStart + visible
        val hourH = gridH / visible

        // Hour lines and labels.
        val hourFormat = SimpleDateFormat(
            android.text.format.DateFormat.getBestDateTimePattern(locale, if (use24h) "HH" else "h a"),
            locale
        )
        val labelCal = Calendar.getInstance()
        for (i in 0 until visible) {
            val y = top + i * hourH
            if (i > 0) {
                line.color = gridLine
                canvas.drawLine(if (rtl) 0f else axisW, y, if (rtl) w - axisW else w, y, line)
            }
            labelCal.set(Calendar.HOUR_OF_DAY, windowStart + i)
            labelCal.set(Calendar.MINUTE, 0)
            text.textSize = 8 * d
            text.typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            text.color = WidgetStyle.withAlpha(onSurface, 0x73)
            val label = shrinkToFit(hourFormat.format(labelCal.time), text, axisW - 4 * d)
            text.textAlign = Paint.Align.CENTER
            canvas.drawText(label, axisLeft + axisW / 2, y + text.textSize + 2 * d, text)
        }
        // Column dividers (and the axis edge).
        line.color = gridLine
        for (col in 0..6) {
            val x = if (rtl) colLeft(col) + colW else colLeft(col)
            canvas.drawLine(x, top, x, h, line)
        }
        if (todayCol >= 0) {
            fill.color = WidgetStyle.withAlpha(palette.primary, 0x0A)
            canvas.drawRect(colLeft(todayCol), top, colLeft(todayCol) + colW, h, fill)
        }

        // 4. Blocks, clipped to the hour window; dots mark items above or below it.
        canvas.save()
        canvas.clipRect(0f, top, w, h)
        for ((col, dayItems) in timed.groupBy { it.day }) {
            val lanes = layoutLanes(dayItems)
            val left = colLeft(col)
            var hiddenAbove = false
            var hiddenBelow = false
            dayItems.forEachIndexed { index, item ->
                if (item.endMin <= windowStart * 60) { hiddenAbove = true; return@forEachIndexed }
                if (item.startMin >= windowEnd * 60) { hiddenBelow = true; return@forEachIndexed }
                val lane = lanes[index]
                val laneW = (colW - 3 * d) / lane.lanes
                val blockW = laneW - if (lane.lanes > 1) 1.5f * d else 0f
                val x = if (rtl) left + colW - 1.5f * d - lane.lane * laneW - blockW else left + 1.5f * d + lane.lane * laneW
                val y = top + (item.startMin - windowStart * 60) / 60f * hourH + 1 * d
                val blockH = max((item.endMin - item.startMin) / 60f * hourH - 2 * d, 10 * d)
                drawBlock(canvas, RectF(x, y, x + blockW, y + blockH), item, palette, rtl, d, locale, use24h, fill, line, text)
            }
            val cx = left + colW / 2
            fill.color = WidgetStyle.withAlpha(onSurface, 0x73)
            if (hiddenAbove) canvas.drawCircle(cx, top + 3 * d, 1.6f * d, fill)
            if (hiddenBelow) canvas.drawCircle(cx, h - 3 * d, 1.6f * d, fill)
        }
        canvas.restore()

        canvas.restore()
        line.color = gridLine
        line.strokeWidth = max(1f, d)
        canvas.drawRoundRect(outer, radius, radius, line)
    }

    private fun drawBlock(
        canvas: Canvas,
        rect: RectF,
        item: Item,
        palette: FullCalendarWidgetUtils.Palette,
        rtl: Boolean,
        d: Float,
        locale: Locale,
        use24h: Boolean,
        fill: Paint,
        line: Paint,
        text: TextPaint
    ) {
        val r = 5 * d
        val multi = item.colors.size > 1
        fill.color = blend(item.color, palette)
        if (multi) {
            fill.shader = LinearGradient(
                rect.left, rect.top, rect.right, rect.bottom,
                IntArray(item.colors.size) { blend(item.colors[it], palette) }, null, Shader.TileMode.CLAMP
            )
        }
        canvas.drawRoundRect(rect, r, r, fill)
        fill.shader = null

        // Start-side accent bar, clipped to the rounded block.
        canvas.save()
        canvas.clipPath(Path().apply { addRoundRect(rect, r, r, Path.Direction.CW) })
        fill.color = item.color
        val barW = 3 * d
        if (multi) {
            fill.shader = LinearGradient(
                0f, rect.top, 0f, rect.bottom,
                IntArray(item.colors.size) { item.colors[it] }, null, Shader.TileMode.CLAMP
            )
        }
        if (rtl) canvas.drawRect(rect.right - barW, rect.top, rect.right, rect.bottom, fill)
        else canvas.drawRect(rect.left, rect.top, rect.left + barW, rect.bottom, fill)
        fill.shader = null

        val strokeColor = line.color
        val strokeWidth = line.strokeWidth
        line.color = WidgetStyle.withAlpha(item.color, 0x59)
        line.strokeWidth = max(1f, 0.8f * d)
        canvas.drawRoundRect(rect, r, r, line)

        // Content: tasks lead with an open circle (like a checkbox), then the title.
        val padStart = barW + 2 * d
        val padEnd = 1.5f * d
        val contentLeft = if (rtl) rect.left + padEnd else rect.left + padStart
        val contentRight = if (rtl) rect.right - padStart else rect.right - padEnd
        val contentW = contentRight - contentLeft
        if (contentW > 4 * d) {
            text.textSize = 8 * d
            text.typeface = Typeface.create("sans-serif", Typeface.BOLD)
            text.color = palette.onSurface
            text.textAlign = Paint.Align.LEFT
            var titleTop = rect.top + 2 * d
            if (item.type == "task") {
                val cr = 2.6f * d
                val cx = if (rtl) contentRight - cr - 0.5f * d else contentLeft + cr + 0.5f * d
                line.color = item.color
                line.strokeWidth = 1.1f * d
                canvas.drawCircle(cx, titleTop + text.textSize * 0.55f, cr, line)
            }
            val indent = if (item.type == "task") 7 * d else 0f
            val lineH = text.fontSpacing
            val showTime = rect.height() >= 3 * lineH + 4 * d
            val timeH = if (showTime) 9 * d else 0f
            val maxLines = floor((rect.height() - 3 * d - timeH) / lineH).toInt().coerceAtLeast(1)
            val title = item.title.ifEmpty { " " }
            canvas.save()
            canvas.clipRect(rect)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // The circle only indents the first line (the last indent repeats for the rest).
                val first = intArrayOf(indent.toInt(), 0)
                val none = intArrayOf(0)
                val layout = StaticLayout.Builder.obtain(title, 0, title.length, text, contentW.toInt().coerceAtLeast(1))
                    .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                    .setIncludePad(false)
                    .setMaxLines(maxLines)
                    .setEllipsize(TextUtils.TruncateAt.END)
                    .setIndents(if (rtl) none else first, if (rtl) first else none)
                    .build()
                canvas.translate(contentLeft, titleTop)
                layout.draw(canvas)
                titleTop += layout.height
            } else {
                val firstLineW = (contentW - indent).coerceAtLeast(1f)
                val single = TextUtils.ellipsize(title, text, firstLineW, TextUtils.TruncateAt.END).toString()
                val x = if (rtl) contentRight - indent - text.measureText(single) else contentLeft + indent
                canvas.drawText(single, x, titleTop + text.textSize, text)
                titleTop += lineH
            }
            canvas.restore()

            if (showTime && titleTop + timeH <= rect.bottom) {
                text.textSize = 7 * d
                text.typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
                text.color = item.color
                val cal = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, item.startMin / 60)
                    set(Calendar.MINUTE, item.startMin % 60)
                }
                val pattern = android.text.format.DateFormat.getBestDateTimePattern(locale, if (use24h) "Hm" else "hm")
                val time = fit(SimpleDateFormat(pattern, locale).format(cal.time), text, contentW)
                val x = if (rtl) contentRight - text.measureText(time) else contentLeft
                canvas.drawText(time, x, titleTop + 1 * d + text.textSize, text)
            }
        }
        canvas.restore()
        line.color = strokeColor
        line.strokeWidth = strokeWidth
    }

    /** Side-by-side lanes for overlapping items, same rule as the Schedule grid. */
    private fun layoutLanes(items: List<Item>): List<Lane> {
        val order = items.indices.sortedBy { items[it].startMin }
        val result = arrayOfNulls<Lane>(items.size)
        var cluster = mutableListOf<Pair<Int, Int>>() // item index, lane
        var laneEnds = mutableListOf<Int>()
        var clusterEnd = -1
        fun close() {
            cluster.forEach { (index, lane) -> result[index] = Lane(lane, laneEnds.size) }
            cluster = mutableListOf()
            laneEnds = mutableListOf()
        }
        for (index in order) {
            val item = items[index]
            if (item.startMin >= clusterEnd) close()
            var lane = laneEnds.indexOfFirst { it <= item.startMin }
            if (lane < 0) {
                lane = laneEnds.size
                laneEnds.add(item.endMin)
            } else {
                laneEnds[lane] = item.endMin
            }
            cluster.add(index to lane)
            clusterEnd = max(clusterEnd, item.endMin)
        }
        close()
        return result.map { it ?: Lane(0, 1) }
    }

    private fun todayColumn(weekStart: Calendar): Int {
        val today = dayKey(Calendar.getInstance())
        val day = weekStart.clone() as Calendar
        for (col in 0..6) {
            if (dayKey(day) == today) return col
            day.add(Calendar.DAY_OF_YEAR, 1)
        }
        return -1
    }

    /** The Schedule block tint: the item color at 16% (28% dark) over the card. */
    private fun blend(color: Int, palette: FullCalendarWidgetUtils.Palette): Int {
        val a = if (palette.isDark) 0.28f else 0.16f
        fun mix(c: Int, s: Int) = (c * a + s * (1 - a)).toInt()
        val s = palette.surface
        return android.graphics.Color.rgb(
            mix(android.graphics.Color.red(color), android.graphics.Color.red(s)),
            mix(android.graphics.Color.green(color), android.graphics.Color.green(s)),
            mix(android.graphics.Color.blue(color), android.graphics.Color.blue(s))
        )
    }

    private fun startsRtl(text: String): Boolean {
        for (ch in text) {
            when (Character.getDirectionality(ch)) {
                Character.DIRECTIONALITY_RIGHT_TO_LEFT,
                Character.DIRECTIONALITY_RIGHT_TO_LEFT_ARABIC -> return true
                Character.DIRECTIONALITY_LEFT_TO_RIGHT -> return false
            }
        }
        return false
    }

    private fun fit(value: String, paint: TextPaint, width: Float): String =
        if (width <= 0f) "" else TextUtils.ellipsize(value, paint, width, TextUtils.TruncateAt.END).toString()

    private fun shrinkToFit(value: String, paint: TextPaint, width: Float): String {
        while (paint.measureText(value) > width && paint.textSize > 5f) paint.textSize -= 0.5f
        return value
    }

    private fun minuteOf(cal: Calendar) = cal.get(Calendar.HOUR_OF_DAY) * 60 + cal.get(Calendar.MINUTE)

    private fun parse(iso: String?): Calendar? {
        if (iso.isNullOrEmpty() || iso.length < 19) return null
        return try {
            Calendar.getInstance().apply { time = isoFormat.parse(iso.substring(0, 19))!! }
        } catch (_: Exception) {
            null
        }
    }
}
