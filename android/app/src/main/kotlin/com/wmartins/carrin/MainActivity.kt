package com.wmartins.carrin

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            startService(Intent(this, NotificationDismissService::class.java))
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            notificationManager?.cancelAll()
        } catch (_: Exception) {}
        super.onDestroy()
    }
}
