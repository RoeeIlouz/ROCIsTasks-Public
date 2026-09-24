package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

class QuickActionWidgetProvider : HomeWidgetProvider() {

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
                val views = RemoteViews(context.packageName, R.layout.widget_quick_action_layout)

                // 1. The app's card, tinted tiles, RTL.
                val palette = WidgetStyle.palette(context, widgetData)
                val widgetLocale = WidgetLocaleHelper.getWidgetLocale(widgetData)
                WidgetStyle.applyCard(views, palette, R.id.widget_quick_card_fill, R.id.widget_quick_card_stroke)
                WidgetStyle.applyDirection(views, R.id.widget_quick_action_root, widgetLocale)

                // Primary action: accent-tinted tile; secondary: faint onSurface wash (like list tiles).
                WidgetStyle.applyTile(views, R.id.widget_quick_btn_add_fill, palette.primary, 0x1F)
                WidgetStyle.applyTile(views, R.id.widget_quick_btn_cal_fill, palette.onSurface, if (palette.isDark) 0x14 else 0x0D)
                WidgetStyle.tint(views, palette.primary, R.id.widget_quick_btn_add_icon, R.id.widget_quick_calendar_icon)
                views.setTextViewText(R.id.widget_quick_btn_add_text, WidgetLocaleHelper.getNewTaskText(widgetLocale))
                views.setTextViewText(R.id.widget_quick_btn_cal_text, WidgetLocaleHelper.getCalendarText(widgetLocale))
                views.setTextColor(R.id.widget_quick_btn_add_text, palette.onSurface)
                views.setTextColor(R.id.widget_quick_btn_cal_text, palette.onSurface)

                // 2. Today's progress (pending / completed today, written by updateQuickActionWidget).
                val pendingCount = readCount(widgetData, "quick_action_pending_count")
                val completedCount = readCount(widgetData, "quick_action_completed_count")
                views.setTextViewText(R.id.widget_quick_stat_number, if (pendingCount > 99) "99+" else "$pendingCount")
                views.setTextColor(R.id.widget_quick_stat_number, palette.onSurface)
                views.setTextViewText(R.id.widget_quick_stat_label, WidgetLocaleHelper.getPendingLeftText(widgetLocale))
                views.setTextColor(R.id.widget_quick_stat_label, palette.onSurfaceMuted)
                views.setTextViewText(R.id.widget_quick_done_label, doneText(completedCount, widgetLocale))
                views.setTextColor(R.id.widget_quick_done_label, palette.primary)

                val total = pendingCount + completedCount
                val progress = if (total == 0) 0f else completedCount.toFloat() / total
                val ring = drawRing(
                    context, progress, palette.primary,
                    WidgetStyle.withAlpha(palette.onSurface, if (palette.isDark) 0x26 else 0x1A),
                    WidgetLocaleHelper.isRtl(widgetLocale)
                )
                if (ring != null) views.setImageViewBitmap(R.id.widget_quick_ring, ring)

                // 3. Actions
                views.setOnClickPendingIntent(
                    R.id.widget_quick_btn_add_task,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://add_task"))
                )
                views.setOnClickPendingIntent(
                    R.id.widget_quick_btn_calendar,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://calendar"))
                )
                views.setOnClickPendingIntent(
                    R.id.widget_quick_progress_container,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse("rocistasks://home"))
                )

                WidgetStyle.setupProOverlay(context, views, isAllowed, palette, widgetLocale)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                android.util.Log.e("QuickActionWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    /** HomeWidget stores Dart ints as Int or Long depending on the platform channel. */
    private fun readCount(widgetData: SharedPreferences, key: String): Int =
        when (val raw = widgetData.all[key]) {
            is Number -> raw.toInt()
            is String -> raw.toIntOrNull() ?: 0
            else -> 0
        }.coerceAtLeast(0)

    /** Today's completion ring: faint track plus an accent arc with round caps (mirrored in RTL). */
    private fun drawRing(context: Context, progress: Float, accent: Int, track: Int, rtl: Boolean): Bitmap? {
        return try {
            val density = context.resources.displayMetrics.density
            val size = (60 * density).toInt().coerceAtLeast(1)
            val stroke = 5 * density
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val inset = stroke / 2 + density
            val oval = RectF(inset, inset, size - inset, size - inset)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = stroke
                strokeCap = Paint.Cap.ROUND
            }
            paint.color = track
            canvas.drawOval(oval, paint)
            if (progress > 0f) {
                paint.color = accent
                val sweep = 360f * progress.coerceIn(0f, 1f)
                canvas.drawArc(oval, -90f, if (rtl) -sweep else sweep, false, paint)
            }
            bitmap
        } catch (_: Exception) {
            null
        }
    }

    private fun doneText(count: Int, locale: Locale): String = when (WidgetLocaleHelper.getNormalizedLanguage(locale)) {
        "he" -> "$count הושלמו"; "es" -> "$count hechas"; "de" -> "$count erledigt"; "fr" -> "$count faites"
        "ar" -> "$count مكتملة"; "sv" -> "$count klara"; "hi" -> "$count पूर्ण"; else -> "$count done"
    }
}
