package com.zrelxr06.malwirus.web_security.repository

import android.content.Context
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Holds per-app blocking rules and DNS blocklist with live updates via StateFlow.
 * Broadcast intents can be used to trigger immediate application in a running VPN.
 */
class RuleRepository(private val appContext: Context) {
    private val TAG = "RuleRepository"
    companion object Actions {
        const val ACTION_RULES_CHANGED = "com.zrelxr06.malwirus.web.ACTION_RULES_CHANGED"
        const val EXTRA_BLOCKED_PACKAGES = "blocked_packages" // String[]
        const val ACTION_DNS_CHANGED = "com.zrelxr06.malwirus.web.ACTION_DNS_CHANGED"
        const val EXTRA_DNS_BLOCKLIST = "dns_blocklist" // String[] domains
    }

    private val _blockedPackages = MutableStateFlow<Set<String>>(emptySet())
    private val _dnsBlocklist = MutableStateFlow<Set<String>>(emptySet())

    val blockedPackages: StateFlow<Set<String>> = _blockedPackages.asStateFlow()
    val dnsBlocklist: StateFlow<Set<String>> = _dnsBlocklist.asStateFlow()

    fun setBlockedPackages(packages: Set<String>, notify: Boolean = true) {
        _blockedPackages.value = packages
        Log.i(TAG, "Blocked packages updated: ${packages.size}")
        if (notify) broadcastRulesChanged(packages)
    }

    fun addBlockedPackage(pkg: String, notify: Boolean = true) {
        setBlockedPackages(_blockedPackages.value + pkg, notify)
    }

    fun removeBlockedPackage(pkg: String, notify: Boolean = true) {
        setBlockedPackages(_blockedPackages.value - pkg, notify)
    }

    fun setDnsBlocklist(domains: Set<String>, notify: Boolean = true) {
        _dnsBlocklist.value = domains
        Log.i(TAG, "DNS blocklist updated: ${domains.size}")
        if (notify) broadcastDnsChanged(domains)
    }

    fun addDnsDomain(domain: String, notify: Boolean = true) {
        setDnsBlocklist(_dnsBlocklist.value + domain.lowercase(), notify)
    }

    fun removeDnsDomain(domain: String, notify: Boolean = true) {
        setDnsBlocklist(_dnsBlocklist.value - domain.lowercase(), notify)
    }

    private fun broadcastRulesChanged(packages: Set<String>) {
        val intent = Intent(ACTION_RULES_CHANGED).apply {
            putExtra(EXTRA_BLOCKED_PACKAGES, packages.toTypedArray())
        }
        appContext.sendBroadcast(intent)
        Log.d(TAG, "Broadcasted ACTION_RULES_CHANGED for ${packages.size} packages")
    }

    private fun broadcastDnsChanged(domains: Set<String>) {
        val intent = Intent(ACTION_DNS_CHANGED).apply {
            putExtra(EXTRA_DNS_BLOCKLIST, domains.toTypedArray())
        }
        appContext.sendBroadcast(intent)
        Log.d(TAG, "Broadcasted ACTION_DNS_CHANGED for ${domains.size} domains")
    }
}
