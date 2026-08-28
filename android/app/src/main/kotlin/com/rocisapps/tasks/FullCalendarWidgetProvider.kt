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
        const val ACTION_FILTER_TASKS = "com.rocisapps.tasks.ACTION_FILTER_TASKS"
        const val ACTION_FILTER_GOOGLE = "com.rocisapps.tasks.ACTION_FILTER_GOOGLE"
        const val ACTION_PREV_MONTH = "com.rocisapps.tasks.ACTION_PREV_MONTH"
        const val ACTION_NEXT_MONTH = "com.rocisapps.tasks.ACTION_NEXT_MONTH"
        const val ACTION_TODAY = "com.rocisapps.tasks.ACTION_TODAY"
        
        // Preference keys
        const val PREF_SHOW_TASKS = "full_calendar_show_tasks"
        const val PREF_SHOW_GOOGLE = "full_calendar_show_google"
        const val PREF_OFFSET = "full_calendar_offset"
        
        // Unique request codes
        private const val REQUEST_CODE_FILTER_TASKS = 301
        private const val REQUEST_CODE_FILTER_GOOGLE = 302
        private const val REQUEST_CODE_PREV_MONTH = 304
        private const val REQUEST_CODE_NEXT_MONTH = 305
        private const val REQUEST_CODE_TODAY = 306
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        
        appWidgetIds.forEach { appWidgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_full_calendar_layout)

                // Read theme and customization preferences
                val theme = widgetData.getString("full_calendar_theme", "system") ?: "system"
                val showWeekNumbers = widgetData.getBoolean("full_calendar_show_week_numbers", true)
                val weekendHighlight = widgetData.getBoolean("full_calendar_weekend_highlight", true)
                val highlightColorStr = widgetData.getString("full_calendar_highlight_color", "#EF3842") ?: "#EF3842"
                var primaryColor = android.graphics.Color.parseColor("#EF3842")
                try {
                    primaryColor = android.graphics.Color.parseColor(highlightColorStr)
                } catch (_: Exception) {}

                // 1. Apply Widget Theme Background
                val rootBgRes = when (theme) {
                    "light" -> R.drawable.widget_background_light
                    "dark" -> R.drawable.widget_background_dark
                    "glassmorphic" -> R.drawable.widget_background_glass
                    else -> R.drawable.widget_background
                }
                views.setInt(R.id.widget_full_calendar_root, "setBackgroundResource", rootBgRes)

                // 2. Set Text Colors depending on Theme
                val textColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#1C1C1E")
                    "dark", "glassmorphic" -> android.graphics.Color.parseColor("#FFFFFF")
                    else -> context.getColor(R.color.widget_title_text)
                }
                views.setTextColor(R.id.widget_full_calendar_title, textColor)
                views.setTextColor(R.id.widget_full_calendar_prev, textColor)
                views.setTextColor(R.id.widget_full_calendar_next, textColor)
                views.setTextColor(R.id.widget_full_calendar_today, primaryColor)
                views.setTextColor(R.id.widget_add_task_btn, primaryColor)

                // Weekday headers text colors
                val weekdayColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#2C2C2E")
                    "dark", "glassmorphic" -> android.graphics.Color.parseColor("#E5E5EA")
                    else -> context.getColor(R.color.widget_body_text)
                }
                val weekdaySecondaryColor = when (theme) {
                    "light" -> android.graphics.Color.parseColor("#8E8E93")
                    "dark", "glassmorphic" -> android.graphics.Color.parseColor("#AEAEB2")
                    else -> context.getColor(R.color.widget_secondary_text)
                }

                views.setTextColor(R.id.widget_weekday_num_header, weekdaySecondaryColor)

                // Dynamic Weekday headers text and colors based on startOfWeek
                val startOfWeek = widgetData.getInt("full_calendar_start_of_week", 7) // 7 = Sunday, 1 = Monday, 6 = Saturday
                val daysOfWeekLetters = listOf("M", "T", "W", "T", "F", "S", "S") // 1-indexed days of week: 1=Mon, ..., 7=Sun
                val weekdayViewIds = listOf(
                    R.id.widget_weekday_sun_header,
                    R.id.widget_weekday_mon_header,
                    R.id.widget_weekday_tue_header,
                    R.id.widget_weekday_wed_header,
                    R.id.widget_weekday_thu_header,
                    R.id.widget_weekday_fri_header,
                    R.id.widget_weekday_sat_header
                )

                for (col in 0..6) {
                    val dayOfWeek = (startOfWeek + col - 1) % 7 + 1
                    val letter = daysOfWeekLetters[dayOfWeek - 1]
                    val viewId = weekdayViewIds[col]
                    views.setTextViewText(viewId, letter)

                    val color = if (weekendHighlight) {
                        if (dayOfWeek == 7) {
                            android.graphics.Color.parseColor("#EF4444") // Red/Coral for Sunday (matches in-app calendar)
                        } else if (dayOfWeek == 6) {
                            android.graphics.Color.parseColor("#3B82F6") // Blue/Cyan for Saturday (matches in-app calendar)
                        } else {
                            weekdayColor
                        }
                    } else {
                        weekdayColor
                    }
                    views.setTextColor(viewId, color)
                }

                // Show / Hide Week Numbers column header
                views.setViewVisibility(R.id.widget_weekday_num_header, if (showWeekNumbers) android.view.View.VISIBLE else android.view.View.GONE)

                // 3. Title Update
                val savedMonthName = widgetData.getString("full_calendar_month_name", null)
                val monthName = if (!savedMonthName.isNullOrEmpty()) {
                    savedMonthName
                } else {
                    val cal = java.util.Calendar.getInstance()
                    val offset = widgetData.getInt(PREF_OFFSET, 0)
                    cal.add(java.util.Calendar.MONTH, offset)
                    java.text.SimpleDateFormat("MMMM yyyy", java.util.Locale.getDefault()).format(cal.time)
                }
                views.setTextViewText(R.id.widget_full_calendar_title, monthName)

                // 4. Header Navigation Buttons
                val prevIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
                    action = ACTION_PREV_MONTH
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val prevPendingIntent = android.app.PendingIntent.getBroadcast(
                    context, REQUEST_CODE_PREV_MONTH, prevIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_full_calendar_prev, prevPendingIntent)
                
                val nextIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
                    action = ACTION_NEXT_MONTH
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val nextPendingIntent = android.app.PendingIntent.getBroadcast(
                    context, REQUEST_CODE_NEXT_MONTH, nextIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_full_calendar_next, nextPendingIntent)
                
                val todayIntent = Intent(context, FullCalendarWidgetProvider::class.java).apply {
                    action = ACTION_TODAY
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                }
                val todayPendingIntent = android.app.PendingIntent.getBroadcast(
                    context, REQUEST_CODE_TODAY, todayIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_full_calendar_today, todayPendingIntent)

                // Open calendar tab when tapping the month title
                val calendarTabIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://calendar")
                )
                views.setOnClickPendingIntent(R.id.widget_full_calendar_title, calendarTabIntent)

                // Add Task Button
                val addTaskPendingIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("rocistasks://add_task")
                )
                views.setOnClickPendingIntent(R.id.widget_add_task_btn, addTaskPendingIntent)

                // 5. Filter Buttons - Pill toggle design
                val showTasks = widgetData.getBoolean(PREF_SHOW_TASKS, true)
                val showGoogle = widgetData.getBoolean(PREF_SHOW_GOOGLE, true)

                // Background pills
                views.setInt(
                    R.id.widget_filter_tasks,
                    "setBackgroundResource",
                    if (showTasks) R.drawable.widget_filter_button_active_bg else R.drawable.widget_filter_button_bg
                )
                views.setInt(
                    R.id.widget_filter_google,
                    "setBackgroundResource",
                    if (showGoogle) R.drawable.widget_filter_button_active_bg else R.drawable.widget_filter_button_bg
                )

                // Text colors
                views.setTextColor(R.id.widget_filter_tasks, if (showTasks) primaryColor else weekdaySecondaryColor)
                views.setTextColor(R.id.widget_filter_google, if (showGoogle) primaryColor else weekdaySecondaryColor)

                views.setViewVisibility(R.id.widget_filter_rocis, android.view.View.GONE)

                // Filter button click handlers
                setupFilterButtonIntents(context, views, appWidgetId)

                // 6. List Adapter
                val serviceIntent = Intent(context, FullCalendarWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("widget://rocis/full_calendar/$appWidgetId")
                }
                views.setRemoteAdapter(R.id.widget_full_calendar_list, serviceIntent)
                views.setEmptyView(R.id.widget_full_calendar_list, R.id.empty_full_calendar_view)

                val appIntent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                val appPendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    100 + appWidgetId,
                    appIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.widget_full_calendar_list, appPendingIntent)

                // 7. Finalize Update - Check Widget Allowance
                val isPremium = widgetData.getBoolean("is_premium", false)
                val isAllowed = WidgetLimitHelper.isWidgetAllowed(context, appWidgetId, isPremium)
                if (!isAllowed) {
                    views.setViewVisibility(R.id.widget_premium_overlay, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.widget_full_calendar_list, android.view.View.GONE)
                    views.setViewVisibility(R.id.widget_full_calendar_header, android.view.View.GONE)
                    views.setViewVisibility(R.id.widget_full_calendar_filters, android.view.View.GONE)
                    views.setViewVisibility(R.id.widget_full_calendar_weekdays, android.view.View.GONE)

                    val paywallIntent = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("rocistasks://paywall")
                    )
                    views.setOnClickPendingIntent(R.id.widget_premium_overlay, paywallIntent)
                } else {
                    views.setViewVisibility(R.id.widget_premium_overlay, android.view.View.GONE)
                    views.setViewVisibility(R.id.widget_full_calendar_list, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.widget_full_calendar_header, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.widget_full_calendar_filters, android.view.View.VISIBLE)
                    views.setViewVisibility(R.id.widget_full_calendar_weekdays, android.view.View.VISIBLE)
                }

                appWidgetManager.updateAppWidget(appWidgetId, views)
                try {
                    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_full_calendar_list)
                } catch (_: Exception) {}

                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_full_calendar_list)
                    } catch (_: Exception) {}
                }, 200)
            } catch (e: Exception) {
            }
        }
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
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        
        if (action == ACTION_FILTER_TASKS || action == ACTION_FILTER_GOOGLE || 
            action == ACTION_PREV_MONTH || action == ACTION_NEXT_MONTH || 
            action == ACTION_TODAY) {
            
            val widgetData = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
            val editor = widgetData.edit()
            
            when (action) {
                ACTION_FILTER_TASKS -> {
                    val current = widgetData.getBoolean(PREF_SHOW_TASKS, true)
                    editor.putBoolean(PREF_SHOW_TASKS, !current)
                }
                ACTION_FILTER_GOOGLE -> {
                    val current = widgetData.getBoolean(PREF_SHOW_GOOGLE, true)
                    editor.putBoolean(PREF_SHOW_GOOGLE, !current)
                }
                ACTION_PREV_MONTH -> {
                    val currentOffset = widgetData.getInt(PREF_OFFSET, 0)
                    editor.putInt(PREF_OFFSET, currentOffset - 1)
                    
                    val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                        context, Uri.parse("rocistasks://full_calendar_prev")
                    )
                    try {
                        backgroundIntent.send()
                    } catch (e: Exception) {}
                }
                ACTION_NEXT_MONTH -> {
                    val currentOffset = widgetData.getInt(PREF_OFFSET, 0)
                    editor.putInt(PREF_OFFSET, currentOffset + 1)
                    
                    val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                        context, Uri.parse("rocistasks://full_calendar_next")
                    )
                    try {
                        backgroundIntent.send()
                    } catch (e: Exception) {}
                }
                ACTION_TODAY -> {
                    editor.putInt(PREF_OFFSET, 0)
                    
                    val backgroundIntent = es.antonborri.home_widget.HomeWidgetBackgroundIntent.getBroadcast(
                        context, Uri.parse("rocistasks://full_calendar_today")
                    )
                    try {
                        backgroundIntent.send()
                    } catch (e: Exception) {}
                }
            }
            editor.apply()
            
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = android.content.ComponentName(context, FullCalendarWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            onUpdate(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }
}
