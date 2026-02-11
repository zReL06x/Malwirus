package com.zrelxr06.malwirus.sms_security.url

import android.util.Log
import com.zrelxr06.malwirus.MainActivity
import java.util.regex.Pattern
import java.util.regex.Matcher

/**
 * Utility class containing patterns for suspicious URLs
 * This centralizes all the suspicious URL detection patterns to avoid duplication
 */
object SuspiciousUrlPatterns {
    private const val TAG = "SuspiciousUrlPatterns"

    // Local log helpers gated by session-scoped debug flag
    private inline fun logD(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.d(TAG, msg) }

    /**
     * List of suspicious URL domains that should be automatically considered risky
     * These include URL shorteners and free hosting services often used in phishing
     */
    val SUSPICIOUS_DOMAINS = listOf(
        "bit.ly", "tinyurl.com", "t.co", "goo.gl", "ow.ly",
        "buff.ly", "is.gd", "cutt.ly", "rb.gy", "shorte.st",
        "rebrand.ly", "bl.ink", "000webhostapp.com", "wixsite.com",
        "weebly.com", "blogspot.com", "tiny.cc", "shorturl.at",
        "adf.ly", "bc.vc", "v.gd", "clck.ru", "urls.fr", "x.co",
        "soo.gd", "s2r.co", "snip.ly", "tiny.pl", "shorturl.com",
        "titan.cf", "br-icloud.com.br", "pinoyinsta.com",
        "blogspot.cf"
    )

    /**
     * List of suspicious top-level domains (TLDs) that are often used in phishing
     * These TLDs are frequently abused due to low registration costs or lax verification
     */
    val SUSPICIOUS_TLDS = listOf(
        "tk",
        "ml",
        "ga",
        "cf",
        "gq",
        "ly",
        "pw",
        "cc",
        "su",
        "xyz",
        "top",
        "club",
        "icu",
        "br"
    )

    /**
     * Pattern to detect random character sequences in URL paths
     * Phishing URLs often contain random strings in their paths
     */
    val RANDOM_CHAR_PATTERN = Pattern.compile("/[a-zA-Z0-9]{8,}(?=/|$)")

    /**
     * Pattern to detect URLs with numeric IP addresses instead of domains
     * Phishing sites often use IP addresses directly to avoid domain blacklisting
     */
    val IP_ADDRESS_PATTERN = Pattern.compile("https?://(?:[0-9]{1,3}\\.){3}[0-9]{1,3}")

    /**
     * Pattern to detect URLs with hexadecimal IP addresses
     * Another technique used to obfuscate malicious URLs
     */
    val HEX_IP_PATTERN = Pattern.compile("https?://0x[0-9a-f]{8}")

    /**
     * Standard URL pattern with http/https/www
     */
    val STANDARD_URL_PATTERN = Pattern.compile(
        "(?:(?:https?|ftp)://|www\\.)[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6}\\b(?:[-a-zA-Z0-9()@:%_\\+.~#?&//=]*)",
        Pattern.CASE_INSENSITIVE
    )

    /**
     * Extended URL pattern that handles spaces between domain and path
     * Example: https://myservice.co /sign-up-now
     */
    val EXTENDED_URL_PATTERN = Pattern.compile(
        "((?:https?|ftp)://[-a-zA-Z0-9@:%._\\+~#=]{1,256}\\.[a-zA-Z0-9()]{1,6})\\s*((?:/[-a-zA-Z0-9()@:%_\\+.~#?&//=]*)?)",
        Pattern.CASE_INSENSITIVE
    )

    /**
     * Raw domain pattern (e.g., "example.com")
     */
    val RAW_DOMAIN_PATTERN = Pattern.compile(
        "\\b([a-zA-Z0-9][a-zA-Z0-9-]*\\.[a-zA-Z0-9][a-zA-Z0-9-]*(?:\\.[a-zA-Z0-9][a-zA-Z0-9-]*)+)\\b",
        Pattern.CASE_INSENSITIVE
    )

