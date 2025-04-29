package com.zrelxr06.malwirus.sms_security.google_safebrowsing

import android.content.Context
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlin.coroutines.resume
import com.zrelxr06.malwirus.notification.NotificationHandler
import com.zrelxr06.malwirus.data.SmsHistoryEntry
import com.zrelxr06.malwirus.data.HistoryManager
import com.zrelxr06.malwirus.data.UrlScanResult
import com.zrelxr06.malwirus.preference.PreferenceManager

/**
 * Service that handles scanning SMS messages for malicious URLs
 */
class SafeBrowsingService(private val context: Context) {
    private val TAG = "SafeBrowsingService"
    
    // Use the Google Safe Browsing API key
    private val apiKey = "AIzaSyAyla-n-8LXnsO3-aU6MPsK2q3CaY4Qbm0"
    private val safeBrowsingClient = SafeBrowsingClient(apiKey)
    private val preferenceManager = PreferenceManager(context)
    private val historyManager = HistoryManager(context)
    private val notificationHandler = NotificationHandler(context)
    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    
    init {
        Log.d(TAG, "SafeBrowsingService initialized with API key")
    }

    /**
     * Data class to hold URL scan results
     */
    data class ScanResult(
        val hasMaliciousUrls: Boolean = false,
        val scannedUrls: List<String> = emptyList(),
        val threatTypes: String = "",
        val error: String? = null
    )
    
    /**
     * Scans an SMS message for potentially malicious URLs using Google's SafeBrowsing API
     * This method only checks URLs against Google's API and doesn't perform local suspicious pattern checks
     * 
     * @param sender The phone number that sent the message
     * @param message The content of the SMS message
     * @param confidence The spam confidence value (0-100)
     * @return A ScanResult containing information about the scan
     */
    suspend fun scanMessage(sender: String, message: String, confidence: Float = 100f): ScanResult = suspendCancellableCoroutine { continuation ->
        Log.d(TAG, "scanMessage() called for message from $sender")
        
        // Check if Safe Browsing is enabled
        if (!preferenceManager.getBoolean("SMS_SAFEBROWSING", true)) {
            Log.d(TAG, "Safe Browsing is disabled, skipping scan")
            continuation.resume(ScanResult(hasMaliciousUrls = false, error = "Safe Browsing is disabled"))
            return@suspendCancellableCoroutine
        }

        Log.d(TAG, "Scanning message from $sender for URLs: '${message.take(50)}${if (message.length > 50) "..." else ""}'")
        val urls = safeBrowsingClient.extractUrlsFromMessage(message)
        
        if (urls.isEmpty()) {
            Log.d(TAG, "No URLs found in message from $sender")
            continuation.resume(ScanResult(hasMaliciousUrls = false, scannedUrls = emptyList()))
            return@suspendCancellableCoroutine
        }
        
        // Remove duplicate URLs before scanning
        val uniqueUrls = urls.toSet().toList()
        Log.d(TAG, "Found ${uniqueUrls.size} unique URLs in message from $sender")
        
        coroutineScope.launch {
            try {
                Log.d(TAG, "Starting asynchronous URL checks for message from $sender")
                
                // Flag to track if we found at least one dangerous URL
                var foundDangerousUrl = false
                var threatTypes = ""
                var maliciousUrl = ""
                
                // Check each URL against the Safe Browsing API
                for (url in uniqueUrls) {
                    Log.d(TAG, "Checking URL: $url against Safe Browsing API")
                    val result = safeBrowsingClient.checkUrl(url)
                    
                    // Update history regardless of result
                    updateHistoryWithScanResult(sender, url, result, confidence)
                    
                    if (!result.isSafe) {
                        // URL is unsafe, track it
                        Log.d(TAG, "URL $url is UNSAFE with ${result.threats.size} threats")
                        foundDangerousUrl = true
                        threatTypes = result.threats.map { it.type }.joinToString(", ")
                        maliciousUrl = url
                    } else {
                        // URL is safe
                        Log.d(TAG, "URL $url is SAFE")
                    }
                }
                
                // Only show one notification for all malicious URLs in the message
                if (foundDangerousUrl) {
                    // Check all preference stores to ensure proper sync
                    val appPrefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
                    val smsPrefs = context.getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
                    
                    // Link scanning is only enabled if both preference stores have it enabled
                    val isLinkScanningEnabled = preferenceManager.getBoolean("link_scanning_enabled", true) &&
                                               appPrefs.getBoolean("link_scanning_enabled", true) &&
                                               smsPrefs.getBoolean("link_scanning_enabled", true)
                    
                    // Set appropriate notification title based on settings
                    val title = if (isLinkScanningEnabled) "Spam and URL Alert!" else "Suspicious Message Alert!"
                    
                    // Increment suspicious links counter for malicious URLs found
                    val statsPrefs = context.getSharedPreferences("sms_security_stats", Context.MODE_PRIVATE)
                    val currentCount = statsPrefs.getInt("suspicious_links_found", 0)
                    statsPrefs.edit().putInt("suspicious_links_found", currentCount + 1).apply()
                    Log.d(TAG, "Incremented suspicious links counter to ${currentCount + 1} for URL: $maliciousUrl")
                    
                    // Use the improved notification handler with consistent Link Status format
                    notificationHandler.showSpamNotification(
                        messageType = "SUSPICIOUS",
                        confidence = 90, // High confidence for SafeBrowsing API detections
                        sender = sender,
                        url = if (isLinkScanningEnabled) maliciousUrl else null,
                        threatType = if (isLinkScanningEnabled) threatTypes else null,
                        notificationId = sender.hashCode() // Use sender hash as notification ID to avoid duplicates
                    )
                }
                
                // Return scan results
                continuation.resume(
                    ScanResult(
                        hasMaliciousUrls = foundDangerousUrl,
                        scannedUrls = urls,
                        threatTypes = threatTypes
                    )
                )
                
            } catch (e: Exception) {
                Log.e(TAG, "Error scanning URLs: ${e.message}", e)
                
                // Update history entries with error
                for (url in urls) {
                    updateHistoryWithError(sender, url, e.message ?: "Unknown error")
                }
                
                // Return error
                continuation.resume(
                    ScanResult(
                        hasMaliciousUrls = false,
                        scannedUrls = urls,
                        error = e.message
                    )
                )
            }
        }
    }
    
