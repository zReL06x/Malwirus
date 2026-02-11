package com.zrelxr06.malwirus

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.provider.Telephony
import android.net.VpnService
import android.os.Handler
import android.os.Looper
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.SystemClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import com.zrelxr06.malwirus.preference.PreferenceHandler
import com.zrelxr06.malwirus.sms_security.SmsProcessor
import com.zrelxr06.malwirus.sms_security.receiver.SmsReceiver
import android.content.ComponentName
import android.content.pm.PackageManager
import com.zrelxr06.malwirus.web_security.controller.VpnController
import com.zrelxr06.malwirus.web_security.repository.RuleRepository
import com.zrelxr06.malwirus.web_security.model.Counters
import com.zrelxr06.malwirus.notification.MonitoringService
import com.zrelxr06.malwirus.notification.NotificationHandler
import androidx.lifecycle.Observer
import com.zrelxr06.malwirus.device_security.TalsecManager
import com.zrelxr06.malwirus.device_security.TalsecNotifier
import com.zrelxr06.malwirus.device_security.SecurityThreat
import com.zrelxr06.malwirus.device_security.InstallSourceInspector

class MainActivity : FlutterActivity() {
    companion object {
        @Volatile
        var DEBUG_LOGS_ENABLED: Boolean = false
    }
    private val CHANNEL = "malwirus/platform"
    private val TAG = "MainActivity"
    private var smsProcessor: SmsProcessor? = null
    private var smsReceiver: SmsReceiver? = null

    private var pendingNotificationResult: MethodChannel.Result? = null
    private var pendingSmsResult: MethodChannel.Result? = null
    private var pendingPhoneResult: MethodChannel.Result? = null
    private var pendingVpnPrepareResult: MethodChannel.Result? = null
    private var platformChannel: MethodChannel? = null
    private var talsecObserverRegistered: Boolean = false
    private var debugLogsEnabled: Boolean = false // session-only; resets on app restart

    // ---- Local phone normalization helpers (avoid instantiating SmsProcessor) ----
    private fun normalizeToLocalFormat(number: String): String {
        val cleaned = number.replace(Regex("[^0-9+]"), "")
        return when {
            cleaned.startsWith("+63") && cleaned.length >= 13 -> "0" + cleaned.substring(3)
            cleaned.startsWith("63") && cleaned.length >= 12 -> "0" + cleaned.substring(2)
            else -> cleaned
        }
    }

