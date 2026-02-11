package com.zrelxr06.malwirus.device_security

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.zrelxr06.malwirus.MainActivity
import org.json.JSONArray

/**
 * Inspect apps capable of installing APKs and maintain a trusted installers whitelist.
 *
 * Capabilities are detected via:
 * - Declared permission REQUEST_INSTALL_PACKAGES
 * - PackageManager.canRequestPackageInstalls() (Android 8+)
 */
object InstallSourceInspector {

    private const val TAG = "InstallSourceInspector"

    // Local log helpers gated by session-scoped debug flag
    private inline fun logD(msg: String) {
        if (MainActivity.DEBUG_LOGS_ENABLED) Log.d(TAG, msg)
    }

    private inline fun logI(msg: String) {
        if (MainActivity.DEBUG_LOGS_ENABLED) Log.i(TAG, msg)
    }

    private inline fun logW(msg: String) {
        if (MainActivity.DEBUG_LOGS_ENABLED) Log.w(TAG, msg)
    }

    private const val PREFS = "app_preferences"
    private const val KEY_TRUSTED_INSTALLERS = "trusted_installers"

    /** Data holder for installer-capable app information. */
    data class InstallerCapableApp(
        val packageName: String,
        val appName: String,
        val canRequestInstalls: Boolean,
        val declaresPermission: Boolean,
        val isSystemApp: Boolean
    )

    /** Simple data holder for generic app listing */
    data class SimpleApp(
        val packageName: String,
        val appName: String,
    )

