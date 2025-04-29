package com.zrelxr06.malwirus.data

data class SmsHistoryEntry(
    val id: String = System.currentTimeMillis().toString(),
    val senderNumber: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isSpam: Boolean,
    val isSuspicious: Boolean = false, // New field for messages with 50-80% confidence
    val confidence: Float,
    val containsUrl: Boolean = false,
    val url: String? = null,
    val urlScanResult: UrlScanResult = UrlScanResult.UNKNOWN,
    val threatInfo: String = ""
)
