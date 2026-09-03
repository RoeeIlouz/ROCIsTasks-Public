package com.rocisapps.tasks

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

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

                val theme = widgetData.getString("full_calendar_theme", "system") ?: "system"
                val rootBgRes = when (theme) {
                    "light" -> R.drawable.widget_background_light
                    "dark" -> R.drawable.widget_background_dark
                    "glassmorphic" -> R.drawable.widget_background_glass
                    else -> R.drawable.widget_background
                }
                views.setInt(R.id.widget_quick_action_root, "setBackgroundResource", rootBgRes)

                val highlightColorHex = widgetData.getString("full_calendar_highlight_color", "#6366F1") ?: "#6366F1"
                val highlightColor = try {
                    Color.parseColor(highlightColorHex)
                } catch (_: Exception) {
                    Color.parseColor("#6366F1")
                }

                val textColor = when (theme) {
                    "light" -> Color.parseColor("#0F172A")
                    else -> Color.parseColor("#FFFFFF")
                }
                val secondaryColor = when (theme) {
                    "light" -> Color.parseColor("#64748B")
                    else -> Color.parseColor("#94A3B8")
                }

                views.setTextColor(R.id.widget_quick_stat_number, textColor)
                views.setTextColor(R.id.widget_quick_stat_label, secondaryColor)
                views.setTextColor(R.id.widget_quick_btn_add_icon, highlightColor)
                views.setTextColor(R.id.widget_quick_btn_add_text, textColor)
                views.setTextColor(R.id.widget_quick_btn_cal_text, textColor)
                views.setInt(R.id.widget_quick_calendar_icon, "setColorFilter", highlightColor)

                // Load Circular Chart if available, otherwise show number fallback
                val chartPath = widgetData.getString("chart_image_path", null)
                var hasChart = false
                if (chartPath != null && File(chartPath).exists()) {
                    val bitmap = BitmapFactory.decodeFile(chartPath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_quick_chart_img, bitmap)
                        views.setViewVisibility(R.id.widget_quick_chart_img, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_quick_stat_container, View.GONE)
                        hasChart = true
                    }
                }

                if (!hasChart) {
                    views.setViewVisibility(R.id.widget_quick_chart_img, View.GONE)
                    views.setViewVisibility(R.id.widget_quick_stat_container, View.VISIBLE)
                    val pendingCount = widgetData.getInt("quick_action_pending_count", 0)
                    views.setTextViewText(R.id.widget_quick_stat_number, if (pendingCount > 99) "99+" else "$pendingCount")
                }

                // Button actions
                val addTaskIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://add_task")
                )
                views.setOnClickPendingIntent(R.id.widget_quick_btn_add_task, addTaskIntent)

                val calIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://calendar")
                )
                views.setOnClickPendingIntent(R.id.widget_quick_btn_calendar, calIntent)

                val homeIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://home")
                )
                views.setOnClickPendingIntent(R.id.widget_quick_progress_container, homeIntent)

                // Pro limit overlay
                WidgetLimitHelper.setupProOverlay(context, views, isAllowed)

                appWidgetManager.updateAppWidget(appWidgetId, views)
            } catch (e: Exception) {
                android.util.Log.e("QuickActionWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }
}
