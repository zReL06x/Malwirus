package com.zrelxr06.malwirus.web_security.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.zrelxr06.malwirus.web_security.controller.VpnController
import com.zrelxr06.malwirus.web_security.dns.DnsFilter
import com.zrelxr06.malwirus.web_security.repository.RuleRepository

/**
 * Receives broadcasts when rules or DNS list change and applies updates immediately.
 */
class RulesUpdateReceiver : BroadcastReceiver() {
    private val TAG = "RulesUpdateReceiver"
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received action: ${intent.action}")
        when (intent.action) {
            RuleRepository.ACTION_RULES_CHANGED -> {
                val pkgs = intent.getStringArrayExtra(RuleRepository.EXTRA_BLOCKED_PACKAGES)
                Log.i(TAG, "Rules changed; packages=${pkgs?.size ?: 0}. Applying updates")
                VpnController.applyUpdates(context)
            }
            RuleRepository.ACTION_DNS_CHANGED -> {
                val domains = intent.getStringArrayExtra(RuleRepository.EXTRA_DNS_BLOCKLIST)?.toSet() ?: emptySet()
                if (domains.isNotEmpty()) {
                    Log.i(TAG, "DNS list changed; domains=${domains.size}")
                    DnsFilter.set(domains)
                }
                // Refresh universal DNS enabled flag from prefs regardless of domains extra
                val prefs = context.getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                val enabled = prefs.getBoolean("dns_universal_enabled", true)
                DnsFilter.setEnabled(enabled)
                // Apply pre-listed Bloom enabled toggle
                val prelistedEnabled = prefs.getBoolean("prelisted_enabled", true)
                DnsFilter.setPrelistedEnabled(prelistedEnabled)
                VpnController.applyUpdates(context)
            }
        }
    }
}
