package com.rocisapps.tasks

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class UpNextWidgetProvider : HomeWidgetProvider() {

    companion object {
        private const val REQ_REFRESH = 701
        private const val MINUTE = 60_000L
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val isPremium = widgetData.getBoolean("is_premium", false)
        val now = System.currentTimeMillis()
        val startMillis = readStartMillis(widgetData)

        appWidgetIds.forEach { appWidgetId ->
            try {
                val isAllowed = WidgetLimitHelper.isWidgetAllowed(context, appWidgetId, isPremium)
                val views = RemoteViews(context.packageName, R.layout.widget_up_next_layout)

                // 1. The app's card, RTL.
                val palette = WidgetStyle.palette(context, widgetData)
                val widgetLocale = WidgetLocaleHelper.getWidgetLocale(widgetData)
                WidgetStyle.applyCard(views, palette, R.id.widget_up_next_card_fill, R.id.widget_up_next_card_stroke)
                WidgetStyle.applyDirection(views, R.id.widget_up_next_root, widgetLocale)

                views.setTextViewText(R.id.widget_up_next_header_label, upNextText(widgetLocale).uppercase(widgetLocale))
                views.setTextColor(R.id.widget_up_next_header_label, palette.primary)
                views.setTextColor(R.id.widget_up_next_title, palette.onSurface)
                views.setTextColor(R.id.widget_up_next_subtitle, palette.onSurfaceMuted)

                // 2. Data written by WidgetDataService.updateUpNextWidget.
                val rawType = widgetData.getString("up_next_type", "none") ?: "none"
                val id = widgetData.getString("up_next_id", "") ?: ""
                val rawTitle = widgetData.getString("up_next_title", "") ?: ""
                val subtitle = widgetData.getString("up_next_subtitle", "") ?: ""
                val fallbackTime = widgetData.getString("up_next_time_display", "") ?: ""
                val type = if (id.isEmpty() || rawTitle.isEmpty() || rawType == "none") "none" else rawType

                if (type == "none") {
                    renderCaughtUp(context, views, palette, widgetLocale)
                } else {
                    val accent = WidgetStyle.parseColor(widgetData.getString("up_next_color", ""), palette.primary)
                    views.setViewVisibility(R.id.widget_up_next_color_strip, View.VISIBLE)
                    views.setInt(R.id.widget_up_next_color_strip, "setColorFilter", accent)
                    views.setViewVisibility(R.id.widget_up_next_done_icon, View.GONE)
                    views.setViewVisibility(R.id.widget_up_next_add_btn, View.GONE)
                    views.setTextViewText(R.id.widget_up_next_title, rawTitle)
                    views.setTextViewText(R.id.widget_up_next_subtitle, subtitle)
                    views.setViewVisibility(R.id.widget_up_next_subtitle, if (subtitle.isEmpty()) View.GONE else View.VISIBLE)

                    renderTimeChip(context, views, palette, widgetLocale, type, startMillis, fallbackTime, now)

                    if (type == "task") {
                        views.setViewVisibility(R.id.widget_up_next_check, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_up_next_event_icon, View.GONE)
                        views.setImageViewResource(R.id.widget_up_next_check, R.drawable.ic_widget_check_off)
                        views.setInt(R.id.widget_up_next_check, "setColorFilter", palette.onSurfaceMuted)
                        views.setOnClickPendingIntent(
                            R.id.widget_up_next_check,
                            HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("rocistasks://complete?id=$id"))
                        )
                        views.setOnClickPendingIntent(
                            R.id.widget_up_next_main,
                            HomeWidgetLaunchIntent.getActivity(
                                context, MainActivity::class.java, Uri.parse("rocistasks://task_item?id=$id")
                            )
                        )
                    } else {
                        views.setViewVisibility(R.id.widget_up_next_check, View.GONE)
                        views.setViewVisibility(R.id.widget_up_next_event_icon, View.VISIBLE)
                        views.setInt(R.id.widget_up_next_event_icon, "setColorFilter", accent)
                        // Events open the in-app calendar on their day.
                        val uri = if (startMillis > 0) {
                            val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(startMillis))
                            "rocistasks://calendar?date=$day"
                        } else {
                            "rocistasks://calendar"
                        }
                        views.setOnClickPendingIntent(
                            R.id.widget_up_next_main,
                            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))
                        )
                    }
                }

                WidgetStyle.setupProOverlay(context, views, isAllowed, palette, widgetLocale)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                android.util.Log.e("UpNextWidget", "Error updating widget $appWidgetId", e)
            }
        }

        val hasItem = (widgetData.getString("up_next_id", "") ?: "").isNotEmpty() &&
            widgetData.getString("up_next_type", "none") != "none"
        scheduleRefresh(context, if (hasItem) startMillis else -1L, now)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        try {
            (context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager)?.cancel(refreshIntent(context))
        } catch (_: Exception) {}
    }

    private fun renderCaughtUp(
        context: Context,
        views: RemoteViews,
        palette: FullCalendarWidgetUtils.Palette,
        locale: Locale
    ) {
        views.setViewVisibility(R.id.widget_up_next_color_strip, View.GONE)
        views.setViewVisibility(R.id.widget_up_next_check, View.GONE)
        views.setViewVisibility(R.id.widget_up_next_event_icon, View.GONE)
        views.setViewVisibility(R.id.widget_up_next_done_icon, View.VISIBLE)
        views.setInt(R.id.widget_up_next_done_icon, "setColorFilter", palette.primary)
        views.setViewVisibility(R.id.widget_up_next_time_box, View.GONE)

        views.setTextViewText(R.id.widget_up_next_title, WidgetLocaleHelper.getAllCaughtUpText(locale))
        views.setTextViewText(R.id.widget_up_next_subtitle, WidgetLocaleHelper.getTapPlusToAddText(locale))
        views.setViewVisibility(R.id.widget_up_next_subtitle, View.VISIBLE)

        views.setViewVisibility(R.id.widget_up_next_add_btn, View.VISIBLE)
        views.setInt(R.id.widget_up_next_add_btn, "setColorFilter", palette.primary)
        views.setOnClickPendingIntent(
            R.id.widget_up_next_add_btn,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://add_task"))
        )
        views.setOnClickPendingIntent(
            R.id.widget_up_next_main,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://home"))
        )
    }

    /** Relative time chip: accent pill; solid when it's happening now, red when a task is overdue. */
    private fun renderTimeChip(
        context: Context,
        views: RemoteViews,
        palette: FullCalendarWidgetUtils.Palette,
        locale: Locale,
        type: String,
        startMillis: Long,
        fallback: String,
        now: Long
    ) {
        var chipColor = palette.primary
        var solid = false
        val text: String = if (startMillis <= 0L) {
            // Undated task (or older data without millis).
            if (startMillis == -1L) WidgetLocaleHelper.getTodayText(locale) else fallback
        } else {
            val diff = startMillis - now
            when {
                diff < -15 * MINUTE && type == "task" -> {
                    chipColor = WidgetStyle.PRIORITY_HIGH
                    WidgetStyle.overdueText(locale)
                }
                diff in (-15 * MINUTE)..MINUTE -> {
                    solid = true
                    nowText(locale)
                }
                diff in MINUTE until 60 * MINUTE -> inMinutesText(((diff + MINUTE - 1) / MINUTE).toInt().coerceIn(1, 59), locale)
                else -> formatStart(context, startMillis, now, locale)
            }
        }

        if (text.isEmpty()) {
            views.setViewVisibility(R.id.widget_up_next_time_box, View.GONE)
            return
        }
        views.setViewVisibility(R.id.widget_up_next_time_box, View.VISIBLE)
        views.setTextViewText(R.id.widget_up_next_time_badge, text)
        views.setInt(R.id.widget_up_next_time_fill, "setColorFilter", chipColor)
        views.setInt(R.id.widget_up_next_time_fill, "setImageAlpha", if (solid) 0xFF else 0x26)
        views.setTextColor(R.id.widget_up_next_time_badge, if (solid) WidgetStyle.onColor(chipColor) else chipColor)
    }

    /** Same day: time; tomorrow: "Tomorrow time"; later: short date, all in the widget locale. */
    private fun formatStart(context: Context, startMillis: Long, now: Long, locale: Locale): String {
        val start = Calendar.getInstance().apply { timeInMillis = startMillis }
        val today = Calendar.getInstance().apply { timeInMillis = now }
        val skeleton = if (DateFormat.is24HourFormat(context)) "Hm" else "hm"
        val time = SimpleDateFormat(DateFormat.getBestDateTimePattern(locale, skeleton), locale).format(start.time)
        val tomorrow = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
        return when {
            isSameDay(start, today) -> time
            isSameDay(start, tomorrow) -> "${WidgetLocaleHelper.getTomorrowText(locale)} $time"
            else -> SimpleDateFormat(DateFormat.getBestDateTimePattern(locale, "MMMd"), locale).format(start.time)
        }
    }

    private fun isSameDay(a: Calendar, b: Calendar): Boolean =
        a.get(Calendar.YEAR) == b.get(Calendar.YEAR) && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)

    /** HomeWidget may store the epoch millis as Long, Int or (older builds) String. */
    private fun readStartMillis(widgetData: SharedPreferences): Long {
        return when (val raw = widgetData.all["up_next_start_millis"]) {
            is Long -> raw
            is Int -> raw.toLong()
            is Number -> raw.toLong()
            is String -> raw.toLongOrNull() ?: 0L
            else -> 0L
        }
    }

    /**
     * Re-renders the widget when its relative time changes: every minute while the item is
     * within the next hour (or happening now), otherwise when it enters that hour or at midnight.
     */
    private fun scheduleRefresh(context: Context, startMillis: Long, now: Long) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val midnight = Calendar.getInstance().apply {
                timeInMillis = now
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 5)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val triggerAt = if (startMillis <= 0L) {
                midnight
            } else {
                val diff = startMillis - now
                when {
                    diff > 60 * MINUTE -> minOf(startMillis - 60 * MINUTE, midnight)
                    diff > -15 * MINUTE -> (now / MINUTE + 1) * MINUTE
                    else -> midnight
                }
            }
            alarmManager.set(AlarmManager.RTC, triggerAt, refreshIntent(context))
        } catch (e: Exception) {
            android.util.Log.w("UpNextWidget", "Could not schedule refresh", e)
        }
    }

    private fun refreshIntent(context: Context): PendingIntent {
        val ids = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, UpNextWidgetProvider::class.java))
        val intent = Intent(context, UpNextWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        return PendingIntent.getBroadcast(
            context, REQ_REFRESH, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun upNextText(locale: Locale): String = when (WidgetLocaleHelper.getNormalizedLanguage(locale)) {
        "he" -> "הבא בתור"; "es" -> "A continuación"; "de" -> "Als Nächstes"; "fr" -> "À suivre"
        "ar" -> "التالي"; "sv" -> "Härnäst"; "hi" -> "आगे"; else -> "Up next"
    }

    private fun nowText(locale: Locale): String = when (WidgetLocaleHelper.getNormalizedLanguage(locale)) {
        "he" -> "עכשיו"; "es" -> "Ahora"; "de" -> "Jetzt"; "fr" -> "Maintenant"
        "ar" -> "الآن"; "sv" -> "Nu"; "hi" -> "अभी"; else -> "Now"
    }

    private fun inMinutesText(minutes: Int, locale: Locale): String = when (WidgetLocaleHelper.getNormalizedLanguage(locale)) {
        "he" -> "בעוד $minutes דק׳"; "es" -> "en $minutes min"; "de" -> "in $minutes Min."
        "fr" -> "dans $minutes min"; "ar" -> "بعد $minutes د"; "sv" -> "om $minutes min"
        "hi" -> "$minutes मिनट में"; else -> "in $minutes min"
    }
}
