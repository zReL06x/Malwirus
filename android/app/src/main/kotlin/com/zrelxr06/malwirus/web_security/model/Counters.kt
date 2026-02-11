package com.zrelxr06.malwirus.web_security.model

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Counters and simple stats for the VPN service
 * - Bytes In/Out are volatile (session only)
 * - DNS Queries/Blocked persist across app launches until user resets
 */
object Counters {
    private const val PREF_NAME = "web_vpn_stats"
    private const val KEY_DNS_QUERIES = "dns_queries"
    private const val KEY_DNS_BLOCKED = "dns_blocked"

    private var prefs: SharedPreferences? = null

    fun init(context: Context) {
        if (prefs == null) {
            prefs = context.applicationContext.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            // Load persisted DNS stats
            _dnsQueries.value = prefs?.getLong(KEY_DNS_QUERIES, 0L) ?: 0L
            _dnsBlocked.value = prefs?.getLong(KEY_DNS_BLOCKED, 0L) ?: 0L
        }
    }

    private fun persistDns() {
        prefs?.edit()
            ?.putLong(KEY_DNS_QUERIES, _dnsQueries.value)
            ?.putLong(KEY_DNS_BLOCKED, _dnsBlocked.value)
            ?.apply()
    }

    private val _bytesIn = MutableStateFlow(0L)
    private val _bytesOut = MutableStateFlow(0L)
    private val _dnsQueries = MutableStateFlow(0L)
    private val _dnsBlocked = MutableStateFlow(0L)

    val bytesIn: StateFlow<Long> = _bytesIn
    val bytesOut: StateFlow<Long> = _bytesOut
    val dnsQueries: StateFlow<Long> = _dnsQueries
    val dnsBlocked: StateFlow<Long> = _dnsBlocked

    fun incBytesIn(delta: Long) { if (delta > 0) _bytesIn.value += delta }
    fun incBytesOut(delta: Long) { if (delta > 0) _bytesOut.value += delta }
    fun incDnsQueries() { _dnsQueries.value += 1; persistDns() }
    fun incDnsBlocked() { _dnsBlocked.value += 1; persistDns() }

    // Resets only DNS stats (persistent)
    fun resetDns() {
        _dnsQueries.value = 0
        _dnsBlocked.value = 0
        persistDns()
    }

    // Keeps existing API; if used, resets everything (not used by UI anymore)
    fun reset() {
        _bytesIn.value = 0
        _bytesOut.value = 0
        resetDns()
    }
}
