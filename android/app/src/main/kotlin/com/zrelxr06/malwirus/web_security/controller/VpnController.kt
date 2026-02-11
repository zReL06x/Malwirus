package com.zrelxr06.malwirus.web_security.controller

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.util.Log
import com.zrelxr06.malwirus.web_security.service.WebSecurityVpnService

/**
 * Simple helper to start/stop and apply updates to the VPN service.
 */
object VpnController {
    private const val TAG = "VpnController"
    fun prepare(context: Context): Intent? = VpnService.prepare(context)

    fun start(context: Context) {
        try {
            val i = Intent(context, WebSecurityVpnService::class.java)
            // Use startService instead of startForegroundService because the service does not
            // post a foreground notification. Using startForegroundService would require
            // Service.startForeground() within 5s, causing a crash when stopping or updating.
            context.startService(i)
            // Mark VPN as active
            try {
                val prefs = context.getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("vpn_active", true).apply()
            } catch (_: Exception) {}
            Log.i(TAG, "Requested start of WebSecurityVpnService")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start service: ${e.message}", e)
        }
    }

    fun stop(context: Context) {
        try {
            val i = Intent(context, WebSecurityVpnService::class.java).apply {
                action = WebSecurityVpnService.ACTION_STOP
            }
            // Use startService for stop action; foreground start would require a notification
            // and calling startForeground(), which we intentionally avoid.
            context.startService(i)
            // Mark VPN as inactive
            try {
                val prefs = context.getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                prefs.edit().putBoolean("vpn_active", false).apply()
            } catch (_: Exception) {}
            Log.i(TAG, "Requested stop of WebSecurityVpnService (ACTION_STOP)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop service: ${e.message}", e)
        }
    }

    fun applyUpdates(context: Context) {
        try {
            val i = Intent(context, WebSecurityVpnService::class.java).apply {
                action = WebSecurityVpnService.ACTION_APPLY_UPDATES
                component = ComponentName(context, WebSecurityVpnService::class.java)
            }
            // Use startService to deliver update action without foreground requirement
            context.startService(i)
            Log.d(TAG, "Requested apply updates")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to apply updates: ${e.message}", e)
        }
    }
}