    /**
     * Enhanced raw domain pattern that can detect domains with paths
     * This is especially useful for detecting suspicious domains without http/www prefix
     */
    val ENHANCED_DOMAIN_PATTERN = Pattern.compile(
        "\\b([a-zA-Z0-9][a-zA-Z0-9-]*\\.[a-zA-Z0-9][a-zA-Z0-9-]*(?:\\.[a-zA-Z0-9][a-zA-Z0-9-]*)*)((?:/[^\\s]*)?)",
        Pattern.CASE_INSENSITIVE
    )

    /**
     * Pattern specifically for suspicious TLDs with paths
     * This helps catch domains with suspicious TLDs like .cf, .tk, etc.
     */
    val SUSPICIOUS_TLD_PATTERN = Pattern.compile(
        "\\b([a-zA-Z0-9][a-zA-Z0-9-]*\\.(?:${SUSPICIOUS_TLDS.joinToString("|")}))((?:/[^\\s]*)?)",
        Pattern.CASE_INSENSITIVE
    )

    /**
     * Pattern for URL shorteners with spaces (e.g., "bit.ly abc123")
     */
    val SPECIFIC_SHORTENER_PATTERN = Pattern.compile(
        "\\b(bit\\.ly|t\\.co|goo\\.gl|tinyurl\\.com|discord\\.com)\\s+([a-zA-Z0-9_\\-/]+)\\b",
        Pattern.CASE_INSENSITIVE
    )

    /**
     * Pattern for domains with spaces between domain parts
     * Often used for obfuscation like "bit . ly/abc"
     */
    val OBFUSCATED_DOMAIN_PATTERN = Pattern.compile(
        "([a-zA-Z0-9][a-zA-Z0-9-]*)(\\s+\\.\\s+|\\s*\\[?dot\\]?\\s*)([a-zA-Z0-9][a-zA-Z0-9-]*)((?:\\.\\s*[a-zA-Z0-9][a-zA-Z0-9-]*)*)((?:/[^\\s]*)?)",
        Pattern.CASE_INSENSITIVE
    )

    /**
     * Pattern for obfuscated protocols (hxxp, h**p, etc.)
     */
    val OBFUSCATED_PROTOCOL_PATTERN = Pattern.compile(
        "\\b(h(?:xx|tt|\\*\\*?)p(?:s?)(?::|://))\\s*([^\\s]+)\\b",
        Pattern.CASE_INSENSITIVE
    )

