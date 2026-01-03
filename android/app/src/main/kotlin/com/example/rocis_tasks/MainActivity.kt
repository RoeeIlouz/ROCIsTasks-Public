package com.example.rocis_tasks

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.rocis_tasks/notifications"
    private lateinit var notificationHelper: NotificationHelper


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

        // Handle initial intent
        handleIntent(intent, channel)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        val channel = MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL)
        handleIntent(intent, channel)
    }

    private fun handleIntent(intent: android.content.Intent?, channel: MethodChannel) {
        if (intent?.action == NotificationHelper.ACTION_ADD_TASK) {
            channel.invokeMethod("onNotificationAction", "add_task")
        }
    }
}
