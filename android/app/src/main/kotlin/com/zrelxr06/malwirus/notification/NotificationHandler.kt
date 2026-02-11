package com.zrelxr06.malwirus.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import android.util.Log
import com.zrelxr06.malwirus.MainActivity
import java.util.concurrent.atomic.AtomicInteger
import com.zrelxr06.malwirus.preference.PreferenceHandler
import android.graphics.Color
import com.zrelxr06.malwirus.notification.action.NotificationActionHandler

/**
 * Handles all notifications for the Malwirus app
 */
class NotificationHandler(private val context: Context) {
    private val TAG = "NotificationHandler"
    private val preferenceHandler = PreferenceHandler(context)

    // Local log helpers gated by session-scoped debug flag
    private inline fun logD(msg: String) {
        if (MainActivity.DEBUG_LOGS_ENABLED) Log.d(TAG, msg)
    }

    private inline fun logE(msg: String) {
        if (MainActivity.DEBUG_LOGS_ENABLED) Log.e(TAG, msg)
    }

    companion object {
        private const val CHANNEL_ID = "Malwirus_Channel"
        private const val MONITORING_CHANNEL_ID = "Malwirus_Monitoring_Channel"

        // Fixed notification IDs to prevent conflicts
        private const val MONITORING_NOTIFICATION_ID = 1000 // Reserved for monitoring notification
        private const val REGULAR_NOTIFICATION_ID_START = 1001 // Start of regular notification IDs

        // Group keys for notification ordering
        private const val GROUP_KEY_ALERTS = "com.zrelxr06.malwirus.ALERTS"

        // Message types
        private const val MESSAGE_TYPE_SPAM = "SPAM" // High confidence spam
        private const val MESSAGE_TYPE_SUSPICIOUS = "SUSPICIOUS" // Low confidence spam
        private const val MESSAGE_TYPE_SAFE = "SAFE" // Not spam
    }

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private val notificationCounter = AtomicInteger(REGULAR_NOTIFICATION_ID_START)

    init {
        createNotificationChannels()
    }

    // Resolve the small icon to consistently use the app icon with fallbacks
    private fun getAppSmallIconRes(): Int {
        val res = context.resources
        val pkg = context.packageName
        return res.getIdentifier("ic_notification", "drawable", pkg)
            .takeIf { it != 0 }
            ?: res.getIdentifier("notification_icon", "drawable", pkg)
                .takeIf { it != 0 }
            ?: res.getIdentifier("ic_launcher", "mipmap", pkg)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Create the main notification channel
            val name = "Malwirus Alerts"
            val descriptionText = "Security alerts from Malwirus"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }

            // Create the monitoring notification channel
            val monitoringName = "Malwirus Monitoring"
            val monitoringDescriptionText = "Ongoing security monitoring by Malwirus"
            val monitoringImportance = NotificationManager.IMPORTANCE_LOW
            val monitoringChannel = NotificationChannel(
                MONITORING_CHANNEL_ID,
                monitoringName,
                monitoringImportance
            ).apply {
                description = monitoringDescriptionText
            }

