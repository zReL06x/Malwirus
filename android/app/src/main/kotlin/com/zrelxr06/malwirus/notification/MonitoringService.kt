package com.zrelxr06.malwirus.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import com.zrelxr06.malwirus.MainActivity
import com.zrelxr06.malwirus.web_security.model.Counters
import com.zrelxr06.malwirus.web_security.service.WebSecurityVpnService

/**
 * Foreground service that shows a persistent monitoring notification with live counters.
 * - SMS Security status and counters (messages scanned, suspicious links)
 * - VPN status and DNS counters (queries, blocked, bytes in/out)
 */
class MonitoringService : Service() {
    companion object {
        private const val CHANNEL_ID = "Malwirus_Monitoring_Channel"
        private const val NOTIFICATION_ID = 1000 // Keep in sync with NotificationHandler
        const val ACTION_STOP = "com.zrelxr06.malwirus.monitoring.STOP"
        private const val UPDATE_INTERVAL_MS = 5000L
    }

    private val handler = Handler(Looper.getMainLooper())
    private val updateTask = object : Runnable {
        override fun run() {
            try {
                val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.notify(NOTIFICATION_ID, buildNotification())
            } finally {
                handler.postDelayed(this, UPDATE_INTERVAL_MS)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        ensureChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopForeground(true)
            stopSelf()
            return START_NOT_STICKY
        }
        startForeground(NOTIFICATION_ID, buildNotification())
        handler.removeCallbacks(updateTask)
        handler.post(updateTask)
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacks(updateTask)
        try {
            stopForeground(true)
        } catch (_: Exception) {
        }
    }

    /**
     * Some OEMs (and user action of swiping the task away) may remove the task and stop
     * the service. Because this service represents a user-enabled persistent monitoring
     * notification, we immediately schedule a restart to keep it alive unless the user
     * explicitly toggled it off from Settings.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        try {
            val restartIntent = Intent(applicationContext, MonitoringService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                applicationContext.startForegroundService(restartIntent)
            } else {
                @Suppress("DEPRECATION")
                applicationContext.startService(restartIntent)
            }
        } catch (_: Exception) {
        }
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Malwirus Monitoring",
                NotificationManager.IMPORTANCE_LOW
            )
            ch.description = "Shows live SMS and VPN monitoring status"
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val smsPrefs = getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
        val smsEnabled = smsPrefs.getBoolean("sms_scanning_enabled", false)

        val stats = getSharedPreferences("sms_security_stats", Context.MODE_PRIVATE)
        val msgs = stats.getInt("messages_scanned", 0)
        val links = stats.getInt("suspicious_links_found", 0)

        val webPrefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
        val vpnActive = webPrefs.getBoolean("vpn_active", false)

        // Live VPN counters
        val dnsQ = Counters.dnsQueries.value
        val dnsB = Counters.dnsBlocked.value
        val bIn = Counters.bytesIn.value
        val bOut = Counters.bytesOut.value

        val title = "Malwirus Security • Status"
        val lines = mutableListOf<String>()
        if (smsEnabled) {
            lines.add("SMS Scanned: $msgs • Suspicious: $links")
        }
        if (vpnActive) {
            lines.add("DNS: $dnsQ queries • $dnsB blocked")
            lines.add("Traffic: ${readableBytes(bIn)} in • ${readableBytes(bOut)} out")
        }
        if (!smsEnabled && !vpnActive) {
            lines.add("No security feature is enabled.")
        }

        val collapsedContent = when {
            smsEnabled && vpnActive -> "Live monitoring: SMS and Web active"
            vpnActive -> "Traffic: ${readableBytes(bIn)} in • ${readableBytes(bOut)} out"
            smsEnabled -> "SMS Scanned: $msgs • Suspicious: $links"
            else -> "No security feature is enabled."
        }

        val pi = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
        )


        // Action: Stop VPN (only shown when VPN is active)
        val stopVpnPi: PendingIntent? = if (vpnActive) {
            val stopIntent = Intent(this, WebSecurityVpnService::class.java).apply {
                action = WebSecurityVpnService.ACTION_STOP
            }
            PendingIntent.getService(
                this,
                3,
                stopIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)
            )
        } else null

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(
                resources.getIdentifier("ic_notification", "drawable", packageName)
                    .takeIf { it != 0 }
                    ?: resources.getIdentifier("notification_icon", "drawable", packageName)
                        .takeIf { it != 0 }
                    ?: resources.getIdentifier("ic_launcher", "mipmap", packageName)
            )
            .setContentTitle(title)
            .setContentText(collapsedContent)
            .setContentIntent(pi)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSubText("Live status")
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        if (stopVpnPi != null) {
            builder.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop VPN", stopVpnPi)
        }

        val style = NotificationCompat.InboxStyle()
        for (l in lines) style.addLine(l)
        builder.setStyle(style)

        return builder.build()
    }

    private fun readableBytes(v: Long): String {
        if (v < 1024) return "$v B"
        val kb = v / 1024.0
        if (kb < 1024) return String.format("%.1f KB", kb)
        val mb = kb / 1024.0
        if (mb < 1024) return String.format("%.1f MB", mb)
        val gb = mb / 1024.0
        return String.format("%.1f GB", gb)
    }
}