    /**
     * Check if a URL is suspicious based on various criteria
     *
     * @param url The URL to check
     * @return Pair of (isSuspicious, reason)
     */
    fun isUrlSuspicious(url: String): Pair<Boolean, String?> {
        Log.d(TAG, "Checking URL for suspicious patterns: $url")

        // Convert to lowercase for case-insensitive matching
        val lowercaseUrl = url.lowercase()
        Log.d(TAG, "Checking URL (lowercase): $lowercaseUrl")

        // Extract domain from URL for further checks
        var domain: String? = null

        // Try to extract domain using standard URL pattern first
        val standardPattern = Pattern.compile("(?:https?://|www\\.)([^/]+)")
        val standardMatcher = standardPattern.matcher(lowercaseUrl)

        if (standardMatcher.find()) {
            domain = standardMatcher.group(1)
            Log.d(TAG, "Extracted domain from standard URL: $domain")
        } else {
            // If no standard pattern match, try to extract from raw domain format
            val rawPattern = Pattern.compile("^([a-z0-9][a-z0-9-]*\\.[a-z0-9-\\.]+)")
            val rawMatcher = rawPattern.matcher(lowercaseUrl)

            if (rawMatcher.find()) {
                domain = rawMatcher.group(1)
                Log.d(TAG, "Extracted domain from raw URL: $domain")
            }
        }

        // If we couldn't extract a domain, use the whole URL
        if (domain == null) {
            domain = lowercaseUrl
            Log.d(TAG, "Using full URL as domain: $domain")
        }

        // FIRST CHECK: Check against suspicious domains list (highest priority)
        if (domain != null) {
            Log.d(TAG, "Checking domain against suspicious domains list: $domain")

            for (suspiciousDomain in SUSPICIOUS_DOMAINS) {
                // Only consider entries that look like real domains (contain a dot)
                if (!suspiciousDomain.contains('.')) continue
                // Check if the domain contains or equals the suspicious domain
                if (domain == suspiciousDomain ||
                    domain.startsWith("$suspiciousDomain.") ||
                    domain.endsWith(".$suspiciousDomain") ||
                    domain == "www.$suspiciousDomain"
                ) {

                    Log.d(
                        TAG,
                        "Match found! Domain $domain matches suspicious domain $suspiciousDomain"
                    )
                    return Pair(true, "Uses known suspicious domain ($suspiciousDomain)")
                }
            }

            // Check for suspicious TLDs immediately after checking domains
            // This ensures we catch domains with suspicious TLDs like .tk
            for (tld in SUSPICIOUS_TLDS) {
                Log.d(TAG, "Checking against TLD: $tld")
                if (domain.endsWith(".$tld")) {
                    Log.d(TAG, "Match found! Domain $domain ends with suspicious TLD $tld")
                    return Pair(true, "Suspicious - Uses suspicious top-level domain ($tld)")
                }
            }
        }

        // SECOND CHECK: Check URL format patterns that indicate suspicious behavior

        // Check for direct IP addresses in URL
        if (IP_ADDRESS_PATTERN.matcher(url).find()) {
            return Pair(true, "Uses direct IP address instead of domain name")
        }

        // Check for hexadecimal IP addresses
        if (HEX_IP_PATTERN.matcher(url).find()) {
            return Pair(true, "Uses hexadecimal IP address format")
        }

        // Check for random character sequences in URL path
        if (RANDOM_CHAR_PATTERN.matcher(url).find()) {
            return Pair(true, "Contains random character sequence")
        }

        // THIRD CHECK: Check against suspicious TLDs
        if (domain != null) {
            for (tld in SUSPICIOUS_TLDS) {
                Log.d(TAG, "Checking against TLD: $tld")
                if (domain.endsWith(".$tld")) {
                    Log.d(TAG, "Match found! Domain $domain ends with suspicious TLD $tld")
                    return Pair(true, "Suspicious - Uses suspicious top-level domain ($tld)")
                }
            }
        }

        // FOURTH CHECK: Special check for URL shorteners with no path (just the domain)
        // This is a fallback check in case the domain extraction failed
        for (suspiciousDomain in SUSPICIOUS_DOMAINS) {
            if (lowercaseUrl == suspiciousDomain || lowercaseUrl == "www.$suspiciousDomain" ||
                lowercaseUrl == "http://$suspiciousDomain" || lowercaseUrl == "https://$suspiciousDomain" ||
                lowercaseUrl == "http://www.$suspiciousDomain" || lowercaseUrl == "https://www.$suspiciousDomain"
            ) {
                Log.d(
                    TAG,
                    "Match found! URL $lowercaseUrl matches suspicious domain format with $suspiciousDomain"
                )
                return Pair(true, "Uses known URL shortener service ($suspiciousDomain)")
            }
        }

        return Pair(false, null)
    }

