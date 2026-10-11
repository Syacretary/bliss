package com.syacretary.bliss

import android.content.Context
import android.content.Intent
import java.security.SecureRandom
import android.util.Base64
import java.util.concurrent.atomic.AtomicBoolean

internal object NodeRuntimeState {
    const val PORT = 49273
    const val CHANNEL = "bliss/bot_runtime"

    @Volatile private var token: String? = null
    @Volatile var state: String = "idle"
        private set
    private val started = AtomicBoolean(false)

    @Synchronized
    fun launch(context: Context): Map<String, Any> {
        if (state == "failed" || state == "exited") {
            // A prior Node event loop may have returned while the Android app stayed alive.
            // Let an explicit user/API health retry start a fresh runtime in this process.
            started.set(false)
            state = "idle"
        }
        val secret = ensureToken()
        val intent = Intent(context, NodeRuntimeService::class.java)
            .setAction(NodeRuntimeService.ACTION_START)
            .putExtra(NodeRuntimeService.EXTRA_TOKEN, secret)
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
        if (state == "idle") state = "starting"
        return mapOf("port" to PORT, "token" to secret)
    }

    @Synchronized
    fun ensureToken(): String {
        return token ?: run {
            val bytes = ByteArray(32)
            SecureRandom().nextBytes(bytes)
            Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
                .also { token = it }
        }
    }

    fun stopForeground(context: Context) {
        context.stopService(Intent(context, NodeRuntimeService::class.java))
    }

    fun markStarted(): Boolean = started.compareAndSet(false, true)
    fun markReady() { state = "ready" }
    fun markFailed() { state = "failed" }
    fun markExited() { state = "exited" }
    fun markStopped() { if (state == "ready" || state == "starting") state = "idle" }

    fun arguments(context: Context): Array<String> {
        val project = java.io.File(context.filesDir, "bliss-node-project")
        val data = context.noBackupFilesDir
        val cache = context.cacheDir
        val secret = ensureToken()
        return arrayOf(
            "node",
            java.io.File(project, "dist/android-host.js").absolutePath,
            project.absolutePath,
            data.absolutePath,
            cache.absolutePath,
            PORT.toString(),
            secret,
        )
    }

    fun sessionKey(context: Context): String = AndroidSessionKeyStore(context).getOrCreateBase64Key()
}
