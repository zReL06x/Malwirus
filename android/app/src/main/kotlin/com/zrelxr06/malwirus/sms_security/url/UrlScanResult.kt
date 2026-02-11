package com.zrelxr06.malwirus.sms_security.url

/**
 * Enum representing the result of a URL scan
 */
enum class UrlScanResult {
    SAFE,       // URL was scanned and found to be safe
    MALICIOUS,  // URL was scanned and found to be malicious
    UNKNOWN,    // URL hasn't been scanned yet
    ERROR,      // Error occurred during scanning
    NOT_SCANNED // URL was intentionally not scanned (e.g., link scanning disabled)
}
