package com.zrelxr06.malwirus

import android.Manifest
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.zrelxr06.malwirus.sms_security.SmsProcessor
import com.zrelxr06.malwirus.sms_security.SmsReceiver
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.zrelxr06.malwirus.notification.NotificationHandler

class MainActivity : FlutterActivity() {
    private fun openAppInfo(packageName: String) {
        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
        intent.data = android.net.Uri.parse("package:$packageName")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private val CHANNEL = "com.zrelxr06.malwirus/sms_security"
    private val NOTIFICATION_CHANNEL = "com.zrelxr06.malwirus/notification"
    private val TAG = "MainActivity"
    private val SMS_PERMISSION_REQUEST_CODE = 100
    private var smsReceiver: SmsReceiver? = null
    private var smsProcessor: SmsProcessor? = null
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize SmsProcessor
        smsProcessor = SmsProcessor(applicationContext)
        
        // Notification handler channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            val notificationHandler = NotificationHandler(applicationContext)
            when (call.method) {
                "enableMonitoringNotification" -> {
                    notificationHandler.showMonitoringNotification()
                    result.success(true)
                }
                "disableMonitoringNotification" -> {
                    notificationHandler.cancelMonitoringNotification()
                    result.success(true)
                }
                "isMonitoringNotificationActive" -> {
                    val isActive = notificationHandler.isMonitoringNotificationActive()
                    result.success(isActive)
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppInfo" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        openAppInfo(packageName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "checkAppInstalled" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        result.success(isAppInstalled(packageName))
                    } else {
                        result.error("INVALID_ARGUMENT", "Package name is required", null)
                    }
                }
                "startSmsScanning" -> {
                    val success = startSmsScanning()
                    result.success(success)
                }
                "stopSmsScanning" -> {
                    stopSmsScanning()
                    result.success(true)
                }
                "getSmsStats" -> {
                    val stats = getSmsStats()
                    result.success(stats)
                }
                "getWhitelistedNumbers" -> {
                    val numbers = getWhitelistedNumbers()
                    result.success(numbers)
                }
                "addToWhitelist" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        addToWhitelist(number)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Number is required", null)
                    }
                }
                "removeFromWhitelist" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        removeFromWhitelist(number)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "Number is required", null)
                    }
                }
                "checkSmsPermission" -> {
                    val hasPermission = checkSmsPermission()
                    result.success(hasPermission)
                }
                "setLinkScanningEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    setLinkScanningEnabled(enabled)
                    result.success(true)
                }
                "requestSmsPermission" -> {
                    requestSmsPermission()
                    result.success(true)
                }
                "getSmsHistory" -> {
                    val history = getSmsHistory()
                    result.success(history)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun startSmsScanning(): Boolean {
        if (!checkSmsPermission()) {
            Log.e(TAG, "SMS permission not granted")
            return false
        }
        
        if (smsReceiver == null) {
            smsReceiver = SmsReceiver()
            val intentFilter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
            registerReceiver(smsReceiver, intentFilter)
            Log.d(TAG, "SMS receiver registered")
        }
        
        return true
    }
    
    private fun stopSmsScanning() {
        if (smsReceiver != null) {
            try {
                unregisterReceiver(smsReceiver)
                smsReceiver = null
                Log.d(TAG, "SMS receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering SMS receiver: ${e.message}")
            }
        }
    }
    
    private fun getSmsStats(): Map<String, Any> {
        val stats = HashMap<String, Any>()
        
        // Get stats from shared preferences
        val prefs = getSharedPreferences("sms_security_stats", MODE_PRIVATE)
        stats["messagesScanned"] = prefs.getInt("messages_scanned", 0)
        stats["suspiciousLinksFound"] = prefs.getInt("suspicious_links_found", 0)
        stats["isEnabled"] = smsReceiver != null
        
        return stats
    }
    
    private fun getWhitelistedNumbers(): List<Map<String, Any>> {
        return smsProcessor?.getWhitelistedNumbers()?.map { number ->
            mapOf(
                "number" to number.number,
                "dateAdded" to number.dateAdded
            )
        } ?: emptyList()
    }
    
    private fun addToWhitelist(number: String) {
        smsProcessor?.addToWhitelist(number)
    }
    
    private fun removeFromWhitelist(number: String) {
        smsProcessor?.removeFromWhitelist(number)
    }
    
    private fun checkSmsPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.RECEIVE_SMS
        ) == PackageManager.PERMISSION_GRANTED
    }
    
    private fun requestSmsPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.RECEIVE_SMS),
            SMS_PERMISSION_REQUEST_CODE
        )
    }
    
    private fun getSmsHistory(): List<Map<String, Any>> {
        val historyManager = com.zrelxr06.malwirus.data.HistoryManager(applicationContext)
        return historyManager.getHistory().map { entry ->
            // Just return the original map without any changes to ensure compatibility
            mapOf(
                "senderNumber" to entry.senderNumber,
                "timestamp" to entry.timestamp,
                "isSpam" to entry.isSpam,
                "confidence" to entry.confidence,
                "containsUrl" to entry.containsUrl,
                "url" to (entry.url ?: ""),
                "urlScanResult" to entry.urlScanResult.toString(),
                "threatInfo" to entry.threatInfo
            )
        }
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d(TAG, "SMS permission granted")
                startSmsScanning()
            } else {
                Log.e(TAG, "SMS permission denied")
            }
        }
    }
    
    /**
     * Sets the link scanning enabled state and synchronizes it across all preference stores
     * @param enabled Whether link scanning should be enabled
     */
    private fun setLinkScanningEnabled(enabled: Boolean) {
        try {
            // Update all preference stores to ensure consistency
            val appPrefs = applicationContext.getSharedPreferences("app_preferences", MODE_PRIVATE)
            val smsPrefs = applicationContext.getSharedPreferences("sms_security_prefs", MODE_PRIVATE)
            
            // Set the same value in all stores
            appPrefs.edit().putBoolean("link_scanning_enabled", enabled).apply()
            smsPrefs.edit().putBoolean("link_scanning_enabled", enabled).apply()
            
            // Also update preference manager directly if smsProcessor is available
            smsProcessor?.getPreferenceManager()?.setBoolean("link_scanning_enabled", enabled)
            
            Log.d(TAG, "Link scanning ${if (enabled) "enabled" else "disabled"} in all preference stores")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting link scanning state: ${e.message}")
        }
    }
}