    private fun numbersEqual(a: String, b: String): Boolean {
        val na = normalizeToLocalFormat(a)
        val nb = normalizeToLocalFormat(b)
        if (na == nb) return true
        val minLen = minOf(na.length, nb.length)
        val required = if (minLen >= 11) 11 else if (minLen >= 10) 10 else 9
        return na.takeLast(required) == nb.takeLast(required)
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Initialize VPN counters persistence
        Counters.init(applicationContext)
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        platformChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "setDebugLogsEnabled" -> {
                    debugLogsEnabled = call.argument<Boolean>("enabled") ?: false
                    DEBUG_LOGS_ENABLED = debugLogsEnabled
                    result.success(true)
                }
                "getDebugLogsEnabled" -> {
                    result.success(debugLogsEnabled)
                }
                "simulateSms" -> {
                    try {
                        val sender = call.argument<String>("sender") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        if (sender.isBlank() || body.isBlank()) {
                            result.error("ARG_ERROR", "Missing sender or body", null)
                        } else {
                            if (smsProcessor == null) smsProcessor = SmsProcessor(applicationContext)
                            smsProcessor?.processAsync(sender, body, true)
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "simulateSms error: ${e.message}")
                        result.success(false)
                    }
                }
                "openAndroidSettings" -> {
                    val action = call.argument<String>("intentAction")
                    if (action != null) {
                        val intent = Intent(action)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.error("INVALID_ACTION", "No intent action provided", null)
                    }
                }
                // --- Talsec device security bridge ---
                "talsecObserveThreats" -> {
                    try {
                        if (!talsecObserverRegistered) {
                            TalsecNotifier.threatsLiveData.observe(this, Observer { set ->
                                try {
                                    val list = set.map { it.name }
                                    platformChannel?.invokeMethod("talsecThreatsChanged", list)
                                } catch (e: Exception) {
                                    Log.e(TAG, "Error emitting threats: ${e.message}")
                                }
                            })
                            talsecObserverRegistered = true
                        }
                        // Emit current snapshot immediately
                        val current = TalsecNotifier.current().map { it.name }
                        platformChannel?.invokeMethod("talsecThreatsChanged", current)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("TALSEC_OBSERVE_ERR", e.message, null)
                    }
                }
                "talsecGetThreats" -> {
                    val threats = try { TalsecNotifier.current().map { it.name } } catch (_: Exception) { emptyList<String>() }
                    result.success(threats)
                }
                "talsecClearThreat" -> {
                    val name = call.argument<String>("threat")
                    if (name.isNullOrBlank()) {
                        result.error("ARG_ERROR", "Missing 'threat'", null)
                    } else {
                        try {
                            val threat = SecurityThreat.valueOf(name)
                            TalsecNotifier.clearThreat(threat)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INVALID_THREAT", e.message, null)
                        }
                    }
                }
                "talsecClearAllThreats" -> {
                    try {
                        TalsecNotifier.clearAllThreats()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEAR_ALL_ERR", e.message, null)
                    }
                }
                "talsecRescan" -> {
                    try {
                        TalsecManager.rescan(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("RESCAN_ERR", e.message, null)
                    }
                }
                "talsecGetSuspiciousPackages" -> {
                    try {
                        result.success(TalsecManager.getSuspiciousPackages())
                    } catch (e: Exception) {
                        result.success(emptyList<String>())
                    }
                }
                "talsecClearSuspiciousPackage" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank()) {
                        result.error("ARG_ERROR", "Missing 'packageName'", null)
                    } else {
                        try {
                            TalsecManager.clearSuspiciousPackage(pkg)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("CLEAR_PKG_ERR", e.message, null)
                        }
                    }
                }
                "talsecClearAllSuspiciousPackages" -> {
                    try {
                        TalsecManager.clearAllSuspiciousPackages()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEAR_ALL_PKG_ERR", e.message, null)
                    }
                }
                "talsecSetAllowedInstallerPackages" -> {
                    val stores = call.argument<List<String>>("stores") ?: emptyList()
                    try {
                        TalsecManager.setAllowedInstallerPackages(stores)
                        // Optionally prune again using new rules if desired
                        TalsecManager.pruneAllowedStoreInstalled(applicationContext)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SET_STORES_ERR", e.message, null)
                    }
                }
                "talsecSetScreenCaptureBlocked" -> {
                    val enable = call.argument<Boolean>("enable") ?: false
                    try {
                        TalsecManager.setScreenCaptureBlocked(this, enable)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SCR_CAPTURE_ERR", e.message, null)
                    }
                }
                // --- App installer/source checks ---
                "isInstalledFromPlayStore" -> {
                    try {
                        val installer = try {
                            packageManager.getInstallerPackageName(packageName)
                        } catch (e: Exception) { null }
                        val isPlay = installer == "com.android.vending"
                        result.success(isPlay)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getPackageName" -> {
                    try {
                        result.success(packageName)
                    } catch (e: Exception) {
                        result.error("PKG_ERROR", e.message, null)
                    }
                }
                "isPackageFromPlayStore" -> {
                    try {
                        val target = call.argument<String>("packageName")
                        if (target.isNullOrEmpty()) {
                            result.error("ARG_ERROR", "packageName is required", null)
                        } else {
                            val installer = try {
                                packageManager.getInstallerPackageName(target)
                            } catch (e: Exception) { null }
                            val isPlay = installer == "com.android.vending"
                            result.success(isPlay)
                        }
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                // --- Installer-capable apps + Trusted Installers ---
                "getInstallerCapableApps" -> {
                    try {
                        val appContext = applicationContext
                        Thread {
                            val list = InstallSourceInspector.getInstallerCapableApps(appContext).map {
                                mapOf(
                                    "packageName" to it.packageName,
                                    "appName" to it.appName,
                                    "canRequestInstalls" to it.canRequestInstalls,
                                    "declaresPermission" to it.declaresPermission,
                                    "isSystemApp" to it.isSystemApp
                                )
                            }
                            Handler(Looper.getMainLooper()).post {
                                result.success(list)
                            }
                        }.start()
                    } catch (e: Exception) {
                        result.error("INSTALLERS_ERROR", e.message, null)
                    }
                }
                "getTrustedInstallers" -> {
                    try {
                        val set = InstallSourceInspector.getTrustedInstallers(applicationContext)
                        result.success(set.toList())
                    } catch (e: Exception) {
                        result.success(emptyList<String>())
                    }
                }
                "addTrustedInstaller" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank()) {
                        result.error("ARG_ERROR", "packageName is required", null)
                    } else {
                        val changed = InstallSourceInspector.addTrustedInstaller(applicationContext, pkg)
                        result.success(changed)
                    }
                }
                "removeTrustedInstaller" -> {
                    val pkg = call.argument<String>("packageName")
                    if (pkg.isNullOrBlank()) {
                        result.error("ARG_ERROR", "packageName is required", null)
                    } else {
                        val changed = InstallSourceInspector.removeTrustedInstaller(applicationContext, pkg)
                        result.success(changed)
                    }
                }
                "getInstallerPackage" -> {
                    val target = call.argument<String>("packageName")
                    if (target.isNullOrBlank()) {
                        result.error("ARG_ERROR", "packageName is required", null)
                    } else {
                        val installer = InstallSourceInspector.getInstallerPackage(applicationContext, target)
                        result.success(installer)
                    }
                }
                "getNonPlayUserInstalledApps" -> {
                    try {
                        val appContext = applicationContext
                        Thread {
                            val list = InstallSourceInspector.getNonPlayUserInstalledApps(appContext).map {
                                mapOf(
                                    "packageName" to it.packageName,
                                    "appName" to it.appName,
                                )
                            }
                            Handler(Looper.getMainLooper()).post {
                                result.success(list)
                            }
                        }.start()
                    } catch (e: Exception) {
                        result.error("NON_PLAY_APPS_ERROR", e.message, null)
                    }
                }
                // --- Monitoring foreground service ---
                "monitoringStart" -> {
                    try {
                        val handler = NotificationHandler(this)
                        if (!handler.isMonitoringNotificationActive()) {
                            val i = Intent(this, MonitoringService::class.java)
                            startForegroundService(i)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MON_START_ERR", e.message, null)
                    }
                }
                "monitoringStop" -> {
                    try {
                        val handler = NotificationHandler(this)
                        if (handler.isMonitoringNotificationActive()) {
                            // If running, ask Android to stop the service gracefully
                            stopService(Intent(this, MonitoringService::class.java))
                        } // else no-op to avoid starting a new foreground service just to stop it
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("MON_STOP_ERR", e.message, null)
                    }
                }
                "monitoringIsActive" -> {
                    try {
                        val handler = NotificationHandler(this)
                        result.success(handler.isMonitoringNotificationActive())
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                // --- Web VPN controls ---
                "vpnPrepare" -> {
                    val intent = VpnController.prepare(this)
                    if (intent != null) {
                        pendingVpnPrepareResult = result
                        startActivityForResult(intent, 1201)
                    } else {
                        result.success(true)
                    }
                }
                "vpnIsActive" -> {
                    try {
                        val prefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                        val prefActive = prefs.getBoolean("vpn_active", false)
                        val serviceRunning = com.zrelxr06.malwirus.web_security.service.WebSecurityVpnService.isRunning
                        // Reconcile: if pref says active but service isn't actually running, fix it
                        val active = if (prefActive && !serviceRunning) {
                            prefs.edit().putBoolean("vpn_active", false).apply()
                            false
                        } else if (!prefActive && serviceRunning) {
                            prefs.edit().putBoolean("vpn_active", true).apply()
                            true
                        } else {
                            prefActive
                        }
                        result.success(active)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "vpnStart" -> {
                    VpnController.start(this)
                    result.success(true)
                }
                "vpnStop" -> {
                    VpnController.stop(this)
                    result.success(true)
                }
                "vpnSetBlockedPackages" -> {
                    val pkgs = call.argument<List<String>>("packages") ?: emptyList()
                    val prefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putStringSet("blocked_packages", pkgs.toSet()).apply()
                    // Broadcast update so running service can re-apply
                    val intent = Intent(RuleRepository.ACTION_RULES_CHANGED).apply {
                        putExtra(RuleRepository.EXTRA_BLOCKED_PACKAGES, pkgs.toTypedArray())
                    }
                    sendBroadcast(intent)
                    result.success(true)
                }
                "vpnSetDnsBlocklist" -> {
                    val domains = call.argument<List<String>>("domains")?.map { it.lowercase() } ?: emptyList()
                    val prefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putStringSet("dns_blocklist", domains.toSet()).apply()
                    val intent = Intent(RuleRepository.ACTION_DNS_CHANGED).apply {
                        putExtra(RuleRepository.EXTRA_DNS_BLOCKLIST, domains.toTypedArray())
                    }
                    sendBroadcast(intent)
                    result.success(true)
                }
                "vpnSetUniversalDnsEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    val prefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("dns_universal_enabled", enabled).apply()
                    // Notify running VPN to re-read prefs
                    val intent = Intent(RuleRepository.ACTION_DNS_CHANGED)
                    sendBroadcast(intent)
                    result.success(true)
                }
                "vpnGetUniversalDnsEnabled" -> {
                    val prefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                    val enabled = prefs.getBoolean("dns_universal_enabled", true)
                    result.success(enabled)
                }

                // --- Pre-listed (Bloom) controls ---
                "vpnSetPrelistedEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    val prefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("prelisted_enabled", enabled).apply()
                    // Notify running VPN (receiver will toggle and apply updates)
                    val intent = Intent(com.zrelxr06.malwirus.web_security.repository.RuleRepository.ACTION_DNS_CHANGED)
                    sendBroadcast(intent)
                    result.success(true)
                }
                "vpnGetPrelistedInfo" -> {
                    val prefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
                    val enabled = prefs.getBoolean("prelisted_enabled", true)
                    val count = prefs.getInt("prelisted_count", 0)
                    val map = mapOf("enabled" to enabled, "count" to count)
                    result.success(map)
                }

                // --- Web VPN counters ---
                "vpnGetCounters" -> {
                    try {
                        val map = mapOf(
                            "bytesIn" to Counters.bytesIn.value,
                            "bytesOut" to Counters.bytesOut.value,
                            "dnsQueries" to Counters.dnsQueries.value,
                            "dnsBlocked" to Counters.dnsBlocked.value
                        )
                        result.success(map)
                    } catch (e: Exception) {
                        result.error("COUNTERS_ERROR", e.message, null)
                    }
                }
                "vpnResetCounters" -> {
                    try {
                        Counters.reset()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "vpnResetDnsCounters" -> {
                    try {
                        Counters.resetDns()
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getInstalledApps" -> {
                    try {
                        // Optional filter: "all" (default), "user", or "system"
                        val type = call.argument<String>("type") ?: "all"
                        val appContext = applicationContext
                        Thread {
                            try {
                                val pm = appContext.packageManager
                                val installed = pm.getInstalledApplications(PackageManager.GET_META_DATA)
                                val list = ArrayList<Map<String, String>>(installed.size)

                                for (app in installed) {
                                    // Skip our own app only
                                    if (app.packageName == packageName) continue

                                    val isSystemApp = (app.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
                                    val isUpdatedSystemApp = (app.flags and android.content.pm.ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
                                    val appType = when {
                                        !isSystemApp -> "user"
                                        isUpdatedSystemApp -> "user" // Treat updated system apps as user apps
                                        else -> "system"
                                    }

                                    // Filter early to reduce work
                                    if (type == "user" && appType != "user") continue
                                    if (type == "system" && appType != "system") continue

                                    // Prefer nonLocalizedLabel to avoid AssetManager churn; fallback to label
                                    val label = app.nonLocalizedLabel?.toString()
                                        ?: try { pm.getApplicationLabel(app).toString() } catch (_: Exception) { app.packageName }

                                    list.add(mapOf(
                                        "packageName" to app.packageName,
                                        "appName" to label,
                                        "appType" to appType
                                    ))
                                }

                                // Sort by app name
                                list.sortBy { it["appName"] }

                                Handler(Looper.getMainLooper()).post {
                                    result.success(list)
                                }
                            } catch (e: Exception) {
                                Handler(Looper.getMainLooper()).post {
                                    result.error("GET_APPS_ERROR", e.message, null)
                                }
                            }
                        }.start()
                    } catch (e: Exception) {
                        result.error("GET_APPS_ERROR", e.message, null)
                    }
                }

                "openAppInfo" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val intent =
                            Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        intent.data = android.net.Uri.parse("package:$packageName")
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.error("INVALID_PACKAGE", "No package name provided", null)
                    }
                }

                "getMessagesScanned" -> {
                    val prefs = getSharedPreferences("sms_security_stats", Context.MODE_PRIVATE)
                    val count = prefs.getInt("messages_scanned", 0)
                    result.success(count)
                }

                "getSuspiciousLinksFound" -> {
                    val prefs = getSharedPreferences("sms_security_stats", Context.MODE_PRIVATE)
                    val count = prefs.getInt("suspicious_links_found", 0)
                    result.success(count)
                }

                "setLinkScanningEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setLinkScanningEnabled(enabled)
                    result.success(null)
                }

                "setSmsScanningEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setSmsScanningEnabled(enabled)
                    result.success(null)
                }

                "getWhitelist" -> {
                    try {
                        val prefs = getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
                        val json = prefs.getString("sms_whitelist", "[]")
                        val gson = com.google.gson.Gson()
                        val arr = try { gson.fromJson(json, Array<com.zrelxr06.malwirus.sms_security.WhitelistedNumber>::class.java) } catch (e: Exception) { null }
                        val list = arr?.map { it.number } ?: emptyList()
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<String>())
                    }
                }

                "addToWhitelist" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        try {
                            val prefs = getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
                            val gson = com.google.gson.Gson()
                            val current = prefs.getString("sms_whitelist", "[]")
                            val arr = try { gson.fromJson(current, Array<com.zrelxr06.malwirus.sms_security.WhitelistedNumber>::class.java) } catch (e: Exception) { null }
                            val list = arr?.toMutableList() ?: mutableListOf()
                            val target = normalizeToLocalFormat(number)
                            if (!list.any { normalizeToLocalFormat(it.number) == target }) {
                                list.add(com.zrelxr06.malwirus.sms_security.WhitelistedNumber(target))
                                prefs.edit().putString("sms_whitelist", gson.toJson(list)).apply()
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }

                "removeFromWhitelist" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        try {
                            val prefs = getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
                            val gson = com.google.gson.Gson()
                            val current = prefs.getString("sms_whitelist", "[]")
                            val arr = try { gson.fromJson(current, Array<com.zrelxr06.malwirus.sms_security.WhitelistedNumber>::class.java) } catch (e: Exception) { null }
                            val target = normalizeToLocalFormat(number)
                            val list = (arr?.toMutableList() ?: mutableListOf()).apply {
                                removeIf { normalizeToLocalFormat(it.number) == target }
                            }
                            prefs.edit().putString("sms_whitelist", gson.toJson(list)).apply()
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(false)
                    }
                }

                // --- Blocklist (Calls) management ---
                "getBlocklist" -> {
                    try {
                        val pref = PreferenceHandler(this)
                        val json = pref.getString("call_blocklist", "[]")
                        val gson = com.google.gson.Gson()
                        val list: List<String> = try {
                            val arr = gson.fromJson(json, Array<String>::class.java)
                            arr?.toList() ?: emptyList()
                        } catch (e: Exception) { emptyList() }
                        result.success(list)
                    } catch (e: Exception) {
                        result.success(emptyList<String>())
                    }
                }
                "addToBlocklist" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        val pref = PreferenceHandler(this)
                        val gson = com.google.gson.Gson()
                        val currentJson = pref.getString("call_blocklist", "[]")
                        val list: MutableList<String> = try {
                            val arr = gson.fromJson(currentJson, Array<String>::class.java)
                            arr?.toMutableList() ?: mutableListOf()
                        } catch (e: Exception) { mutableListOf() }
                        val target = normalizeToLocalFormat(number)
                        if (!list.any { it == target }) {
                            list.add(target)
                            pref.saveString("call_blocklist", gson.toJson(list))
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "removeFromBlocklist" -> {
                    val number = call.argument<String>("number")
                    if (number != null) {
                        val pref = PreferenceHandler(this)
                        val gson = com.google.gson.Gson()
                        val currentJson = pref.getString("call_blocklist", "[]")
                        val list: MutableList<String> = try {
                            val arr = gson.fromJson(currentJson, Array<String>::class.java)
                            arr?.toMutableList() ?: mutableListOf()
                        } catch (e: Exception) { mutableListOf() }
                        val target = normalizeToLocalFormat(number)
                        val updated = list.filter { it != target }
                        pref.saveString("call_blocklist", gson.toJson(updated))
                        // Also remove any stored reason for this number
                        try {
                            val reasonsJson = pref.getString("call_blocklist_reasons", "{}")
                            val map: MutableMap<String, String> = try {
                                val obj = gson.fromJson(reasonsJson, com.google.gson.JsonObject::class.java)
                                val m = mutableMapOf<String, String>()
                                if (obj != null) {
                                    for ((k, v) in obj.entrySet()) {
                                        m[k] = v.asString
                                    }
                                }
                                m
                            } catch (e: Exception) { mutableMapOf() }
                            if (map.remove(target) != null) {
                                pref.saveString("call_blocklist_reasons", gson.toJson(map))
                            }
                        } catch (_: Exception) {}
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                // --- Auto-block spam senders preference ---
                "getAutoBlockSpamSendersEnabled" -> {
                    try {
                        val pref = PreferenceHandler(this)
                        val enabled = pref.getBoolean("auto_block_spam_senders", true)
                        result.success(enabled)
                    } catch (e: Exception) {
                        result.success(true)
                    }
                }
                "setAutoBlockSpamSendersEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    try {
                        val pref = PreferenceHandler(this)
                        pref.setBoolean("auto_block_spam_senders", enabled)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                // --- Blocklist reasons map ---
                "getBlocklistReasons" -> {
                    try {
                        val pref = PreferenceHandler(this)
                        val json = pref.getString("call_blocklist_reasons", "{}")
                        val gson = com.google.gson.Gson()
                        val map: Map<String, String> = try {
                            val obj = gson.fromJson(json, com.google.gson.JsonObject::class.java)
                            val m = mutableMapOf<String, String>()
                            if (obj != null) {
                                for ((k, v) in obj.entrySet()) {
                                    m[k] = v.asString
                                }
                            }
                            m
                        } catch (e: Exception) { emptyMap() }
                        result.success(map)
                    } catch (e: Exception) {
                        result.success(emptyMap<String, String>())
                    }
                }

                "isNotificationPermissionGranted" -> {
                    val granted = if (android.os.Build.VERSION.SDK_INT >= 33) {
                        androidx.core.app.ActivityCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.POST_NOTIFICATIONS
                        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    } else {
                        true // Always granted on Android < 13
                    }
                    result.success(granted)
                }
                "requestNotificationPermission" -> {
                    if (android.os.Build.VERSION.SDK_INT >= 33) {
                        pendingNotificationResult = result
                        androidx.core.app.ActivityCompat.requestPermissions(
                            this,
                            arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                            1001
                        )
                    } else {
                        result.success(true)
                    }
                }
                "isSmsPermissionGranted" -> {
                    val granted = androidx.core.app.ActivityCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.RECEIVE_SMS
                    ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> {
                    pendingSmsResult = result
                    androidx.core.app.ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            android.Manifest.permission.RECEIVE_SMS,
                            android.Manifest.permission.READ_SMS
                        ),
                        1002
                    )
                }
                "isPhonePermissionGranted" -> {
                    val granted =
                        androidx.core.app.ActivityCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.READ_PHONE_STATE
                        ) == android.content.pm.PackageManager.PERMISSION_GRANTED &&
                        androidx.core.app.ActivityCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.READ_PHONE_NUMBERS
                        ) == android.content.pm.PackageManager.PERMISSION_GRANTED &&
                        androidx.core.app.ActivityCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.READ_CALL_LOG
                        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestPhonePermission" -> {
                    pendingPhoneResult = result
                    androidx.core.app.ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            android.Manifest.permission.READ_PHONE_STATE,
                            android.Manifest.permission.READ_PHONE_NUMBERS,
                            android.Manifest.permission.READ_CALL_LOG
                        ),
                        1003
                    )
                }
                "getSmsHistory" -> {
                    try {
                        val historyManager = com.zrelxr06.malwirus.history.HistoryManager(this)
                        val history = historyManager.getHistory()
                        val gson = com.google.gson.Gson()
                        val json = gson.toJson(history)
                        result.success(json)
                    } catch (e: Exception) {
                        result.error("HISTORY_ERROR", e.message, null)
                    }
                }
                "clearSmsHistory" -> {
                    try {
                        val historyManager = com.zrelxr06.malwirus.history.HistoryManager(this)
                        historyManager.clearHistory()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("CLEAR_HISTORY_ERROR", e.message, null)
                    }
                }
                // --- App lifecycle controls ---
                "hardRestartApp" -> {
                    try {
                        Log.i(TAG, "[hardRestartApp] Requested from Dart. Scheduling cold restart…")
                        // Schedule a cold relaunch and terminate this process
                        scheduleColdRestart()
                        Log.i(TAG, "[hardRestartApp] scheduleColdRestart() called")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "[hardRestartApp] Error: ${e.message}")
                        result.error("RESTART_ERROR", e.message, null)
                    }
                }
                "killAppNoRelaunch" -> {
                    try {
                        Log.w(TAG, "[killAppNoRelaunch] Finishing and killing process without relaunch…")
                        // Finish the activity and kill without scheduling a relaunch.
                        // This is used for manual rescan flow: user will relaunch via app icon.
                        finishAndRemoveTask()
                        Handler(Looper.getMainLooper()).postDelayed({
                            Log.w(TAG, "[killAppNoRelaunch] Killing PID…")
                            android.os.Process.killProcess(android.os.Process.myPid())
                            System.exit(0)
                        }, 120)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "[killAppNoRelaunch] Error: ${e.message}")
                        result.error("KILL_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1201) {
            val res = pendingVpnPrepareResult
            pendingVpnPrepareResult = null
            res?.success(true)
        }
    }

    // Removed hardcoded cold start enforcement in onNewIntent. Use the
    // explicit 'hardRestartApp' method when a true cold restart is desired.

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        try {
            // If user taps launcher icon while the activity already exists (singleTop),
            // enforce a cold restart so native protections (e.g., Talsec) re-initialize cleanly.
            if (Intent.ACTION_MAIN == intent.action && intent.hasCategory(Intent.CATEGORY_LAUNCHER)) {
                scheduleColdRestart()
            }
        } catch (e: Exception) {
            Log.e(TAG, "onNewIntent restart error: ${e.message}")
        }
    }

