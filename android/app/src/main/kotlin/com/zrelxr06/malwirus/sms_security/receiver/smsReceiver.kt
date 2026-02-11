package com.zrelxr06.malwirus.sms_security.receiver

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import android.util.Log
import com.zrelxr06.malwirus.MainActivity
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import com.zrelxr06.malwirus.sms_security.SmsProcessor
import java.util.*

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        private const val CONFIDENCE_THRESHOLD_SUSPICIOUS = 50f
        private const val CONFIDENCE_THRESHOLD_SPAM = 80f

        // Set to store recently processed message IDs
        private val recentlyProcessedMessageIds =
            Collections.synchronizedSet(LinkedHashSet<String>())
        private const val MESSAGE_EXPIRY_TIME = 10000L // 10 seconds
    }

    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    // Local log helpers gated by session-scoped debug flag
    private inline fun logD(tag: String, msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.d(tag, msg) }
    private inline fun logE(tag: String, msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.e(tag, msg) }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            logD(TAG, "Received intent is not SMS_RECEIVED_ACTION")
            return
        }

        if (!hasSmsPermission(context)) {
            logE(TAG, "SMS permission not granted")
            return
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) {
            logD(TAG, "No messages found in intent")
            return
        }

        val fullMessage = StringBuilder()
        val senderNumber = messages[0].originatingAddress ?: "Unknown"

        // Combine all message parts
        messages.forEach { message ->
            fullMessage.append(message.messageBody)
        }

        val messageContent = fullMessage.toString()
        // Build a stable de-duplication key using sender + content hash only.
        // Do not include a timestamp here; we manage expiry via a delayed removal.
        val messageDedupKey = "${senderNumber}_${messageContent.hashCode()}"

        // Check if we've recently processed this message
        if (recentlyProcessedMessageIds.contains(messageDedupKey)) {
            Log.d(TAG, "Skipping duplicate SMS from $senderNumber - already processed (dedup)")
            return
        }

        // Add to recently processed messages
        recentlyProcessedMessageIds.add(messageDedupKey)

        // Schedule removal of the message ID after expiry time
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            recentlyProcessedMessageIds.remove(messageDedupKey)
            logD(TAG, "Removed message key from deduplication cache: $messageDedupKey")
        }, MESSAGE_EXPIRY_TIME)

        logD(TAG, "Processing message from: $senderNumber")

        context?.let { ctx ->
            // Process the message without incrementing the counter here
            // The counter will be incremented only once in the processMessage method
            processMessage(ctx, messageContent, senderNumber)
        }
    }

    private fun hasSmsPermission(context: Context?): Boolean {
        return ContextCompat.checkSelfPermission(
            context!!,
            Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun processMessage(context: Context, message: String, senderNumber: String) {
        try {
            val smsProcessor = SmsProcessor(context)

            // Check if SMS scanning is enabled in preferences
            val prefs = context.getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
            val isScanningEnabled = prefs.getBoolean("sms_scanning_enabled", true)
            val isLinkScanningEnabled = prefs.getBoolean("link_scanning_enabled", true)

            if (!isScanningEnabled) {
                logD(TAG, "SMS scanning is disabled")
                return
            }

            // Process the message using a coroutine since processMessage is a suspend function
            coroutineScope.launch {
                try {
                    smsProcessor.processMessage(senderNumber, message, isLinkScanningEnabled)
                    logD(TAG, "Message processing completed")
                } catch (e: Exception) {
                    logE(TAG, "Error in coroutine while processing message: ${e.message}")
                }
            }
        } catch (e: Exception) {
            logE(TAG, "Error processing message: ${e.message}")
        }
    }
}
