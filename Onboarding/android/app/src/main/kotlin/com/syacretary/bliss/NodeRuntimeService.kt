package com.syacretary.bliss

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import java.io.File

internal class NodeRuntimeService : Service() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action ?: ACTION_START) {
            ACTION_STOP -> {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf(startId)
                NodeRuntimeState.markStopped()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                NodeRuntimeState.ensureToken()
                startForegroundCompat()
                if (NodeRuntimeState.markStarted()) {
                    Thread({ startNodeRuntime() }, "Bliss-Node-24").apply {
                        isDaemon = false
                        start()
                    }
                }
            }
        }
        return START_STICKY
    }

    private fun startNodeRuntime() {
        try {
            val project = File(filesDir, "bliss-node-project")
            copyAssetTree("nodejs", project)
            val result = NodeRuntimeBridge().startNode(
                NodeRuntimeState.arguments(this),
                NodeRuntimeState.sessionKey(this),
            )
            if (result != 0) NodeRuntimeState.markFailed() else NodeRuntimeState.markExited()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } catch (_: Throwable) {
            NodeRuntimeState.markFailed()
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    private fun copyAssetTree(assetPath: String, destination: File) {
        val children = assets.list(assetPath).orEmpty()
        if (children.isEmpty()) {
            destination.parentFile?.mkdirs()
            assets.open(assetPath).use { input ->
                destination.outputStream().use { output -> input.copyTo(output) }
            }
            return
        }
        if (!destination.exists()) destination.mkdirs()
        for (child in children) copyAssetTree("$assetPath/$child", File(destination, child))
    }

    private fun startForegroundCompat() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Bliss bot", NotificationManager.IMPORTANCE_LOW),
            )
        }
    }

    private fun buildNotification(): Notification {
        val openApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(this)
        }
        return builder.setSmallIcon(android.R.drawable.stat_notify_sync)
            .setContentTitle("Bliss sedang aktif")
            .setContentText("Bot WhatsApp berjalan di perangkat ini")
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val ACTION_START = "com.syacretary.bliss.NODE_START"
        const val ACTION_STOP = "com.syacretary.bliss.NODE_STOP"
        const val EXTRA_TOKEN = "runtime_token"
        private const val CHANNEL_ID = "bliss_bot_runtime"
        private const val NOTIFICATION_ID = 7401
    }
}
