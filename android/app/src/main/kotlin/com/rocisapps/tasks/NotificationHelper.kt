package com.rocisapps.tasks

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

class NotificationHelper(private val context: Context) {
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val channelId = "rocis_tasks_persistent_v6"
    private val notificationId = 888

    companion object {
        private const val TAG = "NotificationHelper"
        const val ACTION_ADD_TASK = "com.rocisapps.tasks.ACTION_ADD_TASK"
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Clean up obsolete high-importance v5 channel if present
            try {
                notificationManager.deleteNotificationChannel("rocis_tasks_persistent_v5")
            } catch (_: Exception) {}

            val name = "Task Counter"
            val descriptionText = "Persistent notification for uncompleted tasks"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(channelId, name, importance).apply {
                description = descriptionText
                setShowBadge(true)
                enableLights(false)
                enableVibration(false)
                setSound(null, null)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showTaskCountNotification(
        count: Int,
        titles: List<String>,
        largeIconPath: String?,
        isDarkText: Boolean = false
    ): Boolean {
        // On Android 13+ (API 33), check runtime notification permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    context,
                    android.Manifest.permission.POST_NOTIFICATIONS
                ) != android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                Log.w(TAG, "POST_NOTIFICATIONS permission not granted, skipping notification")
                return false
            }
        }

        val body = if (titles.isEmpty()) "$count uncompleted tasks" else titles.joinToString("\n")

        val addIntent = android.content.Intent(context, MainActivity::class.java).apply {
            action = ACTION_ADD_TASK
            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val addPendingIntent = android.app.PendingIntent.getActivity(
            context,
            0,
            addIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                android.app.PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val mainIntent = android.content.Intent(context, MainActivity::class.java).apply {
            flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val mainPendingIntent = android.app.PendingIntent.getActivity(
            context,
            1,
            mainIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                android.app.PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        // Large icon (e.g. progressive circular chart)
        var largeBitmap: Bitmap? = null
        if (largeIconPath != null) {
            try {
                largeBitmap = android.graphics.BitmapFactory.decodeFile(largeIconPath)
            } catch (e: Exception) {
                Log.w(TAG, "Failed to decode largeIconPath: $largeIconPath", e)
            }
        }

        // Always create a dedicated small status bar bitmap icon with the count number
        val countBitmap = createCountBitmap(count, isDarkText)

        // Attempt primary path: Native Notification.Builder with dynamic count icon
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val countIcon = Icon.createWithBitmap(countBitmap)
                val nativeBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    android.app.Notification.Builder(context, channelId)
                } else {
                    @Suppress("DEPRECATION")
                    android.app.Notification.Builder(context)
                }

                nativeBuilder
                    .setContentTitle("Tasks Remaining")
                    .setContentText("$count uncompleted tasks")
                    .setSmallIcon(countIcon)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setStyle(android.app.Notification.BigTextStyle().bigText(body))
                    .setContentIntent(mainPendingIntent)
                    .addAction(
                        android.app.Notification.Action.Builder(
                            Icon.createWithResource(context, android.R.drawable.ic_input_add),
                            "Add Task",
                            addPendingIntent
                        ).build()
                    )

                if (largeBitmap != null) {
                    nativeBuilder.setLargeIcon(largeBitmap)
                }

                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    @Suppress("DEPRECATION")
                    nativeBuilder.setPriority(android.app.Notification.PRIORITY_LOW)
                }

                notificationManager.notify(notificationId, nativeBuilder.build())
                return true
            } catch (e: Exception) {
                Log.w(TAG, "Native Notification.Builder failed, falling back to NotificationCompat: ${e.message}", e)
            }
        }

        // Resilient fallback path: NotificationCompat with standard launcher icon
        try {
            val fallbackBuilder = NotificationCompat.Builder(context, channelId)
                .setContentTitle("Tasks Remaining")
                .setContentText("$count uncompleted tasks")
                .setSmallIcon(R.mipmap.launcher_icon)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setAutoCancel(false)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setContentIntent(mainPendingIntent)
                .addAction(android.R.drawable.ic_input_add, "Add Task", addPendingIntent)

            if (largeBitmap != null) {
                fallbackBuilder.setLargeIcon(largeBitmap)
            }

            notificationManager.notify(notificationId, fallbackBuilder.build())
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Fallback NotificationCompat also failed: ${e.message}", e)
            return false
        }
    }

    private fun createCountBitmap(count: Int, isDarkText: Boolean = false): Bitmap {
        val size = 64
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val text = if (count > 99) "99+" else count.toString()

        val paint = Paint().apply {
            color = if (isDarkText) Color.BLACK else Color.WHITE
            isAntiAlias = true
            textAlign = Paint.Align.CENTER
            textSize = when {
                count > 99 -> 26f
                count > 9 -> 34f
                else -> 42f
            }
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }

        val xPos = canvas.width / 2f
        val yPos = (canvas.height / 2f - (paint.descent() + paint.ascent()) / 2f)

        canvas.drawText(text, xPos, yPos, paint)

        return bitmap
    }
}