    /**
     * Update history with scan result
     */
    private fun updateHistoryWithScanResult(sender: String, url: String, result: SafeBrowsingResult, confidence: Float = 100f) {
        val urlScanResult = when {
            result.isSafe -> UrlScanResult.SAFE
            result.error != null -> UrlScanResult.ERROR
            else -> UrlScanResult.MALICIOUS
        }
        
        // Try to find existing entry
        val history = historyManager.getHistory()
        val existingEntry = history.firstOrNull { 
            it.senderNumber == sender && it.containsUrl && it.url == url 
        }
        
        val entryId = try {
            val smsProcessorClass = Class.forName("com.zrelxr06.malwirus.sms_security.SmsProcessor")
            val generateConsistentIdMethod = smsProcessorClass.getDeclaredMethod("generateConsistentId", String::class.java, String::class.java)
            generateConsistentIdMethod.isAccessible = true
            generateConsistentIdMethod.invoke(null, sender, url) as String
        } catch (e: Exception) {
            existingEntry?.id ?: System.currentTimeMillis().toString()
        }
        val threatInfo = if (result.threats.isNotEmpty()) {
            result.threats.map { it.type }.joinToString(", ") + " (SafeBrowsing)"
        } else if (urlScanResult == UrlScanResult.SAFE) {
            "No threats detected (SafeBrowsing)"
        } else {
            ""
        }
        val updatedEntry = SmsHistoryEntry(
            id = entryId,
            senderNumber = sender,
            confidence = existingEntry?.confidence ?: confidence,
            isSpam = true,
            containsUrl = true,
            url = url,
            urlScanResult = urlScanResult,
            threatInfo = if (existingEntry != null && existingEntry.threatInfo.isNotEmpty() && threatInfo.isNotEmpty() && !existingEntry.threatInfo.contains(threatInfo)) {
                "${existingEntry.threatInfo}, $threatInfo"
            } else if (threatInfo.isNotEmpty()) {
                threatInfo
            } else {
                existingEntry?.threatInfo ?: ""
            }
        )
        historyManager.addEntry(updatedEntry);
    }
    
    /**
     * Update history with error
     */
    private fun updateHistoryWithError(sender: String, url: String, errorMessage: String) {
        // Try to find existing entry
        val history = historyManager.getHistory()
        val existingEntry = history.firstOrNull { 
            it.senderNumber == sender && it.containsUrl && it.url == url 
        }
        
        val entryId = try {
            val smsProcessorClass = Class.forName("com.zrelxr06.malwirus.sms_security.SmsProcessor")
            val generateConsistentIdMethod = smsProcessorClass.getDeclaredMethod("generateConsistentId", String::class.java, String::class.java)
            generateConsistentIdMethod.isAccessible = true
            generateConsistentIdMethod.invoke(null, sender, url) as String
        } catch (e: Exception) {
            existingEntry?.id ?: System.currentTimeMillis().toString()
        }
        val updatedEntry = SmsHistoryEntry(
            id = entryId,
            senderNumber = sender,
            confidence = existingEntry?.confidence ?: 100f,
            isSpam = true,
            containsUrl = true,
            url = url,
            urlScanResult = UrlScanResult.ERROR,
            threatInfo = existingEntry?.threatInfo ?: "Error Scanning URL"
        )
        historyManager.addEntry(updatedEntry);
    }
    
    /**
     * Performs a direct check of a specific URL
     * 
     * @param url The URL to check
     * @return A SafeBrowsingResult with threat information
     */
    suspend fun checkUrl(url: String): SafeBrowsingResult {
        Log.d(TAG, "Direct URL check requested for: $url")
        val result = safeBrowsingClient.checkUrl(url)
        
        if (result.isSafe) {
            Log.d(TAG, "Direct URL check result: SAFE for $url")
        } else if (result.error != null) {
            Log.e(TAG, "Direct URL check error for $url: ${result.error}")
        } else {
            Log.w(TAG, "Direct URL check result: UNSAFE for $url with threats: ${result.threats.joinToString { it.type }}")
        }
        
        return result
    }

    /**
     * Extract URLs from a message without scanning them
     */
    fun extractUrls(message: String): List<String> {
        return safeBrowsingClient.extractUrlsFromMessage(message)
    }
}
