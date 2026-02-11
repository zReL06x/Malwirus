package com.zrelxr06.malwirus.device_security

import android.app.Activity
import android.content.Context
import android.util.Log
import com.aheaditec.talsec_security.security.api.Talsec
import com.aheaditec.talsec_security.security.api.TalsecConfig
import com.aheaditec.talsec_security.security.api.ThreatListener
import android.os.Build
import com.zrelxr06.malwirus.device_security.TalsecNotifier
import com.zrelxr06.malwirus.MainActivity

/**
 * Simple wrapper around Talsec freeRASP controls to help manage lifecycle from other layers
 * (e.g., Flutter Android module). Note: the SDK does not currently expose a public stop API.
 * We provide best-effort stop by unregistering listeners. Rescan is simulated by re-registering
 * listeners and optionally re-invoking start with the same config.
 */
object TalsecManager {

    private var threatListener: ThreatListener? = null
    private var lastConfig: TalsecConfig? = null

    // Suspicious packages (by package name) reported by freeRASP malware detection.
    // This set can be fetched from Flutter later via a platform channel.
    private val suspiciousPackages = LinkedHashSet<String>()
    private val lock = Any()

    // Allowed installer packages (stores). Defaults to Google Play. Extend as needed.
    // Example for Samsung: "com.sec.android.app.samsungapps"
    private val allowedInstallerPackages = mutableSetOf("com.android.vending")

    // Local log helpers gated by session-scoped debug flag
    private inline fun logD(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.d(TAG, msg) }
    private inline fun logI(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.i(TAG, msg) }
    private inline fun logW(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.w(TAG, msg) }

    /** Start the SDK. Idempotent if called with the same config. */
    fun start(context: Context, config: TalsecConfig) {
        logI("TalsecManager.start - starting SDK")
        lastConfig = config
        Talsec.start(context, config)
    }

    /** Register your threat listeners. Safe to call multiple times; it will replace the existing listener. */
    fun registerListeners(
        context: Context,
        threats: ThreatListener.ThreatDetected,
        deviceState: ThreatListener.DeviceState? = null
    ) {
        // Unregister old one if exists
        logI("TalsecManager.registerListeners - replacing existing listener=${threatListener != null}")
        threatListener?.unregisterListener(context)
        val listener = ThreatListener(threats, deviceState)
        listener.registerListener(context)
        threatListener = listener
    }

    /** Best-effort stop: unregister listeners. There is no public Talsec.stop(). */
    fun stop(context: Context) {
        logI("TalsecManager.stop - unregistering listeners")
        threatListener?.unregisterListener(context)
        threatListener = null
        // No public API to fully stop the SDK runtime at the moment
    }

    /**
     * Rescan: clear application-side state first, then re-register listeners and re-invoke start
     * with the last known config. This mirrors a fresh initialization without process restart.
     */
    fun rescan(context: Context) {
        logI("TalsecManager.rescan - clearing state, re-invoking start, and re-registering listeners if available")
        // 1) Clear app-side state before rescanning
        try {
            TalsecNotifier.clearAllThreats()
            logD("Rescan: cleared threats")
        } catch (e: Exception) {
            logW("Rescan: failed to clear threats: ${e.message}")
        }
        clearAllSuspiciousPackages()
        logD("Rescan: cleared suspicious packages")

        // 2) Reapply start if we have a config
        lastConfig?.let { cfg ->
            logD("Rescan: calling Talsec.start with lastConfig")
            Talsec.start(context, cfg)
        }
        // 3) Re-register listener if present
        threatListener?.let { listener ->
            logD("Rescan: re-registering existing listener")
            listener.unregisterListener(context)
            listener.registerListener(context)
        }
    }

    /** Convenience to block/unblock screen capture for the given activity. */
    fun setScreenCaptureBlocked(activity: Activity, enable: Boolean) {
        logI("TalsecManager.setScreenCaptureBlocked enable=$enable activity=${activity.localClassName}")
        Talsec.blockScreenCapture(activity, enable)
    }

    // -------------------------------
    // Suspicious packages data store
    // -------------------------------

    /** Configure allowed installer packages (stores) used to guard the suspicious list. */
    fun setAllowedInstallerPackages(stores: Collection<String>) {
        synchronized(lock) {
            allowedInstallerPackages.clear()
            allowedInstallerPackages.addAll(stores)
        }
    }

    /** Add suspicious package names and immediately prune the ones installed from allowed stores. */
    fun addSuspiciousPackagesByName(context: Context, packages: Collection<String>) {
        if (packages.isEmpty()) return
        synchronized(lock) {
            suspiciousPackages.addAll(packages)
        }
        // Prune entries that are installed from allowed stores
        pruneAllowedStoreInstalled(context)
    }

    /** Get a snapshot of the current suspicious package names. */
    fun getSuspiciousPackages(): List<String> = synchronized(lock) { suspiciousPackages.toList() }

    /** Remove a single package from the list. */
    fun clearSuspiciousPackage(packageName: String) {
        synchronized(lock) { suspiciousPackages.remove(packageName) }
    }

    /** Clear the entire suspicious package list. */
    fun clearAllSuspiciousPackages() {
        synchronized(lock) { suspiciousPackages.clear() }
    }

    /** Remove any entries whose installer is one of the allowed stores. Returns number removed. */
    fun pruneAllowedStoreInstalled(context: Context): Int {
        val toRemove = mutableListOf<String>()
        val pm = context.packageManager
        synchronized(lock) {
            for (pkg in suspiciousPackages) {
                try {
                    val installer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        // API 30+: more reliable source info
                        val src = pm.getInstallSourceInfo(pkg)
                        src.installingPackageName ?: src.initiatingPackageName
                        ?: src.originatingPackageName
                    } else {
                        @Suppress("DEPRECATION")
                        pm.getInstallerPackageName(pkg)
                    }
                    if (installer != null && allowedInstallerPackages.contains(installer)) {
                        toRemove.add(pkg)
                    }
                } catch (e: Exception) {
                    // Package may not be installed anymore or visibility filtered; ignore
                    logD("pruneAllowedStoreInstalled: skip $pkg, reason=${e.javaClass.simpleName}")
                }
            }
            if (toRemove.isNotEmpty()) {
                suspiciousPackages.removeAll(toRemove)
            }
        }
        if (toRemove.isNotEmpty()) {
            logI("Pruned ${toRemove.size} suspicious entries installed via allowed stores: $toRemove")
        }
        return toRemove.size
    }

    private const val TAG = "TalsecManager"
}