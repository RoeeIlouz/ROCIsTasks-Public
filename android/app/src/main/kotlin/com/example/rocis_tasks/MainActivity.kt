package com.example.rocis_tasks

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.rocis_tasks/notifications"
    private val WIDGET_CHANNEL = "com.example.rocis_tasks/widget"
    private lateinit var notificationHelper: NotificationHelper
    private var widgetChannel: MethodChannel? = null

    companion object {
        private const val TAG = "MainActivity"
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
        Log.d(TAG, "Widget channel initialized")

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
        Log.d(TAG, "handleIntent called")
        Log.d(TAG, "  action: ${intent?.action}")
        Log.d(TAG, "  data: ${intent?.data}")
        Log.d(TAG, "  flags: ${intent?.flags}")
        Log.d(TAG, "  widgetChannel is null: ${widgetChannel == null}")
        
        if (intent?.action == NotificationHelper.ACTION_ADD_TASK) {
            Log.d(TAG, "Handling notification add_task action")
            channel.invokeMethod("onNotificationAction", "add_task")
            return
        }
        
        // Handle widget deep links
        val data = intent?.data
        if (data != null && data.scheme == "rocistasks") {
            Log.d(TAG, "Widget deep link detected: $data")
            Log.d(TAG, "  host: ${data.host}")
            Log.d(TAG, "  path: ${data.path}")
            // Send the URI to Flutter via the widget channel
            if (widgetChannel != null) {
                Log.d(TAG, "Invoking onWidgetClick with: ${data.toString()}")
                widgetChannel?.invokeMethod("onWidgetClick", data.toString())
            } else {
                Log.e(TAG, "widgetChannel is null, cannot send deep link to Flutter")
            }
        } else {
            Log.d(TAG, "No rocistasks deep link in intent")
        }
    }
}
