package com.zrelxr06.malwirus.sms_security

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.provider.Telephony
import android.util.Log
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.*

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "SmsReceiver"
        private const val CONFIDENCE_THRESHOLD_SUSPICIOUS = 50f
        private const val CONFIDENCE_THRESHOLD_SPAM = 80f
        
        // Set to store recently processed message IDs
        private val recentlyProcessedMessageIds = Collections.synchronizedSet(LinkedHashSet<String>())
        private const val MESSAGE_EXPIRY_TIME = 10000L // 10 seconds
    }

    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            Log.d(TAG, "Received intent is not SMS_RECEIVED_ACTION")
            return
        }

        if (!hasSmsPermission(context)) {
            Log.e(TAG, "SMS permission not granted")
            return
        }

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (messages.isNullOrEmpty()) {
            Log.d(TAG, "No messages found in intent")
            return
        }

        val fullMessage = StringBuilder()
        val senderNumber = messages[0].originatingAddress ?: "Unknown"

        // Combine all message parts
        messages.forEach { message ->
            fullMessage.append(message.messageBody)
        }
        
        val messageContent = fullMessage.toString()
        val messageId = "${senderNumber}_${messageContent.hashCode()}_${System.currentTimeMillis() / 1000}"
        
        // Check if we've recently processed this message
        if (recentlyProcessedMessageIds.contains(messageId)) {
            Log.d(TAG, "Skipping duplicate SMS from $senderNumber - already processed")
            return
        }
        
        // Add to recently processed messages
        recentlyProcessedMessageIds.add(messageId)
        
        // Schedule removal of the message ID after expiry time
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            recentlyProcessedMessageIds.remove(messageId)
            Log.d(TAG, "Removed message ID from deduplication cache: $messageId")
        }, MESSAGE_EXPIRY_TIME)

        Log.d(TAG, "Processing message from: $senderNumber")

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
                Log.d(TAG, "SMS scanning is disabled")
                return
            }
            
            // Process the message using a coroutine since processMessage is a suspend function
            coroutineScope.launch {
                try {
                    smsProcessor.processMessage(senderNumber, message, isLinkScanningEnabled)
                    Log.d(TAG, "Message processing completed")
                } catch (e: Exception) {
                    Log.e(TAG, "Error in coroutine while processing message: ${e.message}")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing message: ${e.message}")
        }
    }
}
