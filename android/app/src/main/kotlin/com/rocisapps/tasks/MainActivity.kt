package com.rocisapps.tasks

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.rocisapps.tasks/notifications"
    private val WIDGET_CHANNEL = "com.rocisapps.tasks/widget"
    private lateinit var notificationHelper: NotificationHelper
    private var widgetChannel: MethodChannel? = null

    companion object {
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        notificationHelper = NotificationHelper(this)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            if (call.method == "updateTaskCountIcon") {
                val count = call.argument<Int>("count") ?: 0
                val titles = call.argument<List<String>>("titles") ?: emptyList()
                val largeIconPath = call.argument<String>("largeIconPath")
                val isDarkText = call.argument<Boolean>("isDarkText") ?: false
                notificationHelper.showTaskCountNotification(count, titles, largeIconPath, isDarkText)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Set up widget channel for deep link communication BEFORE handling intent
        widgetChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)

        // Handle initial intent after channels are set up
        handleIntent(intent, channel)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // Update the intent so HomeWidget can read it
        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
        handleIntent(intent, channel)
    }

    private fun handleIntent(intent: android.content.Intent?, channel: MethodChannel) {
        
        if (intent?.action == NotificationHelper.ACTION_ADD_TASK) {
            channel.invokeMethod("onNotificationAction", "add_task")
            return
        }
        
        // Handle widget deep links
        val data = intent?.data
        if (data != null && data.scheme == "rocistasks") {
            // Send the URI to Flutter via the widget channel
            if (widgetChannel != null) {
                widgetChannel?.invokeMethod("onWidgetClick", data.toString())
            } else {
            }
        } else {
        }
    }
}
