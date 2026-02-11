package com.zrelxr06.malwirus.sms_security.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.TelephonyManager
import android.util.Log
import com.google.gson.Gson
import com.zrelxr06.malwirus.notification.NotificationHandler
import com.zrelxr06.malwirus.preference.PreferenceHandler
import com.zrelxr06.malwirus.sms_security.SmsProcessor

/**
 * CallReceiver implements a soft-blocking behavior for incoming phone calls.
 * It reads a JSON blocklist from shared preferences and, if the incoming number
 * matches, it will notify the user (non-intrusive — no call rejection).
 *
 * Storage format mirrors SMS whitelist implementation patterns:
 * - Preferences file: uses centralized PreferenceHandler ("app_preferences") API
 * - Key: "call_blocklist"
 * - Value: JSON array of strings (phone numbers), e.g. ["09123456789", ...]
 *
 * Notes:
 * - Numbers are normalized similar to `SmsProcessor.formatPhoneNumber()` and then adapted
 *   to local 11-digit format if possible (e.g., +63XXXXXXXXXX -> 0XXXXXXXXXX) to match UI input.
 * - This receiver only shows a notification; it does not end/deny calls.
 */
class CallReceiver : BroadcastReceiver() {
    private val TAG = "CallReceiver"
    private val gson = Gson()

    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        try {
            Log.d(TAG, "onReceive invoked. action=${intent.action}")
            if (TelephonyManager.ACTION_PHONE_STATE_CHANGED != intent.action) {
                Log.d(TAG, "Ignoring non-PHONE_STATE action")
                return
            }

            val state = intent.getStringExtra(TelephonyManager.EXTRA_STATE)
            Log.d(TAG, "Phone state extra: $state")
            if (TelephonyManager.EXTRA_STATE_RINGING != state) {
                Log.d(TAG, "State is not RINGING; nothing to do")
                return
            }

            // WARNING: EXTRA_INCOMING_NUMBER may be empty on newer Android versions
            val rawIncoming = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER)
            if (rawIncoming.isNullOrBlank()) {
                Log.d(TAG, "Incoming number unavailable on this device/version")
                return
            }

            val normalized = normalizeToLocalFormat(context, rawIncoming)
            Log.d(TAG, "Incoming call detected from: $normalized (raw=$rawIncoming)")

            val inList = isInBlocklist(context, normalized)
            Log.d(TAG, "Blocklist match=$inList for incoming=$normalized")
            if (inList) {
                Log.d(TAG, "Number is blocklisted, showing soft-block notification")
                NotificationHandler(context).showQuickNotification(
                    title = "Blocked Call Detected",
                    message = "Incoming call from blocklisted number: $normalized",
                    notificationId = 7000
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error handling call state: ${e.message}", e)
        }
    }

    /**
     * Attempt to normalize phone numbers to match the 11-digit input convention used in UI
     * (e.g., "09123456789"). We start with SmsProcessor.formatPhoneNumber() for base cleanup
     * then convert common country code patterns.
     */
    private fun normalizeToLocalFormat(context: Context, number: String): String {
        val cleaned = try {
            SmsProcessor(context).formatPhoneNumber(number)
        } catch (_: Exception) {
            number.replace(Regex("[^0-9+]"), "")
        }

        // Convert +63XXXXXXXXXX -> 0XXXXXXXXXX (Philippines pattern) if applicable
        if (cleaned.startsWith("+63") && cleaned.length >= 13) {
            return "0" + cleaned.substring(3)
        }
        // Convert 63XXXXXXXXXX -> 0XXXXXXXXXX
        if (cleaned.startsWith("63") && cleaned.length >= 12) {
            return "0" + cleaned.substring(2)
        }
        return cleaned
    }

    private fun numbersEqual(context: Context, a: String, b: String): Boolean {
        val na = normalizeToLocalFormat(context, a)
        val nb = normalizeToLocalFormat(context, b)
        if (na == nb) return true
        val minLen = minOf(na.length, nb.length)
        val required = if (minLen >= 11) 11 else if (minLen >= 10) 10 else 9
        return na.takeLast(required) == nb.takeLast(required)
    }

    /**
     * Reads the JSON blocklist from preferences and checks membership.
     * Key: call_blocklist, Value: JSON array of strings
     */
    private fun isInBlocklist(context: Context, number: String): Boolean {
        return try {
            val pref = PreferenceHandler(context)
            val json = pref.getString("call_blocklist", "[]")
            val arr = gson.fromJson(json, Array<String>::class.java)
            val list: List<String> = arr?.toList() ?: emptyList()
            val match = list.any { numbersEqual(context, it, number) }
            try {
                Log.d(TAG, "Loaded blocklist size=${list.size}, entries=$list, incoming=$number, match=$match")
            } catch (_: Exception) {}
            match
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read/parse call blocklist: ${e.message}")
            false
        }
    }
}