    /**
     * Extract URLs from text
     *
     * @param message Text potentially containing URLs
     * @return List of normalized URLs found in the text
     */
    fun extractUrls(message: String): List<String> {
        logD("Extracting URLs from message: ${message.take(50)}${if (message.length > 50) "..." else ""}")
        val urls = mutableListOf<String>()

        // Pre-processing: Normalize common obfuscation techniques
        var normalizedMessage = message

        // Replace common obfuscations like [dot] with actual dots
        normalizedMessage = normalizedMessage.replace("[dot]", ".")
        normalizedMessage = normalizedMessage.replace("[.]", ".")
        normalizedMessage = normalizedMessage.replace("(dot)", ".")

        // First pass: Handle URLs with spaces between domain and path
        // Example: https://myservice.co /sign-up-now
        val extendedUrlMatcher = EXTENDED_URL_PATTERN.matcher(normalizedMessage)
        val urlReplacements = mutableListOf<Triple<String, String, Int>>()

        while (extendedUrlMatcher.find()) {
            val original = extendedUrlMatcher.group(0)
            val domain = extendedUrlMatcher.group(1)
            val path = extendedUrlMatcher.group(2) ?: ""
            val startPos = extendedUrlMatcher.start()

            if (!domain.isNullOrBlank()) {
                // Remove spaces between domain and path
                val fixedUrl = domain + path.trim()
                urlReplacements.add(Triple(original, fixedUrl, startPos))
                Log.d(TAG, "Found URL with spaced path: $original -> $fixedUrl")

                // Add to URLs list directly
                urls.add(fixedUrl)
            }
        }

        // Apply replacements in reverse order
        urlReplacements.sortByDescending { it.third }
        for ((original, replacement, _) in urlReplacements) {
            normalizedMessage = normalizedMessage.replace(original, replacement)
        }

        // Handle obfuscated protocols
        val obfuscatedProtocolMatcher = OBFUSCATED_PROTOCOL_PATTERN.matcher(normalizedMessage)
        val obfuscationReplacements =
            mutableListOf<Triple<String, String, Int>>() // original, replacement, startPosition

        while (obfuscatedProtocolMatcher.find()) {
            val original = obfuscatedProtocolMatcher.group(0)
            val protocol = obfuscatedProtocolMatcher.group(1)
            val domain = obfuscatedProtocolMatcher.group(2)
            val startPos = obfuscatedProtocolMatcher.start()

            val fixedProtocol = when {
                protocol.contains("s") -> "https://"
                else -> "http://"
            }

            val replacement = fixedProtocol + domain
            obfuscationReplacements.add(Triple(original, replacement, startPos))
        }

        // Apply replacements in reverse order to maintain correct positions
        obfuscationReplacements.sortByDescending { it.third }
        for ((original, replacement, _) in obfuscationReplacements) {
            normalizedMessage = normalizedMessage.replace(original, replacement)
        }

        // First pass: Handle domains with spaces between parts (e.g., "bit . ly/abc")
        val obfuscatedDomainMatcher = OBFUSCATED_DOMAIN_PATTERN.matcher(normalizedMessage)
        val spaceReplacements = mutableListOf<Triple<String, String, Int>>()

        while (obfuscatedDomainMatcher.find()) {
            val original = obfuscatedDomainMatcher.group(0)
            val domainFirst = obfuscatedDomainMatcher.group(1)
            val domainSecond = obfuscatedDomainMatcher.group(3)
            val domainRest = obfuscatedDomainMatcher.group(4).replace("\\s+", "")
            val path = obfuscatedDomainMatcher.group(5) ?: ""
            val startPos = obfuscatedDomainMatcher.start()

            val normalizedDomain =
                domainFirst + "." + domainSecond + domainRest.replace("\\s", "") + path
            spaceReplacements.add(Triple(original, normalizedDomain, startPos))
            Log.d(TAG, "Found obfuscated domain: $original -> $normalizedDomain")
        }

        // Apply replacements in reverse order
        spaceReplacements.sortByDescending { it.third }
        for ((original, replacement, _) in spaceReplacements) {
            normalizedMessage = normalizedMessage.replace(original, replacement)
            // Also add this as a URL
            val normalizedUrl = "http://$replacement"
            urls.add(normalizedUrl)
            Log.d(TAG, "Added obfuscated domain as URL: $normalizedUrl")
        }

        // Second pass: standard URL pattern with http/https/www
        val standardMatcher = STANDARD_URL_PATTERN.matcher(normalizedMessage)

        while (standardMatcher.find()) {
            val url = standardMatcher.group()
            Log.d(TAG, "Found standard URL in message: $url")
            if (!url.isNullOrBlank()) {
                // Ensure URL has a scheme
                val normalizedUrl = if (!url.startsWith("http") && !url.startsWith("ftp")) {
                    "http://$url"
                } else {
                    url
                }
                Log.d(TAG, "Normalized standard URL: $normalizedUrl")
                urls.add(normalizedUrl)
            }
        }

        // Create a copy of the message with already found URLs replaced with spaces
        var messageWithoutUrls = normalizedMessage
        for (url in urls) {
            val urlToReplace =
                if (url.startsWith("http://")) url.substring(7) else if (url.startsWith("https://")) url.substring(
                    8
                ) else url
            messageWithoutUrls =
                messageWithoutUrls.replace(urlToReplace, " ".repeat(urlToReplace.length))
        }

        // Third pass: Check for suspicious TLDs with paths first (higher priority)
        val suspiciousTldMatcher = SUSPICIOUS_TLD_PATTERN.matcher(messageWithoutUrls)
        while (suspiciousTldMatcher.find()) {
            val domain = suspiciousTldMatcher.group(1) // Domain with TLD
            val path = suspiciousTldMatcher.group(2) ?: "" // Path (if any)
            val fullUrl = domain + path

            Log.d(TAG, "Found suspicious TLD domain in message: $fullUrl")
            if (!domain.isNullOrBlank()) {
                val normalizedUrl = "http://$fullUrl"
                Log.d(TAG, "Normalized suspicious TLD URL: $normalizedUrl")
                urls.add(normalizedUrl)

                // Update message to avoid duplicate detection
                messageWithoutUrls = messageWithoutUrls.replace(fullUrl, " ".repeat(fullUrl.length))
            }
        }

        // Fourth pass: enhanced domain pattern with paths
        val enhancedDomainMatcher = ENHANCED_DOMAIN_PATTERN.matcher(messageWithoutUrls)
        while (enhancedDomainMatcher.find()) {
            val domain = enhancedDomainMatcher.group(1) // Domain
            val path = enhancedDomainMatcher.group(2) ?: "" // Path (if any)
            val fullUrl = domain + path

            Log.d(TAG, "Found enhanced domain pattern in message: $fullUrl")
            if (!domain.isNullOrBlank()) {
                val normalizedUrl = "http://$fullUrl"
                Log.d(TAG, "Normalized enhanced domain URL: $normalizedUrl")
                urls.add(normalizedUrl)

                // Update message to avoid duplicate detection
                messageWithoutUrls = messageWithoutUrls.replace(fullUrl, " ".repeat(fullUrl.length))
            }
        }

        // Fifth pass: raw domain pattern (e.g., "example.com")
        val rawMatcher = RAW_DOMAIN_PATTERN.matcher(messageWithoutUrls)
        while (rawMatcher.find()) {
            val domain = rawMatcher.group()
            Log.d(TAG, "Found raw domain in message: $domain")
            if (!domain.isNullOrBlank()) {
                val normalizedUrl = "http://$domain"
                Log.d(TAG, "Normalized raw domain: $normalizedUrl")
                urls.add(normalizedUrl)

                // Update message to avoid duplicate detection
                messageWithoutUrls = messageWithoutUrls.replace(domain, " ".repeat(domain.length))
            }
        }

        // Sixth pass: Check for URL shorteners without http/www prefix
        val shortenerPattern = StringBuilder()
        shortenerPattern.append("\\b(") // Word boundary and start group

        // Add all suspicious domains from our list
        // Only include shorteners that are actual domains (contain a dot) to avoid matching words like carrier names
        val shortenerDomains = SUSPICIOUS_DOMAINS.filter { it.length < 30 && it.contains('.') }
        shortenerPattern.append(shortenerDomains.joinToString("|") { Pattern.quote(it) })

        shortenerPattern.append(")(/?[a-zA-Z0-9_\\-]+)?\\b") // Optional path and word boundary

        val shortenerMatcher =
            Pattern.compile(shortenerPattern.toString(), Pattern.CASE_INSENSITIVE)
                .matcher(messageWithoutUrls)
        while (shortenerMatcher.find()) {
            val shortUrl = shortenerMatcher.group()
            Log.d(TAG, "Found URL shortener in message: $shortUrl")
            if (!shortUrl.isNullOrBlank()) {
                val normalizedUrl = "http://$shortUrl"
                Log.d(TAG, "Normalized URL shortener: $normalizedUrl")
                urls.add(normalizedUrl)
            }
        }

        // Seventh pass: Check for specific patterns like "bit.ly" followed by text
        val specificMatcher = SPECIFIC_SHORTENER_PATTERN.matcher(messageWithoutUrls)
        while (specificMatcher.find()) {
            val domain = specificMatcher.group(1)
            val path = specificMatcher.group(2)
            if (!domain.isNullOrBlank() && !path.isNullOrBlank()) {
                val shortUrl = "$domain/$path"
                Log.d(TAG, "Found separated URL shortener in message: $shortUrl")
                val normalizedUrl = "http://$shortUrl"
                Log.d(TAG, "Normalized separated URL shortener: $normalizedUrl")
                urls.add(normalizedUrl)
            }
        }

        // Special pass: Detect URLs with HTTP protocol that have whitespace between parts
        // This will catch cases like 'https://example.com /path' or 'http://domain.com/ folder/file'
        val spaceInUrlPattern =
            Pattern.compile("(https?://[^\\s]+)\\s+(/[^\\s]*)", Pattern.CASE_INSENSITIVE)
        val spaceInUrlMatcher = spaceInUrlPattern.matcher(messageWithoutUrls)

        while (spaceInUrlMatcher.find()) {
            val domain = spaceInUrlMatcher.group(1)
            val path = spaceInUrlMatcher.group(2)
            Log.d(TAG, "Found URL with space in path: $domain$path")
            if (!domain.isNullOrBlank() && !path.isNullOrBlank()) {
                val fullUrl = domain + path
                Log.d(TAG, "Normalized space-containing URL: $fullUrl")
                urls.add(fullUrl)
            }
        }

        // Final pass: Bare domains with suspicious TLDs
        val barePattern = Pattern.compile(
            "\\b([a-zA-Z0-9][a-zA-Z0-9-]*\\.(${SUSPICIOUS_TLDS.joinToString("|")}))(\\b|$)",
            Pattern.CASE_INSENSITIVE
        )
        val bareMatcher = barePattern.matcher(messageWithoutUrls)

        while (bareMatcher.find()) {
            val domain = bareMatcher.group(1)
            Log.d(TAG, "Found bare suspicious domain: $domain")
            if (!domain.isNullOrBlank()) {
                val normalizedUrl = "http://$domain"
                Log.d(TAG, "Normalized bare suspicious domain: $normalizedUrl")
                urls.add(normalizedUrl)
            }
        }

        // Post-processing: Clean up all extracted URLs
        // This removes any remaining spaces in URLs that might have been missed
        val cleanedUrls = urls.map { url ->
            var cleaned = url
            // Fix common URL issues
            if (cleaned.contains(" ")) {
                cleaned = cleaned.replace(" ", "")
                Log.d(TAG, "Cleaned space from URL: $cleaned")
            }
            cleaned
        }

        // Deduplicate and return
        val uniqueUrls = cleanedUrls.distinct()
        logD("Extracted ${uniqueUrls.size} unique URLs from message")
        return uniqueUrls
    }
}