    /** Returns the list of apps that can install APKs (potential installers). */
    fun getInstallerCapableApps(context: Context): List<InstallerCapableApp> {
        val pm = context.packageManager
        val apps = try {
            pm.getInstalledApplications(PackageManager.GET_META_DATA)
        } catch (e: Exception) {
            logW("getInstalledApplications failed: ${e.message}")
            emptyList<ApplicationInfo>()
        }

        logI("Scanning ${apps.size} installed apps for installer-capable candidates...")

        // 1) Collect packages that explicitly declare REQUEST_INSTALL_PACKAGES
        val candidatesByPermission = HashSet<String>()
        for (app in apps) {
            if (app.packageName == context.packageName) continue
            if (declaresInstallPermission(pm, app.packageName)) {
                candidatesByPermission.add(app.packageName)
            }
        }
        logD("Candidates by permission = ${candidatesByPermission.size}: ${candidatesByPermission}")

        // 2) Collect observed installer packages from existing apps' installer source info
        val observedInstallers = HashSet<String>()
        for (app in apps) {
            val pkg = app.packageName
            // Skip our own package
            if (pkg == context.packageName) continue
            val installer = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val src = pm.getInstallSourceInfo(pkg)
                    src.installingPackageName ?: src.initiatingPackageName
                    ?: src.originatingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(pkg)
                }
            } catch (_: Exception) {
                null
            }
            if (!installer.isNullOrBlank()) {
                observedInstallers.add(installer)
            }
        }
        logD("Observed installers = ${observedInstallers.size}: ${observedInstallers}")

        // Union of both sets -> unique installer-capable or observed installer apps
        val union = HashSet<String>(candidatesByPermission)
        union.addAll(observedInstallers)
        logI("Union of installer-capable + observed installers = ${union.size}")

        // 3) Build InstallerCapableApp list with labels
        val result = ArrayList<InstallerCapableApp>(union.size)
        for (pkg in union) {
            try {
                val ai = pm.getApplicationInfo(pkg, 0)
                val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
                val label = ai.nonLocalizedLabel?.toString() ?: try {
                    pm.getApplicationLabel(ai).toString()
                } catch (_: Exception) {
                    pkg
                }
                val declares = candidatesByPermission.contains(pkg)
                // We cannot know per-package canRequestPackageInstalls(); keep false here
                result.add(
                    InstallerCapableApp(
                        packageName = pkg,
                        appName = label,
                        canRequestInstalls = false,
                        declaresPermission = declares,
                        isSystemApp = isSystem
                    )
                )
            } catch (_: Exception) {
                // Package visibility might hide some. Best-effort: still add by pkg name.
                result.add(
                    InstallerCapableApp(
                        packageName = pkg,
                        appName = pkg,
                        canRequestInstalls = false,
                        declaresPermission = candidatesByPermission.contains(pkg),
                        isSystemApp = false
                    )
                )
            }
        }

        // Sort by app name for stable UI
        result.sortBy { it.appName.lowercase() }
        logI("Returning ${result.size} installer-capable entries")
        return result
    }

    /**
     * Returns all user-installed apps that are NOT installed via Google Play Store.
     * - Excludes system apps.
     */
    fun getNonPlayUserInstalledApps(context: Context): List<SimpleApp> {
        val pm = context.packageManager
        val apps = try {
            pm.getInstalledApplications(PackageManager.GET_META_DATA)
        } catch (e: Exception) {
            Log.w(TAG, "getInstalledApplications failed: ${e.message}")
            emptyList<ApplicationInfo>()
        }
        val out = ArrayList<SimpleApp>()
        for (ai in apps) {
            val isSystem = (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            if (isSystem) continue
            if (ai.packageName == context.packageName) continue
            val installer = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val src = pm.getInstallSourceInfo(ai.packageName)
                    src.installingPackageName ?: src.initiatingPackageName
                    ?: src.originatingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(ai.packageName)
                }
            } catch (_: Exception) {
                null
            }
            // Ignore Google Play Store installs
            if (installer == "com.android.vending") continue
            val label = ai.nonLocalizedLabel?.toString() ?: run {
                try {
                    pm.getApplicationLabel(ai).toString()
                } catch (_: Exception) {
                    ai.packageName
                }
            }
            out.add(SimpleApp(packageName = ai.packageName, appName = label))
        }
        logI("getNonPlayUserInstalledApps => ${out.size} entries")
        out.sortBy { it.appName.lowercase() }
        return out
    }

    /** Returns the installer package name for the given app, if available. */
    fun getInstallerPackage(context: Context, targetPackage: String): String? {
        val pm = context.packageManager
        return try {
            val ans = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                val src = pm.getInstallSourceInfo(targetPackage)
                src.installingPackageName ?: src.initiatingPackageName ?: src.originatingPackageName
            } else {
                @Suppress("DEPRECATION")
                pm.getInstallerPackageName(targetPackage)
            }
            logD("Installer package for $targetPackage = ${ans ?: "<none>"}")
            ans
        } catch (e: Exception) {
            logD("getInstallerPackage: none for $targetPackage (${e.javaClass.simpleName})")
            null
        }
    }

    /** Reads the trusted installers whitelist from SharedPreferences (JSON array of strings). */
    fun getTrustedInstallers(context: Context): Set<String> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val json = prefs.getString(KEY_TRUSTED_INSTALLERS, null) ?: return emptySet()
        return try {
            val arr = JSONArray(json)
            val set = LinkedHashSet<String>(arr.length())
            for (i in 0 until arr.length()) {
                val v = arr.optString(i, null)
                if (!v.isNullOrBlank()) set.add(v)
            }
            logI("Loaded trusted installers = ${set.size}: ${set}")
            set
        } catch (e: Exception) {
            logW("Malformed trusted installers JSON: ${e.message}")
            emptySet()
        }
    }

    /** Saves the trusted installers set to SharedPreferences. */
    private fun saveTrustedInstallers(context: Context, installers: Set<String>) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val arr = JSONArray()
        installers.forEach { arr.put(it) }
        prefs.edit().putString(KEY_TRUSTED_INSTALLERS, arr.toString()).apply()
        logI("Saved trusted installers (${installers.size})")
    }

    /** Adds a package to the trusted installers list. */
    fun addTrustedInstaller(context: Context, packageName: String): Boolean {
        if (packageName.isBlank()) return false
        val set = getTrustedInstallers(context).toMutableSet()
        val changed = set.add(packageName)
        if (changed) saveTrustedInstallers(context, set)
        logI("addTrustedInstaller($packageName) changed=$changed; total=${set.size}")
        return changed
    }

    /** Removes a package from the trusted installers list. */
    fun removeTrustedInstaller(context: Context, packageName: String): Boolean {
        if (packageName.isBlank()) return false
        val set = getTrustedInstallers(context).toMutableSet()
        val changed = set.remove(packageName)
        if (changed) saveTrustedInstallers(context, set)
        logI("removeTrustedInstaller($packageName) changed=$changed; total=${set.size}")
        return changed
    }

    /** Helper: whether package declares REQUEST_INSTALL_PACKAGES permission. */
    private fun declaresInstallPermission(pm: PackageManager, packageName: String): Boolean {
        return try {
            val pi: PackageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                pm.getPackageInfo(
                    packageName,
                    PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong())
                )
            } else {
                @Suppress("DEPRECATION")
                pm.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
            }
            val reqPerms = pi.requestedPermissions ?: return false
            reqPerms.any { it == android.Manifest.permission.REQUEST_INSTALL_PACKAGES }
        } catch (e: Exception) {
            false
        }
    }

    /** Helper: whether package currently can request package installs (Android 8+). */
    private fun canRequestPackageInstalls(pm: PackageManager, packageName: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                pm.getPackageInfo(packageName, 0)
                // For API 26+, PackageManager.hasSigningCertificate or other checks are not needed.
                // We must use the context-bound method, but we don't have a Context for that app.
                // Fallback: global check if that package holds permission and user toggle is on for that app.
                pm.canRequestPackageInstalls()
            } else false
        } catch (_: Exception) {
            false
        }
    }
}
