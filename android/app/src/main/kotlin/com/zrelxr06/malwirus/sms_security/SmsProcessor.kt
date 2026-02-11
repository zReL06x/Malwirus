package com.zrelxr06.malwirus.sms_security

import android.content.Context
import android.util.Log
import com.zrelxr06.malwirus.MainActivity
import com.google.gson.Gson
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.URL
import java.util.concurrent.atomic.AtomicInteger
import java.util.regex.Pattern
import com.zrelxr06.malwirus.notification.NotificationHandler
import com.zrelxr06.malwirus.history.HistoryManager
import com.zrelxr06.malwirus.history.SmsHistoryEntry
import com.zrelxr06.malwirus.history.HistoryHandler
import com.zrelxr06.malwirus.sms_security.url.UrlScanResult
import com.zrelxr06.malwirus.sms_security.url.SuspiciousUrlPatterns
import com.zrelxr06.malwirus.sms_security.google.safebrowsing.SafeBrowsingService
import com.zrelxr06.malwirus.utility.NetworkUtils
import com.zrelxr06.malwirus.preference.PreferenceHandler

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
    private val preferenceHandler = PreferenceHandler(context)
    private val historyHandler = HistoryHandler(context)

    // Using centralized suspicious URL patterns
  // Local log helpers gated by session-scoped debug flag
  private inline fun logD(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.d(TAG, msg) }
  private inline fun logI(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.i(TAG, msg) }
  private inline fun logW(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.w(TAG, msg) }
  private inline fun logE(msg: String, t: Throwable? = null) {
      if (MainActivity.DEBUG_LOGS_ENABLED) {
          if (t != null) Log.e(TAG, msg, t) else Log.e(TAG, msg)
      }
  }

    // Public non-suspending wrapper to trigger processing from platform channel
    fun processAsync(sender: String, message: String, checkLinks: Boolean = true) {
        coroutineScope.launch {
            try {
                processMessage(sender, message, checkLinks)
            } catch (e: Exception) {
                logE("processAsync error: ${e.message}", e)
            }
        }
    }

    fun isNumberWhitelisted(phoneNumber: String): Boolean {
        val whitelistedNumbers = getWhitelistedNumbers()
        val normalized = normalizeToLocalFormat(phoneNumber)
        val result = whitelistedNumbers.any { numbersEqual(it.number, phoneNumber) }
        try {
            logD("Whitelist size=${whitelistedNumbers.size}, numbers=${whitelistedNumbers.map { it.number }}, incoming=$phoneNumber (norm=$normalized), match=$result")
        } catch (_: Exception) {}
        return result
    }

    fun addToWhitelist(phoneNumber: String) {
        val normalized = normalizeToLocalFormat(phoneNumber)
        val whitelistedNumbers = getWhitelistedNumbers().toMutableList()
        if (!isNumberWhitelisted(normalized)) {
            whitelistedNumbers.add(WhitelistedNumber(normalized))
            saveWhitelistedNumbers(whitelistedNumbers)
        }
    }

    fun removeFromWhitelist(phoneNumber: String) {
        val normalized = normalizeToLocalFormat(phoneNumber)
        val whitelistedNumbers = getWhitelistedNumbers().toMutableList()
        whitelistedNumbers.removeIf { normalizeToLocalFormat(it.number) == normalized }
        saveWhitelistedNumbers(whitelistedNumbers)
    }

    /**
     * Get the preference manager instance used by this SmsProcessor
     * @return The preference manager
     */
    fun getPreferenceHandler(): PreferenceHandler {
        return preferenceHandler
    }

    /**
     * Increment the count of messages scanned by the app
     */
    private fun incrementScannedMessagesCount() {
        val prefs = context.getSharedPreferences("sms_security_stats", Context.MODE_PRIVATE)
        val currentCount = prefs.getInt("messages_scanned", 0)
        prefs.edit().putInt("messages_scanned", currentCount + 1).apply()
        logD("Incremented messages scanned count to ${currentCount + 1}")
    }

    /**
     * Increment the count of suspicious links found by the app
     */
    private fun incrementSuspiciousLinksCount() {
        val prefs = context.getSharedPreferences("sms_security_stats", Context.MODE_PRIVATE)
        val currentCount = prefs.getInt("suspicious_links_found", 0)
        prefs.edit().putInt("suspicious_links_found", currentCount + 1).apply()
        logD("Incremented suspicious links count to ${currentCount + 1}")
    }

    fun getWhitelistedNumbers(): List<WhitelistedNumber> {
        val prefs = context.getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
        val json = prefs.getString(WHITELIST_KEY, "[]")
        return try {
            val arr = gson.fromJson(json, Array<WhitelistedNumber>::class.java)
            arr?.toList() ?: emptyList()
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

    // Normalize to local 11-digit format used across the app (e.g., +63XXXXXXXXXX -> 0XXXXXXXXXX)
    private fun normalizeToLocalFormat(number: String): String {
        val cleaned = try { formatPhoneNumber(number) } catch (_: Exception) { number.replace(Regex("[^0-9+]"), "") }
        if (cleaned.startsWith("+63") && cleaned.length >= 13) return "0" + cleaned.substring(3)
        if (cleaned.startsWith("63") && cleaned.length >= 12) return "0" + cleaned.substring(2)
        return cleaned
    }

    // Compare numbers robustly: normalize then allow suffix match to tolerate device/emulator formats
    private fun numbersEqual(a: String, b: String): Boolean {
        val na = normalizeToLocalFormat(a)
        val nb = normalizeToLocalFormat(b)
        if (na == nb) return true
        // If either side is shortened (e.g., emulator), compare by ending digits with a minimum length
        val minLen = minOf(na.length, nb.length)
        val required = if (minLen >= 11) 11 else if (minLen >= 10) 10 else 9
        return na.takeLast(required) == nb.takeLast(required)
    }

    /**
     * Returns true if the sender is a valid 11-digit numeric mobile number.
     * Ignores alphanumeric (e.g., GCASH) and landline/non-11-digit numbers.
     */
    private fun isValid11DigitNumber(sender: String): Boolean {
        return sender.matches(Regex("^[0-9]{11}$"))
    }

    /**
     * Auto-add sender to call blocklist with reason "spam" when enabled and valid.
     */
    private fun autoBlockSpamSenderIfEnabled(sender: String) {
        try {
            // Normalize then validate (proceed for 11-digit numbers; allow >=9 digits for some devices)
            val normalizedSender = normalizeToLocalFormat(sender)
            val digitsOnly = normalizedSender.replace(Regex("[^0-9]"), "")
            if (!(digitsOnly.length >= 11 || digitsOnly.length >= 9)) return

            // Respect user preference (default ON)
            val enabled = preferenceHandler.getBoolean("auto_block_spam_senders", true)
            if (!enabled) return

            val gson = Gson()
            // Update call_blocklist (list of strings)
            val currentJson = preferenceHandler.getString("call_blocklist", "[]")
            val list: MutableList<String> = try {
                val arr = gson.fromJson(currentJson, Array<String>::class.java)
                arr?.toMutableList() ?: mutableListOf()
            } catch (e: Exception) { mutableListOf() }

            var changed = false
            if (!list.any { numbersEqual(it, normalizedSender) }) {
                list.add(normalizedSender)
                changed = true
            }

            if (changed) {
                preferenceHandler.saveString("call_blocklist", gson.toJson(list))
            }

            // Store reason mapping: number -> "spam"
            val reasonsJson = preferenceHandler.getString("call_blocklist_reasons", "{}")
            val map: MutableMap<String, String> = try {
                val jsonObj = gson.fromJson(reasonsJson, com.google.gson.JsonObject::class.java)
                val m = mutableMapOf<String, String>()
                if (jsonObj != null) {
                    for ((k, v) in jsonObj.entrySet()) {
                        m[k] = v.asString
                    }
                }
                m
            } catch (e: Exception) { mutableMapOf() }
            if (map[normalizedSender] != "spam") {
                map[normalizedSender] = "spam"
                preferenceHandler.saveString("call_blocklist_reasons", gson.toJson(map))
            }
        } catch (_: Exception) {
            // Ignore auto-block errors to avoid disrupting SMS processing
        }
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
            logD("Checking if URL is suspicious: $url")

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
                    logD("$url uses IP address instead of domain name")
                    return Pair(true, "Suspicious - Uses IP address instead of domain name")
                }

                // Check for excessive subdomains (potential for confusion)
                val subdomainCount = host.split(".").size - 2 // Subtract 2 for domain and TLD
                if (subdomainCount > 3) {
                    logD("$url has excessive subdomains: $subdomainCount")
                    return Pair(true, "Suspicious - Uses excessive subdomains")
                }

                // Check for @ symbol in raw URL
                if (url.contains('@')) {
                    return Pair(true, "Suspicious - Contains @ symbol, possible spoofing attempt")
                }
            } catch (e: Exception) {
                // If URL parsing fails, consider it suspicious
                logE("Error parsing URL: $url", e)
                return Pair(true, "Suspicious - Invalid URL format")
            }

            // URL passed all checks
            logD("URL $url passed all suspicious checks")
            return Pair(false, null)
        } catch (e: Exception) {
            logE("Error checking URL suspiciousness: ${e.message}", e)
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
        logD("Checking ${urls.size} URLs against local patterns")

        for (url in urls) {
            logD("Processing URL in SmsProcessor: $url")

            try {
                val (isSuspicious, reason) = SuspiciousUrlPatterns.isUrlSuspicious(url)
                logD("Result for $url: isSuspicious=$isSuspicious, reason=$reason")

                if (isSuspicious) {
                    logD("Local check found suspicious URL: $url - Reason: $reason")
                    return Triple(true, reason ?: "Suspicious URL pattern", url)
                }
            } catch (e: Exception) {
                logE("Error checking URL suspiciousness: ${e.message}", e)
            }
        }

        logD("No suspicious URLs found in local check")
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
        logD("addEntryToHistory called with sender=$sender, url=$url, spamConfidence=$spamConfidence, isSeriousSpam=$isSeriousSpam, isMessageSpam=$isMessageSpam, urlScanResult=$urlScanResult, threatInfo=$threatInfo")
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
                    threatInfo.contains("Malicious")
                ) {
                    "SafeBrowsing"
                } else {
                    "Local Analysis"
                }
                "$threatInfo ($source)"
            }
        }

        val entry = SmsHistoryEntry(
            senderNumber = sender,
            confidence = spamConfidence,
            isSpam = isSeriousSpam,
            isSuspicious = isMessageSpam && !isSeriousSpam,
            containsUrl = true,
            url = url,
            urlScanResult = urlScanResult,
            threatInfo = formattedThreatInfo
        )
        logD("Adding entry to history: $entry")
        historyHandler.addEntry(entry)
    }

    /**
     * Process an incoming SMS message for both spam detection and URL safety
     *
     * @param sender The phone number that sent the message
     * @param message The content of the SMS message
     * @param checkLinks Whether to check for suspicious links
     */
    suspend fun processMessage(sender: String, message: String, checkLinks: Boolean = true) {
        logD("Processing message from $sender: '${message.take(50)}${if (message.length > 50) "..." else ""}'")

        // Skip processing if the number is whitelisted
        if (isNumberWhitelisted(sender)) {
            logD("Skipping message from whitelisted number: $sender")
            return
        }

        try {
            // Increment messages scanned counter
            incrementScannedMessagesCount()
            // Detect if the message is spam
            val spamDetectionResult = smsModel.detectSpam(message)
            // Parse the confidence from the string result
            // Expected format: "[[hamProb, spamProb]]"
            val (hamConfidence, spamConfidence) = try {
                val regex = "\\[\\[(.*?),\\s*(.*?)\\]\\]".toRegex()
                val matchResult = regex.find(spamDetectionResult)
                if (matchResult != null && matchResult.groupValues.size >= 3) {
                    val hamProb = matchResult.groupValues[1].toFloat() * 100f
                    val spamProb = matchResult.groupValues[2].toFloat() * 100f
                    Pair(hamProb, spamProb)
                } else {
                    Pair(0f, 0f)
                }
            } catch (e: Exception) {
                logE("Error parsing confidences: ${e.message}")
                Pair(0f, 0f)
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

            val displayConfidence = if (isMessageSpam) spamConfidence else hamConfidence
            logD("Ham confidence: ${hamConfidence}, Spam confidence: ${spamConfidence}, category: $messageCategory")

            // Auto-block if message is flagged (Suspicious or Spam). Validation inside will normalize and allow >=9 digits
            if (isMessageSpam) {
                autoBlockSpamSenderIfEnabled(sender)
            }

            // Only extract and check URLs if link scanning is enabled
            val isLinkScanningEnabled = preferenceHandler.getBoolean("link_scanning_enabled", true)
            val actuallyCheckLinks = checkLinks && isLinkScanningEnabled

            val urls = if (actuallyCheckLinks) extractUrls(message) else emptyList()

            if (urls.isNotEmpty() && actuallyCheckLinks) {
                logD("Message contains URLs: ${urls.joinToString()}")

                // Different handling based on spam status
                if (isMessageSpam) { // This includes both Suspicious and Spam categories
                    // Check for URLs in the message
                    logD("Found ${urls.size} URLs in spam message")

                    // Check if SafeBrowsing is enabled
                    val safeBrowsingEnabled = preferenceHandler.getBoolean("SMS_SAFEBROWSING", true)
                    val currentNotificationId = notificationId.incrementAndGet()
                    val title =
                        if (isSeriousSpam) "Spam and URL Alert!" else "Suspicious Message and URL Alert!"

                    // First check URLs against our local suspicious patterns
                    val suspiciousUrlResult = checkUrlsAgainstLocalPatterns(urls)
                    val hasMaliciousUrls = suspiciousUrlResult.first
                    val threatType = suspiciousUrlResult.second
                    val maliciousUrl = suspiciousUrlResult.third

                    if (hasMaliciousUrls) {
                        // URL is suspicious based on our local patterns
                        logD("Found locally suspicious URL in spam message: $maliciousUrl - $threatType")

                        // Increment suspicious links count
                        incrementSuspiciousLinksCount()

                        // Always add to history for locally suspicious result
                        logD("Calling addEntryToHistory for locally suspicious URL: sender=$sender, url=$maliciousUrl, spamConfidence=$spamConfidence, isSeriousSpam=$isSeriousSpam, isMessageSpam=$isMessageSpam, urlScanResult=MALICIOUS, threatInfo=$threatType")
                        addEntryToHistory(
                            sender = sender,
                            url = maliciousUrl,
                            spamConfidence = spamConfidence,
                            isSeriousSpam = isSeriousSpam,
                            isMessageSpam = isMessageSpam,
                            urlScanResult = UrlScanResult.MALICIOUS,
                            threatInfo = threatType
                        )
                        logD("addEntryToHistory completed for locally suspicious URL: sender=$sender, url=$maliciousUrl")

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
                        // Check for internet connection before SafeBrowsing
                        if (!NetworkUtils.isNetworkAvailable(context)) {
                            // No network: treat as Safe (Local Analysis)
                            val firstUrl = urls.first()
                            addEntryToHistory(
                                sender = sender,
                                url = firstUrl,
                                spamConfidence = spamConfidence,
                                isSeriousSpam = isSeriousSpam,
                                isMessageSpam = isMessageSpam,
                                urlScanResult = UrlScanResult.SAFE,
                                threatInfo = "Safe (Local Analysis)"
                            ) // <-- Always set threatInfo
                            notificationHandler.showSpamNotification(
                                messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                                confidence = spamConfidence.toInt(),
                                sender = sender,
                                url = if (isLinkScanningEnabled) firstUrl else null,
                                threatType = if (isLinkScanningEnabled) "Safe (Local Analysis)" else null,
                                notificationId = currentNotificationId
                            )
                            logD("No network: used local analysis for sender=$sender, url=$firstUrl")
                        } else
                        // No local suspicious patterns found, use Google SafeBrowsing API
                            try {
                                logD("No suspicious patterns found locally, checking URLs with SafeBrowsing API")
                                val scanResult =
                                    safeBrowsingService.scanMessage(sender, message, spamConfidence)

                                // After SafeBrowsing completes, add a single merged entry to history
                                val firstUrl = urls.first()
                                val urlScanResult = when {
                                    scanResult.error != null -> UrlScanResult.ERROR
                                    scanResult.hasMaliciousUrls -> UrlScanResult.MALICIOUS
                                    else -> UrlScanResult.SAFE
                                }
                                val threatInfo = when {
                                    scanResult.error != null -> scanResult.error ?: "Error during scan"
                                    scanResult.hasMaliciousUrls -> scanResult.threatTypes
                                    else -> "No threats detected (SafeBrowsing)"
                                }
                                addEntryToHistory(
                                    sender = sender,
                                    url = firstUrl,
                                    spamConfidence = spamConfidence,
                                    isSeriousSpam = isSeriousSpam,
                                    isMessageSpam = isMessageSpam,
                                    urlScanResult = urlScanResult,
                                    threatInfo = threatInfo
                                )

                                // Notification logic
                                notificationHandler.showSpamNotification(
                                    messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                                    confidence = spamConfidence.toInt(),
                                    sender = sender,
                                    url = if (isLinkScanningEnabled) firstUrl else null,
                                    threatType = if (isLinkScanningEnabled) threatInfo else null,
                                    notificationId = currentNotificationId
                                )

                                // Increment suspicious links count if malicious
                                if (scanResult.hasMaliciousUrls) {
                                    for (url in scanResult.scannedUrls) {
                                        incrementSuspiciousLinksCount()
                                        logD("Incremented suspicious links counter for malicious URL: $url")
                                    }
                                }
                                // End merged SafeBrowsing flow
                            } catch (e: Exception) {
                                // Fallback to basic URL checking if SafeBrowsing fails
                                logE("SafeBrowsing API error, falling back to basic checks", e)
                                checkUrlsWithBasicRules(
                                    sender,
                                    urls,
                                    spamConfidence,
                                    currentNotificationId
                                )
                            }
                    } else {
                        // SafeBrowsing disabled, use basic URL checks
                        logD("SafeBrowsing disabled, using basic URL checks")
                        checkUrlsWithBasicRules(sender, urls, spamConfidence, currentNotificationId)
                    }
                } else {
                    // Not spam, but still check for URLs if link scanning is enabled
                    if (actuallyCheckLinks) {
                        logD("Message is not spam but contains URLs, checking them")

                        // Use Google SafeBrowsing API to check URLs if enabled
                        if (preferenceHandler.getBoolean("SMS_SAFEBROWSING", true)) {
                            try {
                                val scanResult =
                                    safeBrowsingService.scanMessage(sender, message, spamConfidence)
                                val firstUrl = urls.first()
                                if (scanResult.hasMaliciousUrls) {
                                    val maliciousUrl = scanResult.scannedUrls.firstOrNull() ?: firstUrl
                                    val threatInfo = scanResult.threatTypes + " (SafeBrowsing)"
                                    addEntryToHistory(
                                        sender = sender,
                                        url = maliciousUrl,
                                        spamConfidence = displayConfidence,
                                        isSeriousSpam = false,
                                        isMessageSpam = false,
                                        urlScanResult = UrlScanResult.MALICIOUS,
                                        threatInfo = threatInfo
                                    )
                                } else {
                                    addEntryToHistory(
                                        sender = sender,
                                        url = firstUrl,
                                        spamConfidence = displayConfidence,
                                        isSeriousSpam = false,
                                        isMessageSpam = false,
                                        urlScanResult = UrlScanResult.SAFE,
                                        threatInfo = "No threats detected (SafeBrowsing)"
                                    )
                                }
                            } catch (e: Exception) {
                                logE("Error checking URLs in non-spam message", e)
                                // Fallback: record as local analysis safe when SafeBrowsing fails
                                val firstUrl = urls.first()
                                addEntryToHistory(
                                    sender = sender,
                                    url = firstUrl,
                                    spamConfidence = displayConfidence,
                                    isSeriousSpam = false,
                                    isMessageSpam = false,
                                    urlScanResult = UrlScanResult.SAFE,
                                    threatInfo = "No threats detected (Local Analysis)"
                                )
                            }
                        }
                    }

                    // Only show notification for actual spam/suspicious messages
                    if (isMessageSpam) {
                        val currentNotificationId = notificationId.incrementAndGet()
                        val title = if (isSeriousSpam) "Spam Alert!" else "Suspicious Message Alert!"
                        val notificationMessage =
                            "From: $sender - ${if (isSeriousSpam) "Spam" else "Suspicious"} message with accuracy of ${spamConfidence.toInt()}%."

                        notificationHandler.showSpamNotification(
                            messageType = if (isSeriousSpam) "SPAM" else "SUSPICIOUS",
                            confidence = spamConfidence.toInt(),
                            sender = sender,
                            // No URLs to show regardless of link scanning setting
                            url = null,
                            threatType = null,
                            notificationId = currentNotificationId
                        )
                        
                        // Log the notification
                        logD("Shown notification for ${if (isSeriousSpam) "SPAM" else "SUSPICIOUS"} message from $sender")
                    } else {
                        // For non-spam messages with URLs and link scanning disabled, add a not-scanned entry
                        if (urls.isNotEmpty() && !actuallyCheckLinks) {
                            val firstUrl = urls.first()
                            addEntryToHistory(
                                sender = sender,
                                url = firstUrl,
                                spamConfidence = displayConfidence,
                                isSeriousSpam = false,
                                isMessageSpam = false,
                                urlScanResult = UrlScanResult.NOT_SCANNED,
                                threatInfo = "Not Scanned"
                            )
                            logD("Added NOT_SCANNED URL to history for non-spam message: $firstUrl")
                        }
                    }
                }
            } else if (!isMessageSpam) {
                // Not spam, but still check for URLs if link scanning is enabled
                val urls = if (actuallyCheckLinks) extractUrls(message) else emptyList()

                if (urls.isNotEmpty() && actuallyCheckLinks) {
                    logD("Message is not spam but contains URLs, checking them")

                    // First check URLs against our local suspicious patterns
                    val suspiciousUrlResult = checkUrlsAgainstLocalPatterns(urls)
                    var hasMaliciousUrls = suspiciousUrlResult.first
                    var threatTypes = suspiciousUrlResult.second
                    var maliciousUrl = suspiciousUrlResult.third
                    var scanResult: SafeBrowsingService.ScanResult? = null

                    if (hasMaliciousUrls) {
                        // URL is suspicious based on our local patterns
                        logD("Found locally suspicious URL in non-spam message: $maliciousUrl - $threatTypes")

                        // Increment suspicious links count
                        incrementSuspiciousLinksCount()
                        
                        // Add to history with malicious result
                        addEntryToHistory(
                            sender = sender,
                            url = maliciousUrl,
                            spamConfidence = displayConfidence,
                            isSeriousSpam = false,
                            isMessageSpam = false,
                            urlScanResult = UrlScanResult.MALICIOUS,
                            threatInfo = threatTypes
                        )
                        
                        // Show notification for malicious URL in non-spam message
                        notificationHandler.showSpamNotification(
                            messageType = "SUSPICIOUS_URL",
                            confidence = displayConfidence.toInt(),
                            sender = sender,
                            url = maliciousUrl,
                            threatType = threatTypes,
                            notificationId = notificationId.incrementAndGet()
                        )
                    }
                    // If not suspicious locally, use Google SafeBrowsing API to check URLs if enabled
                    else if (preferenceHandler.getBoolean("SMS_SAFEBROWSING", true)) {
                        try {
                            logD("No suspicious patterns found locally, checking URLs with SafeBrowsing API")
                            scanResult = safeBrowsingService.scanMessage(sender, message)

                            // Update the history entry regardless of result
                            val firstUrl = urls.first()

                            if (scanResult.hasMaliciousUrls) {
                                // Malicious URLs found in non-spam message
                                hasMaliciousUrls = true
                                threatTypes = scanResult.threatTypes + " (SafeBrowsing)"
                                maliciousUrl = scanResult.scannedUrls.firstOrNull() ?: firstUrl
                                logD("SafeBrowsing found malicious URLs in non-spam message: ${scanResult.threatTypes}")

                                // Add to history with SafeBrowsing malicious result
                                addEntryToHistory(
                                    sender = sender,
                                    url = maliciousUrl,
                                    spamConfidence = displayConfidence,
                                    isSeriousSpam = false,
                                    isMessageSpam = false,
                                    urlScanResult = UrlScanResult.MALICIOUS,
                                    threatInfo = threatTypes
                                )
                            } else {
                                // URL is safe according to SafeBrowsing
                                logD("SafeBrowsing found no threats in URL for non-spam message")

                                // Add to history with SafeBrowsing safe result
                                addEntryToHistory(
                                    sender = sender,
                                    url = firstUrl,
                                    spamConfidence = displayConfidence,
                                    isSeriousSpam = false,
                                    isMessageSpam = false,
                                    urlScanResult = UrlScanResult.SAFE,
                                    threatInfo = "No threats detected (SafeBrowsing)"
                                )
                            }
                        } catch (e: Exception) {
                            logE("Error scanning message with SafeBrowsing: ${e.message}")
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
                        val title =
                            if (isSeriousSpam) "URL Security Alert!" else "Suspicious URL Alert!"
                        val notificationMessage =
                            "From: $sender - Message contains a MALICIOUS URL: $maliciousUrl\nThreat: $threatTypes"

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
                        logD("No threats found in URLs of non-spam message (Ham)")
                        // Add to history with local analysis status
                        addEntryToHistory(
                            sender = sender,
                            url = urls.first(),
                            spamConfidence = displayConfidence,
                            isSeriousSpam = false,
                            isMessageSpam = false,
                            urlScanResult = UrlScanResult.SAFE,
                            threatInfo = "No threats detected (Local Analysis)"
                        )
                    }
                } else {
                    // Message is not spam and no URLs or link scanning disabled
                    logD("Message is not spam (Ham) and no URLs or link scanning disabled")
                    // Add a simple ham entry to history for visibility
                    historyHandler.addEntry(
                        SmsHistoryEntry(
                            senderNumber = sender,
                            confidence = displayConfidence,
                            isSpam = false,
                            isSuspicious = false,
                            containsUrl = false,
                            url = null,
                            urlScanResult = UrlScanResult.SAFE,
                            threatInfo = "No URL detected"
                        )
                    )
                }
            } else {
                // This is a spam message without URLs
                logD("Spam message without URLs detected: confidence ${spamConfidence}%")

                // Add to history
                historyHandler.addEntry(
                    SmsHistoryEntry(
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
                val notificationMessage =
                    "From: $sender - ${if (isSeriousSpam) "Spam" else "Suspicious"} message with accuracy of ${spamConfidence.toInt()}%."

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
            logE("Error processing message", e)
        }
    }

    /**
     * Check URLs with basic rules when SafeBrowsing API is not available
     */
    private fun checkUrlsWithBasicRules(
        sender: String,
        urls: List<String>,
        confidence: Float,
        notificationId: Int
    ) {
        // Check if auto link scanning is enabled
        val isLinkScanningEnabled = preferenceHandler.getBoolean("link_scanning_enabled", true)
        if (!isLinkScanningEnabled) {
            logD("Link scanning is disabled, skipping URL checks")

            // Add URL to history but mark as not scanned
            if (urls.isNotEmpty()) {
                val firstUrl = urls.first()
                this.historyHandler.addEntry(
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

        logD("Found ${urls.size} URLs in spam message")
        logD("Checking ${urls.size} URLs against local patterns")

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
        val title =
            if (isLinkScanningEnabled) "Spam and URL Alert!" else "${if (confidence > 80f) "Spam" else "Suspicious"} Message Alert!"
        val notificationMessage: String

        if (foundSuspiciousUrl) {
            logD("Found suspicious URL in spam message using basic rules")

            // Don't show URL info if link scanning is disabled
            if (!isLinkScanningEnabled) {
                notificationMessage =
                    "From: $sender - ${if (confidence > 80f) "Spam" else "Suspicious"} message with accuracy of ${confidence.toInt()}%."
            } else {
                notificationMessage =
                    "From: $sender - ${if (confidence > 80f) "Spam" else "Suspicious"} message with accuracy of ${confidence.toInt()}%.\n\nURL detected: $suspiciousUrl\nReason: $suspiciousReason"
            }

            // Add to history with a consistent ID based on sender and URL
            this.historyHandler.addEntry(
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
                notificationMessage =
                    "From: $sender - ${if (confidence > 80f) "Spam" else "Suspicious"} message with accuracy of ${confidence.toInt()}%."
            } else {
                notificationMessage =
                    "From: $sender - Spam message with accuracy of ${confidence.toInt()}%.\n\nURL detected (not scanned): $firstUrl"
            }

            // Add to history with a consistent ID based on sender and URL
            this.historyHandler.addEntry(
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
        logD("generateConsistentId called for sender=$sender, url=$url, generatedId=$id")
        return id
    }

    // End of class
}
