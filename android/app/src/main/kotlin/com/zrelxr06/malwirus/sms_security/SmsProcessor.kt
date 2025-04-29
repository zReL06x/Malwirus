package com.zrelxr06.malwirus.sms_security

import android.content.Context
import android.util.Log
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL
import java.util.concurrent.atomic.AtomicInteger
import java.util.regex.Pattern
import com.zrelxr06.malwirus.notification.NotificationHandler
import com.zrelxr06.malwirus.data.HistoryManager
import com.zrelxr06.malwirus.data.SmsHistoryEntry
import com.zrelxr06.malwirus.data.UrlScanResult
import com.zrelxr06.malwirus.data.SuspiciousUrlPatterns
import com.zrelxr06.malwirus.sms_security.google_safebrowsing.SafeBrowsingService
import com.zrelxr06.malwirus.preference.PreferenceManager

data class WhitelistedNumber(
    val number: String,
    val dateAdded: Long = System.currentTimeMillis()
)

class SmsProcessor(private val context: Context) {
    private val TAG = "SmsProcessor"
    private val gson = Gson()
    private val WHITELIST_KEY = "sms_whitelist"
    private val notificationHandler = NotificationHandler(context)
    private val notificationId = AtomicInteger(1000)
    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    private val smsModel = SmsModel(context)
    private val safeBrowsingService = SafeBrowsingService(context)
    private val preferenceManager = PreferenceManager(context)
    private val historyManager = HistoryManager(context)
    
    // Using centralized suspicious URL patterns
    
    fun isNumberWhitelisted(phoneNumber: String): Boolean {
        val whitelistedNumbers = getWhitelistedNumbers()
        return whitelistedNumbers.any { it.number == phoneNumber }
    }

    fun addToWhitelist(phoneNumber: String) {
        val whitelistedNumbers = getWhitelistedNumbers().toMutableList()
        if (!isNumberWhitelisted(phoneNumber)) {
            whitelistedNumbers.add(WhitelistedNumber(phoneNumber))
            saveWhitelistedNumbers(whitelistedNumbers)
        }
    }

    fun removeFromWhitelist(phoneNumber: String) {
        val whitelistedNumbers = getWhitelistedNumbers().toMutableList()
        whitelistedNumbers.removeIf { it.number == phoneNumber }
        saveWhitelistedNumbers(whitelistedNumbers)
    }
    
    /**
     * Get the preference manager instance used by this SmsProcessor
     * @return The preference manager
     */
    fun getPreferenceManager(): PreferenceManager {
        return preferenceManager
    }
    
    /**
     * Increment the count of messages scanned by the app
     */
    private fun incrementScannedMessagesCount() {
        val prefs = context.getSharedPreferences("sms_security_stats", Context.MODE_PRIVATE)
        val currentCount = prefs.getInt("messages_scanned", 0)
        prefs.edit().putInt("messages_scanned", currentCount + 1).apply()
        Log.d(TAG, "Incremented messages scanned count to ${currentCount + 1}")
    }
    
    /**
     * Increment the count of suspicious links found by the app
     */
    private fun incrementSuspiciousLinksCount() {
        val prefs = context.getSharedPreferences("sms_security_stats", Context.MODE_PRIVATE)
        val currentCount = prefs.getInt("suspicious_links_found", 0)
        prefs.edit().putInt("suspicious_links_found", currentCount + 1).apply()
        Log.d(TAG, "Incremented suspicious links count to ${currentCount + 1}")
    }

