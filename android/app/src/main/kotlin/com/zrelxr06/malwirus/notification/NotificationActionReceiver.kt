package com.zrelxr06.malwirus.notification

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.zrelxr06.malwirus.sms_security.SmsProcessor

/**
 * BroadcastReceiver for handling notification action button clicks
 */
class NotificationActionReceiver : BroadcastReceiver() {
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
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                notificationManager.cancel(notificationId)
            }
            ACTION_IGNORE_MESSAGE -> {
                // Just cancel the notification
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
                notificationManager.cancel(notificationId)
            }
        }
    }
    
    private fun addToWhitelist(context: Context, phoneNumber: String) {
        val smsProcessor = SmsProcessor(context)
        smsProcessor.addToWhitelist(phoneNumber)
    }
}
