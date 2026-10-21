package com.wmartins.carrin

import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder

/**
 * Service that listens for task removal (when the user swipes the app away from recents).
 * Automatically cancels active shopping progress notifications while preserving update notifications.
 */
class NotificationDismissService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            // Cancela o monitor de compras (ID 0) e alertas de orçamento (ID 1)
            // Preserva notificações de novas versões ou APK pronto (IDs 2 e 3)
            notificationManager?.cancel(0)
            notificationManager?.cancel(1)
        } catch (_: Exception) {}
        stopSelf()
    }
}