    override fun onDestroy() {
        try {
            if (talsecObserverRegistered) {
                TalsecNotifier.threatsLiveData.removeObservers(this)
                talsecObserverRegistered = false
            }
        } catch (e: Exception) {
            Log.w(TAG, "onDestroy: failed removing observers: ${e.message}")
        }
        super.onDestroy()
    }

    // Invoked by AlarmManager to safely relaunch the app after a cold kill.
    class RestartReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent?) {
            val tag = "RestartReceiver"
            try {
                Log.i(tag, "[onReceive] Received alarm. Starting MainActivity…")
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?: Intent(context, MainActivity::class.java)
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
                context.startActivity(launch)
            } catch (e: Exception) {
                Log.e(tag, "[onReceive] Failed to relaunch: ${e.message}")
            }
        }
    }

    private fun setLinkScanningEnabled(enabled: Boolean) {
        try {
            val appPrefs = applicationContext.getSharedPreferences("app_preferences", MODE_PRIVATE)
            val smsPrefs = applicationContext.getSharedPreferences("sms_security_prefs", MODE_PRIVATE)
            appPrefs.edit().putBoolean("link_scanning_enabled", enabled).apply()
            smsPrefs.edit().putBoolean("link_scanning_enabled", enabled).apply()
            Log.d(TAG, "Link scanning ${if (enabled) "enabled" else "disabled"} in all preference stores")
        } catch (e: Exception) {
            Log.e(TAG, "Error setting link scanning state: ${e.message}")
        }
    }

    private fun setSmsScanningEnabled(enabled: Boolean) {
        val prefs = applicationContext.getSharedPreferences("sms_security_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("sms_scanning_enabled", enabled).apply()
        setSmsReceiverEnabled(enabled)
        if (enabled) {
            startSmsScanning()
        } else {
            stopSmsScanning()
        }
    }

    private fun setSmsReceiverEnabled(enabled: Boolean) {
        val component = ComponentName(this, SmsReceiver::class.java)
        packageManager.setComponentEnabledSetting(
            component,
            if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun startSmsScanning(): Boolean {
        if (!checkSmsPermission()) {
            Log.e(TAG, "SMS permission not granted")
            return false
        }
        if (smsReceiver == null) {
            smsReceiver = SmsReceiver()
            val intentFilter = IntentFilter(Telephony.Sms.Intents.SMS_RECEIVED_ACTION)
            registerReceiver(smsReceiver, intentFilter)
            Log.d(TAG, "SMS receiver registered")
        }
        return true
    }

    private fun stopSmsScanning() {
        if (smsReceiver != null) {
            try {
                unregisterReceiver(smsReceiver)
                smsReceiver = null
                Log.d(TAG, "SMS receiver unregistered")
            } catch (e: Exception) {
                Log.e(TAG, "Error unregistering SMS receiver: ${e.message}")
            }
        }
    }

    private fun checkSmsPermission(): Boolean {
        // Implement permission check logic
        return true
    }

    /**
     * Schedules a cold relaunch of the app shortly and terminates the current process.
     * This uses AlarmManager + PendingIntent to avoid background launch restrictions.
     */
    private fun scheduleColdRestart(delayMs: Long = 800L) {
        try {
            val ctx = applicationContext
            Log.i(TAG, "[scheduleColdRestart] Preparing broadcast PendingIntent with delay=${delayMs}ms")

            val restartIntent = Intent(ctx, RestartReceiver::class.java)
            val flags = PendingIntent.FLAG_CANCEL_CURRENT or PendingIntent.FLAG_IMMUTABLE
            val pendingIntent = PendingIntent.getBroadcast(
                ctx,
                100,
                restartIntent,
                flags
            )

            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = SystemClock.elapsedRealtime() + delayMs
            am.setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAt, pendingIntent)
            Log.i(TAG, "[scheduleColdRestart] Alarm scheduled (ELAPSED_REALTIME_WAKEUP) at +${delayMs}ms -> RestartReceiver")

            // Finish and kill current process
            finishAndRemoveTask()
            Handler(Looper.getMainLooper()).postDelayed({
                Log.i(TAG, "[scheduleColdRestart] Killing current process now…")
                android.os.Process.killProcess(android.os.Process.myPid())
                System.exit(0)
            }, 250)
        } catch (e: Exception) {
            Log.e(TAG, "scheduleColdRestart error: ${e.message}")
            throw e
        }
    }
}