    fun getWhitelistedNumbers(): List<WhitelistedNumber> {
        val prefs = context.getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
        val json = prefs.getString(WHITELIST_KEY, "[]")
        val type = object : TypeToken<List<WhitelistedNumber>>() {}.type
        return try {
            gson.fromJson(json, type) ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun saveWhitelistedNumbers(numbers: List<WhitelistedNumber>) {
        val json = gson.toJson(numbers)
        val prefs = context.getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
        prefs.edit().putString(WHITELIST_KEY, json).apply()
    }

    fun formatPhoneNumber(number: String): String {
        // Remove any non-digit characters
        return number.replace(Regex("[^0-9+]"), "")
    }
    
    /**
     * Check if a URL is suspicious based on various criteria
     * Delegates to the centralized SuspiciousUrlPatterns utility
     * 
     * @param url The URL to check
     * @return A Pair where the first element is a boolean indicating if the URL is suspicious,
     *         and the second element is a String explaining why (or null if not suspicious)
     */
    fun isUrlSuspicious(url: String): Pair<Boolean, String?> {
        try {
            // Log the URL being checked
            Log.d(TAG, "Checking if URL is suspicious: $url")
            
            // First use the centralized suspicious URL patterns checker
            val (isSuspicious, reason) = SuspiciousUrlPatterns.isUrlSuspicious(url)
            if (isSuspicious) {
                return Pair(true, reason)
            }
            
            // Additional checks specific to SmsProcessor
            try {
                val parsedUrl = URL(if (!url.startsWith("http")) "https://$url" else url)
                
                // Check for IP address in host
                val host = parsedUrl.host
                if (host.matches(Regex("\\d+\\.\\d+\\.\\d+\\.\\d+"))) {
                    Log.d(TAG, "$url uses IP address instead of domain name")
                    return Pair(true, "Suspicious - Uses IP address instead of domain name")
                }
                
                // Check for excessive subdomains (potential for confusion)
                val subdomainCount = host.split(".").size - 2 // Subtract 2 for domain and TLD
                if (subdomainCount > 3) {
                    Log.d(TAG, "$url has excessive subdomains: $subdomainCount")
                    return Pair(true, "Suspicious - Uses excessive subdomains")
                }
                
                // Check for @ symbol in raw URL
                if (url.contains('@')) {
                    return Pair(true, "Suspicious - Contains @ symbol, possible spoofing attempt")
                }
            } catch (e: Exception) {
                // If URL parsing fails, consider it suspicious
                Log.e(TAG, "Error parsing URL: $url", e)
                return Pair(true, "Suspicious - Invalid URL format")
            }
            
            // URL passed all checks
            Log.d(TAG, "URL $url passed all suspicious checks")
            return Pair(false, null)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking URL suspiciousness: ${e.message}", e)
            return Pair(false, null)
        }
    }
    
    /**
     * Extract URLs from text using the centralized method in SuspiciousUrlPatterns
     * 
     * @param text Text potentially containing URLs
     */
    private fun extractUrls(message: String): List<String> {
        // Use the centralized URL extraction method from SuspiciousUrlPatterns
        return SuspiciousUrlPatterns.extractUrls(message)
    }
    
    /**
     * Checks a list of URLs against local suspicious patterns
     * 
     * @param urls List of URLs to check
     * @return Triple of (isSuspicious, reason, suspiciousUrl)
     */
    private fun checkUrlsAgainstLocalPatterns(urls: List<String>): Triple<Boolean, String, String> {
        Log.d(TAG, "Checking ${urls.size} URLs against local patterns")
        
        for (url in urls) {
            Log.d(TAG, "Processing URL in SmsProcessor: $url")
            
            try {
                val (isSuspicious, reason) = SuspiciousUrlPatterns.isUrlSuspicious(url)
                Log.d(TAG, "Result for $url: isSuspicious=$isSuspicious, reason=$reason")
                
                if (isSuspicious) {
                    Log.d(TAG, "Local check found suspicious URL: $url - Reason: $reason")
                    return Triple(true, reason ?: "Suspicious URL pattern", url)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking URL suspiciousness: ${e.message}", e)
            }
        }
        
        Log.d(TAG, "No suspicious URLs found in local check")
        return Triple(false, "", urls.firstOrNull() ?: "")
    }
    
    /**
     * Adds an entry to history with proper status information
     */
    private fun addEntryToHistory(
        sender: String,
        url: String,
        spamConfidence: Float,
        isSeriousSpam: Boolean,
        isMessageSpam: Boolean,
        urlScanResult: UrlScanResult,
        threatInfo: String = ""
    ) {
        Log.d(TAG, "addEntryToHistory called with sender=$sender, url=$url, spamConfidence=$spamConfidence, isSeriousSpam=$isSeriousSpam, isMessageSpam=$isMessageSpam, urlScanResult=$urlScanResult, threatInfo=$threatInfo")
        // Format the threatInfo to include the source (Local Analysis or SafeBrowsing)
        val formattedThreatInfo = when {
            // If threatInfo already includes a source, keep it as is
            threatInfo.contains("(Local Analysis)") || threatInfo.contains("(SafeBrowsing)") -> threatInfo
            
            // If empty threatInfo, create default based on the urlScanResult
            threatInfo.isEmpty() -> {
                when (urlScanResult) {
                    UrlScanResult.SAFE -> {
                        "Safe (SafeBrowsing)"
                    }
                    UrlScanResult.MALICIOUS -> {
                        "Malicious (SafeBrowsing)"
                    }
                    UrlScanResult.UNKNOWN -> {
                        "No threats detected (Local Analysis)"
                    }
                    UrlScanResult.ERROR -> {
                        "Error Scanning URL"
                    }
                    UrlScanResult.NOT_SCANNED -> {
                        "Not Scanned"
                    }
                }
            }
            
            // Non-empty threatInfo but no source, determine and add source
            else -> {
                val source = if (threatInfo.contains("Safe") || 
                                 threatInfo.contains("Phishing") || 
                                 threatInfo.contains("Malware") || 
                                 threatInfo.contains("Unwanted") || 
                                 threatInfo.contains("Malicious")) {
                    "SafeBrowsing"
                } else {
                    "Local Analysis"
                }
                "$threatInfo ($source)"
            }
        }
        
        val entry = SmsHistoryEntry(
            id = generateConsistentId(sender, url),
            senderNumber = sender,
            confidence = spamConfidence,
            isSpam = isSeriousSpam,
            isSuspicious = isMessageSpam && !isSeriousSpam,
            containsUrl = true,
            url = url,
            urlScanResult = urlScanResult,
            threatInfo = formattedThreatInfo
        )
        Log.d(TAG, "Adding entry to history: $entry")
        historyManager.addEntry(entry)
    }
    
    /**
     * Process an incoming SMS message for both spam detection and URL safety
     * 
     * @param sender The phone number that sent the message
     * @param message The content of the SMS message
     * @param checkLinks Whether to check for suspicious links
     */
    suspend fun processMessage(sender: String, message: String, checkLinks: Boolean = true) {
        Log.d(TAG, "Processing message from $sender: '${message.take(50)}${if (message.length > 50) "..." else ""}'")
        
        // Skip processing if the number is whitelisted
        if (isNumberWhitelisted(sender)) {
            Log.d(TAG, "Skipping message from whitelisted number: $sender")
            return
        }
        
        try {
            // Increment messages scanned counter
            incrementScannedMessagesCount()
            // Detect if the message is spam
            val spamDetectionResult = smsModel.detectSpam(message)
            // Parse the confidence from the string result
            // Expected format is like "[[0.08374438, 0.91625565]]" where second value is spam probability
            val spamConfidence = try {
                // Extract the second number from the string using regex
                val regex = "\\[\\[(.*?),\\s*(.*?)\\]\\]".toRegex()
                val matchResult = regex.find(spamDetectionResult)
                if (matchResult != null && matchResult.groupValues.size >= 3) {
                    val spamProb = matchResult.groupValues[2].toFloat()
                    spamProb * 100f // Convert to percentage
                } else {
                    0f // Default if parsing fails
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error parsing spam confidence: ${e.message}")
                0f // Default to 0 if parsing fails
            }
            
            // Three-level classification:
            // < 50% = Ham
            // 50-80% = Suspicious
            // > 80% = Spam
            val isMessageSpam = spamConfidence >= 50f // Consider as potentially harmful if over 50%
            val isSeriousSpam = spamConfidence >= 80f // Consider as definite spam if over 80%
            val messageCategory = when {
                isSeriousSpam -> "Spam"
                isMessageSpam -> "Suspicious"
                else -> "Ham"
            }
            
            Log.d(TAG, "Spam confidence: $spamConfidence, category: $messageCategory")
            
            // Only extract and check URLs if link scanning is enabled
            val isLinkScanningEnabled = preferenceManager.getBoolean("link_scanning_enabled", true)
            val actuallyCheckLinks = checkLinks && isLinkScanningEnabled
            
            val urls = if (actuallyCheckLinks) extractUrls(message) else emptyList()
            
            if (urls.isNotEmpty() && actuallyCheckLinks) {
                Log.d(TAG, "Message contains URLs: ${urls.joinToString()}")
                
                // Different handling based on spam status
                if (isMessageSpam) { // This includes both Suspicious and Spam categories
                    // Check for URLs in the message
                    Log.d(TAG, "Found ${urls.size} URLs in spam message")
                    
                    // Check if SafeBrowsing is enabled
                    val safeBrowsingEnabled = preferenceManager.getBoolean("SMS_SAFEBROWSING", true)
                    val currentNotificationId = notificationId.incrementAndGet()
                    val title = if (isSeriousSpam) "Spam and URL Alert!" else "Suspicious Message and URL Alert!"
                    
                    // First check URLs against our local suspicious patterns
                    val suspiciousUrlResult = checkUrlsAgainstLocalPatterns(urls)
                    val hasMaliciousUrls = suspiciousUrlResult.first
                    val threatType = suspiciousUrlResult.second
                    val maliciousUrl = suspiciousUrlResult.third
                    
                    if (hasMaliciousUrls) {
                        // URL is suspicious based on our local patterns
                        Log.d(TAG, "Found locally suspicious URL in spam message: $maliciousUrl - $threatType")
                        
                        // Increment suspicious links count
                        incrementSuspiciousLinksCount()
                        
                        // Always add to history for locally suspicious result
                        Log.d(TAG, "Calling addEntryToHistory for locally suspicious URL: sender=$sender, url=$maliciousUrl, spamConfidence=$spamConfidence, isSeriousSpam=$isSeriousSpam, isMessageSpam=$isMessageSpam, urlScanResult=MALICIOUS, threatInfo=$threatType")
                        addEntryToHistory(
                            sender = sender,
                            url = maliciousUrl,
                            spamConfidence = spamConfidence,
                            isSeriousSpam = isSeriousSpam,
                            isMessageSpam = isMessageSpam,
                            urlScanResult = UrlScanResult.MALICIOUS,
                            threatInfo = threatType
                        )
                        Log.d(TAG, "addEntryToHistory completed for locally suspicious URL: sender=$sender, url=$maliciousUrl")
                        
                        // Use the new notification system (only includes URL and threat info if link scanning is enabled)
                        notificationHandler.showSpamNotification(
                            messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                            confidence = spamConfidence.toInt(),
                            sender = sender,
                            url = if (isLinkScanningEnabled) maliciousUrl else null,
                            threatType = if (isLinkScanningEnabled) threatType else null,
                            notificationId = currentNotificationId
                        )
                        // Do NOT call SafeBrowsing if local analysis found a suspicious URL
                    } else if (safeBrowsingEnabled) {
                        // No local suspicious patterns found, use Google SafeBrowsing API
                        try {
                            Log.d(TAG, "No suspicious patterns found locally, checking URLs with SafeBrowsing API")
                            val scanResult = safeBrowsingService.scanMessage(sender, message, spamConfidence)
                            
                            if (scanResult.hasMaliciousUrls) {
                                // Malicious URLs found - notification is already shown by SafeBrowsingService
                                Log.d(TAG, "SafeBrowsing found malicious URLs: ${scanResult.threatTypes}")
                                
                                // If malicious URLs were found, increment the counter for each scanned URL
                                // since the scan result indicates they're all malicious
                                for (url in scanResult.scannedUrls) {
                                    incrementSuspiciousLinksCount()
                                    Log.d(TAG, "Incremented suspicious links counter for malicious URL: $url")
                                }
                            } else if (scanResult.error != null) {
                                // Error during scanning
                                Log.e(TAG, "Error during SafeBrowsing scan: ${scanResult.error}")
                                val firstUrl = urls.first()
                                // Log the scan error for diagnostics
                                Log.d(TAG, "URL scan error for: $firstUrl")
                                
                                // Add to history with error status
                                addEntryToHistory(
                                    sender = sender,
                                    url = firstUrl,
                                    spamConfidence = spamConfidence,
                                    isSeriousSpam = isSeriousSpam,
                                    isMessageSpam = isMessageSpam,
                                    urlScanResult = UrlScanResult.ERROR
                                )
                                
                                notificationHandler.showSpamNotification(
                                    messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                                    confidence = spamConfidence.toInt(),
                                    sender = sender,
                                    url = if (isLinkScanningEnabled && scanResult.hasMaliciousUrls) urls.first() else null,
                                    threatType = if (isLinkScanningEnabled && scanResult.hasMaliciousUrls) scanResult.threatTypes else null,
                                    notificationId = currentNotificationId
                                )
                            } else {
                                // URLs are safe
                                Log.d(TAG, "SafeBrowsing found no threats in URLs")
                                val firstUrl = urls.first()
                                
                                // Add entry to history with SafeBrowsing status
                                addEntryToHistory(
                                    sender = sender,
                                    url = firstUrl,
                                    spamConfidence = spamConfidence,
                                    isSeriousSpam = isSeriousSpam,
                                    isMessageSpam = isMessageSpam,
                                    urlScanResult = UrlScanResult.SAFE,
                                    threatInfo = "No threats detected (SafeBrowsing)"
                                )
                                
                                notificationHandler.showSpamNotification(
                                    messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                                    confidence = spamConfidence.toInt(),
                                    sender = sender,
                                    // Only show URL if link scanning is enabled and it's safe
                                    url = if (isLinkScanningEnabled) firstUrl else null,
                                    threatType = if (isLinkScanningEnabled) "No threats detected (SafeBrowsing)" else null,
                                    notificationId = currentNotificationId
                                )
                            }
                        } catch (e: Exception) {
                            // Fallback to basic URL checking if SafeBrowsing fails
                            Log.e(TAG, "SafeBrowsing API error, falling back to basic checks", e)
                            checkUrlsWithBasicRules(sender, urls, spamConfidence, currentNotificationId)
                        }
                    } else {
                        // SafeBrowsing disabled, use basic URL checks
                        Log.d(TAG, "SafeBrowsing disabled, using basic URL checks")
                        checkUrlsWithBasicRules(sender, urls, spamConfidence, currentNotificationId)
                    }
                } else {
                    // Not spam, but still check for URLs if link scanning is enabled
                    if (actuallyCheckLinks) {
                        Log.d(TAG, "Message is not spam but contains URLs, checking them")
                        
                        // Use Google SafeBrowsing API to check URLs if enabled
                        if (preferenceManager.getBoolean("SMS_SAFEBROWSING", true)) {
                            try {
                                val scanResult = safeBrowsingService.scanMessage(sender, message, spamConfidence)
                                // Process scan result for non-spam messages
                                if (scanResult.hasMaliciousUrls) {
                                    // Handle malicious URLs
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Error checking URLs in non-spam message", e)
                            }
                        }
                    }
                    
                    // Show a standard notification based on classification
                    val currentNotificationId = notificationId.incrementAndGet()
                    val title = if (isSeriousSpam) "Spam Alert!" else "Suspicious Message Alert!"
                    val notificationMessage = "From: $sender - ${if (isSeriousSpam) "Spam" else "Suspicious"} message with accuracy of ${spamConfidence.toInt()}%."
                    
                    notificationHandler.showSpamNotification(
                        messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                        confidence = spamConfidence.toInt(),
                        sender = sender,
                        // No URLs to show regardless of link scanning setting
                        url = null,
                        threatType = null,
                        notificationId = currentNotificationId
                    )
                }
            } else if (!isMessageSpam) {
                // Not spam, but still check for URLs if link scanning is enabled
                val urls = if (actuallyCheckLinks) extractUrls(message) else emptyList()
                
                if (urls.isNotEmpty() && actuallyCheckLinks) {
                    Log.d(TAG, "Message is not spam but contains URLs, checking them")
                    
                    // First check URLs against our local suspicious patterns
                    val suspiciousUrlResult = checkUrlsAgainstLocalPatterns(urls)
                    var hasMaliciousUrls = suspiciousUrlResult.first
                    var threatTypes = suspiciousUrlResult.second
                    var maliciousUrl = suspiciousUrlResult.third
                    var scanResult: SafeBrowsingService.ScanResult? = null
                    
                    if (hasMaliciousUrls) {
                        // URL is suspicious based on our local patterns
                        Log.d(TAG, "Found locally suspicious URL in non-spam message: $maliciousUrl - $threatTypes")
                        
                        // Increment suspicious links count
                        incrementSuspiciousLinksCount()
                    }
                    // If not suspicious locally, use Google SafeBrowsing API to check URLs if enabled
                    else if (preferenceManager.getBoolean("SMS_SAFEBROWSING", true)) {
                        try {
                            Log.d(TAG, "No suspicious patterns found locally, checking URLs with SafeBrowsing API")
                            scanResult = safeBrowsingService.scanMessage(sender, message)
                            
                            // Update the history entry regardless of result
                            val firstUrl = urls.first()
                            
                            if (scanResult.hasMaliciousUrls) {
                                // Malicious URLs found in non-spam message
                                hasMaliciousUrls = true
                                threatTypes = scanResult.threatTypes + " (SafeBrowsing)"
                                maliciousUrl = scanResult.scannedUrls.firstOrNull() ?: firstUrl
                                Log.d(TAG, "SafeBrowsing found malicious URLs in non-spam message: ${scanResult.threatTypes}")
                                
                                // Add to history with SafeBrowsing malicious result
                                addEntryToHistory(
                                    sender = sender,
                                    url = maliciousUrl,
                                    spamConfidence = spamConfidence,
                                    isSeriousSpam = false,
                                    isMessageSpam = false,
                                    urlScanResult = UrlScanResult.MALICIOUS,
                                    threatInfo = threatTypes
                                )
                            } else {
                                // URL is safe according to SafeBrowsing
                                Log.d(TAG, "SafeBrowsing found no threats in URL for non-spam message")
                                
                                // Add to history with SafeBrowsing safe result
                                addEntryToHistory(
                                    sender = sender,
                                    url = firstUrl,
                                    spamConfidence = spamConfidence,
                                    isSeriousSpam = false,
                                    isMessageSpam = false,
                                    urlScanResult = UrlScanResult.SAFE,
                                    threatInfo = "No threats detected (SafeBrowsing)"
                                )
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "Error scanning message with SafeBrowsing: ${e.message}")
                        }
                    }
                    
                    if (hasMaliciousUrls) {
                        // Add to history
                        addEntryToHistory(
                            sender = sender,
                            url = maliciousUrl,
                            spamConfidence = spamConfidence,
                            isSeriousSpam = false,
                            isMessageSpam = false,
                            urlScanResult = UrlScanResult.MALICIOUS,
                            threatInfo = threatTypes
                        )
                        
                        // Show notification for malicious URL
                        val currentNotificationId = notificationId.incrementAndGet()
                        val title = if (isSeriousSpam) "URL Security Alert!" else "Suspicious URL Alert!"
                        val notificationMessage = "From: $sender - Message contains a MALICIOUS URL: $maliciousUrl\nThreat: $threatTypes"
                        
                        notificationHandler.showSpamNotification(
                            messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                            confidence = spamConfidence.toInt(),
                            sender = sender,
                            url = if (isLinkScanningEnabled) maliciousUrl else null,
                            threatType = if (isLinkScanningEnabled) threatTypes else null,
                            notificationId = currentNotificationId
                        )
                    } else if (urls.isNotEmpty()) {
                        // URLs are safe or error occurred, don't add to history
                        Log.d(TAG, "No threats found in URLs of non-spam message (Ham)")
                        // Add to history with local analysis status
                        addEntryToHistory(
                            sender = sender,
                            url = urls.first(),
                            spamConfidence = spamConfidence,
                            isSeriousSpam = false,
                            isMessageSpam = false,
                            urlScanResult = UrlScanResult.SAFE,
                            threatInfo = "Local analysis only"
                        )
                    }
                } else {
                    // Message is not spam and no URLs or link scanning disabled
                    Log.d(TAG, "Message is not spam (Ham) and no URLs or link scanning disabled")
                    // We don't log non-spam messages to history, but we've already counted it as scanned
                }
            } else {
                // This is a spam message without URLs
                Log.d(TAG, "Spam message without URLs detected: confidence ${spamConfidence}%")
                
                // Add to history
                historyManager.addEntry(
                    SmsHistoryEntry(
                        id = generateConsistentId(sender, "no_url_${System.currentTimeMillis()}"),
                        senderNumber = sender,
                        confidence = spamConfidence,
                        isSpam = isSeriousSpam,
                        isSuspicious = isMessageSpam && !isSeriousSpam,
                        containsUrl = false
                    )
                )
                
                // Show notification
                val currentNotificationId = notificationId.incrementAndGet()
                val title = if (isSeriousSpam) "Spam Alert!" else "Suspicious Message Alert!"
                val notificationMessage = "From: $sender - ${if (isSeriousSpam) "Spam" else "Suspicious"} message with accuracy of ${spamConfidence.toInt()}%."
                
                notificationHandler.showSpamNotification(
                    messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                    confidence = spamConfidence.toInt(),
                    sender = sender,
                    url = null, // No URL info for this notification
                    threatType = null,
                    notificationId = currentNotificationId
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing message", e)
        }
    }
    
    /**
     * Check URLs with basic rules when SafeBrowsing API is not available
     */
    private fun checkUrlsWithBasicRules(sender: String, urls: List<String>, confidence: Float, notificationId: Int) {
        // Check if auto link scanning is enabled
        val isLinkScanningEnabled = preferenceManager.getBoolean("link_scanning_enabled", true)
        if (!isLinkScanningEnabled) {
            Log.d(TAG, "Link scanning is disabled, skipping URL checks")
            
            // Add URL to history but mark as not scanned
            if (urls.isNotEmpty()) {
                val firstUrl = urls.first()
                this.historyManager.addEntry(
                    SmsHistoryEntry(
                        id = generateConsistentId(sender, firstUrl),
                        senderNumber = sender,
                        confidence = confidence,
                        isSpam = confidence >= 80f,
                        containsUrl = true,
                        url = firstUrl,
                        urlScanResult = UrlScanResult.NOT_SCANNED,
                        threatInfo = "Not scanned: link scanning is disabled"
                    )
                )
            }
            return
        }
        
        Log.d(TAG, "Found ${urls.size} URLs in spam message")
        Log.d(TAG, "Checking ${urls.size} URLs against local patterns")
        
        var foundSuspiciousUrl = false
        var suspiciousReason: String? = null
        var suspiciousUrl: String? = null
        
        for (url in urls) {
            val result = SuspiciousUrlPatterns.isUrlSuspicious(url)
            val isSuspicious = result.first
            val reason = result.second
            if (isSuspicious) {
                foundSuspiciousUrl = true
                suspiciousReason = reason
                suspiciousUrl = url
                break
            }
        }
        
        // Set appropriate title based on whether link scanning is enabled
        val title = if (isLinkScanningEnabled) "Spam and URL Alert!" else "${if (confidence > 80f) "Spam" else "Suspicious"} Message Alert!"
        val notificationMessage: String
        
        if (foundSuspiciousUrl) {
            Log.d(TAG, "Found suspicious URL in spam message using basic rules")
            
            // Don't show URL info if link scanning is disabled
            if (!isLinkScanningEnabled) {
                notificationMessage = "From: $sender - ${if (confidence > 80f) "Spam" else "Suspicious"} message with accuracy of ${confidence.toInt()}%."
            } else {
                notificationMessage = "From: $sender - ${if (confidence > 80f) "Spam" else "Suspicious"} message with accuracy of ${confidence.toInt()}%.\n\nURL detected: $suspiciousUrl\nReason: $suspiciousReason"
            }
            
            // Add to history with a consistent ID based on sender and URL
            this.historyManager.addEntry(
                SmsHistoryEntry(
                    id = generateConsistentId(sender, suspiciousUrl!!),
                    senderNumber = sender,
                    confidence = confidence,
                    isSpam = true,
                    containsUrl = true,
                    url = suspiciousUrl,
                    urlScanResult = UrlScanResult.MALICIOUS,
                    threatInfo = suspiciousReason ?: "SOCIAL_ENGINEERING"
                )
            )
        } else {
            // URL isn't suspicious based on our criteria
            val firstUrl = urls.firstOrNull() ?: "unknown URL"
            
            // If link scanning is disabled, don't show URL in notification
            if (!isLinkScanningEnabled) {
                notificationMessage = "From: $sender - ${if (confidence > 80f) "Spam" else "Suspicious"} message with accuracy of ${confidence.toInt()}%."
            } else {
                notificationMessage = "From: $sender - Spam message with accuracy of ${confidence.toInt()}%.\n\nURL detected (not scanned): $firstUrl"
            }
            
            // Add to history with a consistent ID based on sender and URL
            this.historyManager.addEntry(
                SmsHistoryEntry(
                    id = generateConsistentId(sender, firstUrl),
                    senderNumber = sender,
                    confidence = confidence,
                    isSpam = true,
                    containsUrl = true,
                    url = firstUrl,
                    urlScanResult = UrlScanResult.UNKNOWN
                )
            )
        }
        
        this.notificationHandler.showSpamNotification(
            messageType = if (confidence > 80f) "SPAM" else "SUSPICIOUS",
            confidence = confidence.toInt(),
            sender = sender,
            url = if (isLinkScanningEnabled && foundSuspiciousUrl) suspiciousUrl else null,
            threatType = if (isLinkScanningEnabled && foundSuspiciousUrl) suspiciousReason else null,
            notificationId = notificationId
        )
    }
    
    /**
     * Parse the confidence from model output
     */
    private fun parseConfidence(result: String, label: String): Float {
        val cleanedResult = result.trim().removeSurrounding("[[", "]]")
        val confidenceValues = cleanedResult.split(",")
            .mapNotNull { it.trim().toFloatOrNull() }

        return when {
            label == "spam" && confidenceValues.size >= 2 -> confidenceValues[1] * 100
            confidenceValues.isNotEmpty() -> confidenceValues[0] * 100
            else -> 0f
        }
    }
    
    /**
     * Generate a consistent ID for a message based on sender and URL
     * This ensures that the same message with the same URL doesn't create duplicate entries
     */
    private fun generateConsistentId(sender: String, url: String): String {
        val id = (sender + url).hashCode().toString()
        Log.d(TAG, "generateConsistentId called for sender=$sender, url=$url, generatedId=$id")
        return id
    }
    
    // End of class
}
