package com.example.rocis_tasks

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
import androidx.core.app.NotificationCompat

class NotificationHelper(private val context: Context) {
    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val channelId = "rocis_tasks_persistent_v5"
    private val notificationId = 888
    
    companion object {
        const val ACTION_ADD_TASK = "com.example.rocis_tasks.ACTION_ADD_TASK"
    }

    init {
        createNotificationChannel()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Task Counter"
            val descriptionText = "Persistent notification for uncompleted tasks"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, name, importance).apply {
                description = descriptionText
                setShowBadge(true)
                enableLights(true)
                lightColor = Color.BLUE
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showTaskCountNotification(count: Int, titles: List<String>) {
        android.util.Log.d("NotificationHelper", "showTaskCountNotification called with count: $count")
        try {
            val bitmap = createCountBitmap(count)
            val body = if (titles.isEmpty()) "$count uncompleted tasks" else titles.joinToString("\n")
            val icon = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Icon.createWithBitmap(bitmap)
            } else {
                null // Fallback if needed, but we targeting M+ mostly
            }

            val addIntent = android.content.Intent(context, MainActivity::class.java).apply {
                action = ACTION_ADD_TASK
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val addPendingIntent = android.app.PendingIntent.getActivity(
                context, 
                0, 
                addIntent, 
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT else android.app.PendingIntent.FLAG_UPDATE_CURRENT
            )

            val mainIntent = android.content.Intent(context, MainActivity::class.java).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            val mainPendingIntent = android.app.PendingIntent.getActivity(
                context, 
                1, 
                mainIntent, 
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT else android.app.PendingIntent.FLAG_UPDATE_CURRENT
            )

            val builder = NotificationCompat.Builder(context, channelId)
                .setContentTitle("Tasks Remaining")
                .setContentText("$count uncompleted tasks")
                .setSmallIcon(R.mipmap.launcher_icon) // Fallback small icon
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(false)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setContentIntent(mainPendingIntent)
                .addAction(android.R.drawable.ic_input_add, "Add Task", addPendingIntent)

            if (icon != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Use native Notification.Builder for API 23+ to support Icon object
                val nativeBuilder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    android.app.Notification.Builder(context, channelId)
                } else {
                    @Suppress("DEPRECATION")
                    android.app.Notification.Builder(context)
                }
                
                nativeBuilder
                    .setContentTitle("Tasks Remaining")
                    .setContentText("$count uncompleted tasks")
                    .setSmallIcon(icon)
                    .setOngoing(true)
                    .setAutoCancel(false)
                    .setStyle(android.app.Notification.BigTextStyle().bigText(body))
                    .setContentIntent(mainPendingIntent)
                    .addAction(
                        android.app.Notification.Action.Builder(
                            icon, 
                            "Add Task", 
                            addPendingIntent
                        ).build()
                    )
            
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    nativeBuilder.setPriority(android.app.Notification.PRIORITY_HIGH)
                } else {
                    @Suppress("DEPRECATION")
                    nativeBuilder.setPriority(android.app.Notification.PRIORITY_HIGH)
                }

                notificationManager.notify(notificationId, nativeBuilder.build())
            } else {
                notificationManager.notify(notificationId, builder.build())
            }
        } catch (e: Exception) {
            android.util.Log.e("NotificationHelper", "Error showing notification: ${e.message}", e)
        }
    }

    private fun createCountBitmap(count: Int): Bitmap {
        val size = 64 // Standard small icon size is small
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        val paint = Paint().apply {
            color = Color.WHITE
            isAntiAlias = true
            textAlign = Paint.Align.CENTER
            textSize = 42f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }

        // Drawing only the number as per user request

        val text = if (count > 99) "99+" else count.toString()
        val xPos = canvas.width / 2f
        val yPos = (canvas.height / 2f - (paint.descent() + paint.ascent()) / 2f)
        
        canvas.drawText(text, xPos, yPos, paint)
        
        return bitmap
    }
}