            // Register the channels with the system
            notificationManager.createNotificationChannel(channel)
            notificationManager.createNotificationChannel(monitoringChannel)
        }
    }

    // Check if the notification is already active
    fun isNotificationActive(notificationId: Int): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            for (statusBarNotification in notificationManager.activeNotifications) {
                if (statusBarNotification.id == notificationId) {
                    return true
                }
            }
        }
        return false
    }

    /**
     * Specifically check if the monitoring notification is active.
     * Used by Flutter side to sync UI state with actual notification state.
     *
     * @return true if the monitoring notification is currently displayed
     */
    fun isMonitoringNotificationActive(): Boolean {
        return isNotificationActive(MONITORING_NOTIFICATION_ID)
    }

    /**
     * Shows a spam notification with proper handling of URL information based on user settings
     *
     * @param messageType The type of message (SPAM or SUSPICIOUS)
     * @param confidence Spam confidence percentage (0-100)
     * @param sender The phone number that sent the message
     * @param url Optional URL found in message (null if none or if scanning disabled)
     * @param threatType Optional threat type description (null if none or if scanning disabled)
     * @param notificationId Unique ID for this notification
     */
    fun showSpamNotification(
        messageType: String,
        confidence: Int,
        sender: String,
        url: String? = null,
        threatType: String? = null,
        notificationId: Int
    ) {
        try {
            // Check both preference stores to ensure proper sync between Dart and Kotlin
            val appPrefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
            val smsPrefs = context.getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)

            // If either preference store has link scanning disabled, respect that setting
            val isLinkScanningEnabled = appPrefs.getBoolean("link_scanning_enabled", true) &&
                    smsPrefs.getBoolean("link_scanning_enabled", true)

            // Determine message type display text
            val messageTypeText = when (messageType) {
                MESSAGE_TYPE_SPAM -> "Spam"
                MESSAGE_TYPE_SUSPICIOUS -> "Suspicious"
                else -> "Message"
            }

            // Create appropriate title based on message type and link scanning setting
            val title = if (isLinkScanningEnabled && url != null) {
                // Link scanning enabled and URL found
                "$messageTypeText and URL Alert!"
            } else {
                // Link scanning disabled or no URL found
                "$messageTypeText Message Alert!"
            }

            // Create message content based on scan settings
            val messageContent = StringBuilder()
            messageContent.append("From: $sender - $messageTypeText message with accuracy of $confidence%.")

            // Only add URL information if link scanning is enabled and URL is provided
            if (isLinkScanningEnabled && url != null) {
                messageContent.append("\n\nURL detected: $url")
                if (threatType != null) {
                    // Determine the source of analysis based on the threat type
                    val analysisSource = when {
                        threatType.contains("SafeBrowsing") -> "SafeBrowsing"  // Already contains source
                        threatType.contains("Phishing") -> "SafeBrowsing"  // Phishing is from SafeBrowsing API
                        threatType.contains("Malware") -> "SafeBrowsing"  // Malware is from SafeBrowsing API
                        threatType.contains("Unwanted") -> "SafeBrowsing"  // Social Engineering is from SafeBrowsing API
                        threatType.contains("Social Engineering") -> "SafeBrowsing"  // Social Engineering is from SafeBrowsing API
                        threatType.equals(
                            "No threats detected",
                            ignoreCase = true
                        ) -> "SafeBrowsing"  // Default for URLs checked by SafeBrowsing
                        threatType.equals(
                            "Safe",
                            ignoreCase = true
                        ) -> "SafeBrowsing"  // Default for URLs checked by SafeBrowsing
                        else -> "Local Analysis"  // Default to local analysis for everything else
                    }

                    val linkStatusText = if (threatType != null && threatType.isNotEmpty()) {
                        if (threatType.contains("(SafeBrowsing)") || threatType.contains("(Local Analysis)")) {
                            "Link Status: $threatType"
                        } else {
                            "Link Status: $threatType ($analysisSource)"
                        }
                    } else {
                        "Link Status: No threats detected ($analysisSource)"
                    }

                    messageContent.append("\n$linkStatusText")
                }
            }

            logD("Showing notification: $title")

            // Create intent for the main app activity
            val intent =
                Intent(context, Class.forName("com.zrelxr06.malwirus.MainActivity")).apply {
                    action = "SHOW_SMS_SECURITY"
                    putExtra("sender_number", sender)
                    putExtra("notification_id", notificationId)
                }

            val pendingIntent = PendingIntent.getActivity(
                context,
                notificationId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Create intent for whitelist action
            val whitelistIntent = Intent(context, NotificationActionHandler::class.java).apply {
                action = NotificationActionHandler.ACTION_WHITELIST_NUMBER
                putExtra(NotificationActionHandler.EXTRA_PHONE_NUMBER, sender)
                putExtra(NotificationActionHandler.EXTRA_NOTIFICATION_ID, notificationId)
            }

            val whitelistPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId * 100 + 1, // Request code must be unique
                whitelistIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Create intent for ignore action
            val ignoreIntent = Intent(context, NotificationActionHandler::class.java).apply {
                action = NotificationActionHandler.ACTION_IGNORE_MESSAGE
                putExtra(NotificationActionHandler.EXTRA_PHONE_NUMBER, sender)
                putExtra(NotificationActionHandler.EXTRA_NOTIFICATION_ID, notificationId)
            }

            val ignorePendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId * 100 + 2, // Request code must be unique
                ignoreIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // Ensure unique ID
            val uniqueId = if (notificationId <= MONITORING_NOTIFICATION_ID) {
                notificationCounter.incrementAndGet()
            } else {
                notificationId
            }

            // Build modern, clean notification following UI guidelines
            val notificationBuilder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(getAppSmallIconRes())
                .setContentTitle(title)
                .setContentText(messageContent.toString())
                .setStyle(NotificationCompat.BigTextStyle().bigText(messageContent.toString()))
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setGroup(GROUP_KEY_ALERTS)
                .setColor(Color.parseColor("#34C759")) // Use brand color

                // Add action buttons
                .addAction(
                    android.R.drawable.ic_menu_add,
                    "Whitelist",
                    whitelistPendingIntent
                )
                .addAction(
                    android.R.drawable.ic_menu_close_clear_cancel,
                    "Ignore",
                    ignorePendingIntent
                )

            // Show notification
            notificationManager.notify(uniqueId, notificationBuilder.build())
            logD("Notification shown with ID: $uniqueId, Link scanning enabled: $isLinkScanningEnabled")
        } catch (e: Exception) {
            logE("Error showing notification: ${e.message}")
        }
    }

    fun showQuickNotification(title: String, message: String, notificationId: Int) {
        try {
            // Ensure we use a unique ID that won't conflict with monitoring notification
            val uniqueId = if (notificationId <= MONITORING_NOTIFICATION_ID) {
                notificationCounter.incrementAndGet()
            } else {
                notificationId
            }

            // Build modern, clean notification following UI guidelines with no shadows/borders/elevation
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(getAppSmallIconRes())
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setGroup(GROUP_KEY_ALERTS) // Group with other alert notifications
                .setAutoCancel(true)
                .setColor(Color.parseColor("#34C759")) // Use brand color for consistency
                .build()

            notificationManager.notify(uniqueId, notification)
            logD("Quick notification shown with ID: $uniqueId")
        } catch (e: Exception) {
            logE("Error showing quick notification: ${e.message}")
        }
    }

    /**
     * Show a persistent monitoring notification (toggleable from settings)
     * Follows UI guidelines: transparent, no elevation, no border/shadow, proper color for day/night
     */
    fun showMonitoringNotification() {
        try {
            val notification = NotificationCompat.Builder(context, MONITORING_CHANNEL_ID)
                .setSmallIcon(getAppSmallIconRes())
                .setContentTitle("Malwirus Monitoring Enabled")
                .setContentText("Your device is being actively monitored for threats.")
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setColor(Color.parseColor("#34C759")) // Use brand color for consistency
                .setStyle(
                    NotificationCompat.BigTextStyle()
                        .bigText("Your device is being actively monitored for threats.")
                )
                .build()
            notificationManager.notify(MONITORING_NOTIFICATION_ID, notification)
            logD("Persistent monitoring notification shown.")
        } catch (e: Exception) {
            logE("Error showing monitoring notification: ${e.message}")
        }
    }

    /**
     * Cancel the persistent monitoring notification
     */
    fun cancelMonitoringNotification() {
        try {
            notificationManager.cancel(MONITORING_NOTIFICATION_ID)
            logD("Persistent monitoring notification cancelled.")
        } catch (e: Exception) {
            logE("Error cancelling monitoring notification: ${e.message}")
        }
    }
}
