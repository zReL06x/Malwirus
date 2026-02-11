package com.zrelxr06.malwirus.notification.action

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.gson.Gson
import com.zrelxr06.malwirus.notification.NotificationHandler
import com.zrelxr06.malwirus.sms_security.WhitelistedNumber

/**
 * BroadcastReceiver for handling notification action button clicks
 */
class NotificationActionHandler : BroadcastReceiver() {
    private val TAG = "NotificationAction"

    companion object {
        const val ACTION_WHITELIST_NUMBER = "com.zrelxr06.malwirus.ACTION_WHITELIST_NUMBER"
        const val ACTION_IGNORE_MESSAGE = "com.zrelxr06.malwirus.ACTION_IGNORE_MESSAGE"
        const val EXTRA_PHONE_NUMBER = "phone_number"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val phoneNumber = intent.getStringExtra(EXTRA_PHONE_NUMBER) ?: return
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)

        Log.d(TAG, "Received action: ${intent.action} for number: $phoneNumber")

        when (intent.action) {
            ACTION_WHITELIST_NUMBER -> {
                addToWhitelist(context, phoneNumber)

                // Show confirmation notification
                val notificationHandler = NotificationHandler(context)
                notificationHandler.showQuickNotification(
                    "Number Whitelisted",
                    "Messages from $phoneNumber will no longer be marked as spam",
                    notificationId + 1
                )

                // Cancel the original notification
                val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                notificationManager.cancel(notificationId)
            }

            ACTION_IGNORE_MESSAGE -> {
                // Just cancel the notification
                val notificationManager =
                    context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                notificationManager.cancel(notificationId)
            }
        }
    }

    private fun addToWhitelist(context: Context, phoneNumber: String) {
        try {
            val prefs = context.getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
            val gson = Gson()
            val current = prefs.getString("sms_whitelist", "[]")
            val arr = try { gson.fromJson(current, Array<WhitelistedNumber>::class.java) } catch (e: Exception) { null }
            val list = arr?.toMutableList() ?: mutableListOf()
            val target = normalizeToLocalFormat(phoneNumber)
            if (!list.any { normalizeToLocalFormat(it.number) == target }) {
                list.add(WhitelistedNumber(target))
                prefs.edit().putString("sms_whitelist", gson.toJson(list)).apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add to whitelist: ${e.message}")
        }
    }

    // Local normalization to avoid instantiating SmsProcessor (prevents SafeBrowsing init)
    private fun normalizeToLocalFormat(number: String): String {
        val cleaned = number.replace(Regex("[^0-9+]"), "")
        return when {
            cleaned.startsWith("+63") && cleaned.length >= 13 -> "0" + cleaned.substring(3)
            cleaned.startsWith("63") && cleaned.length >= 12 -> "0" + cleaned.substring(2)
            else -> cleaned
        }
    }
}
