package com.zrelxr06.malwirus.device_security

import android.app.Application
import com.aheaditec.talsec_security.security.api.SuspiciousAppInfo
import com.aheaditec.talsec_security.security.api.ThreatListener
import com.aheaditec.talsec_security.security.api.Talsec
import com.aheaditec.talsec_security.security.api.TalsecConfig
import android.app.Activity
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager.SCREEN_RECORDING_STATE_VISIBLE
import java.util.function.Consumer
import com.zrelxr06.malwirus.device_security.TalsecNotifier
import com.zrelxr06.malwirus.device_security.SecurityThreat
import com.zrelxr06.malwirus.device_security.TalsecManager


class TalsecApplication : Application(), ThreatListener.ThreatDetected {
    override fun onCreate() {
        super.onCreate()

        Log.i(TAG, "TalsecApplication.onCreate - building config and starting SDK")

        // Build Talsec configuration using your app settings
        val config = TalsecConfig.Builder(
            expectedPackageName,
            expectedSigningCertificateHashBase64
        )
            .watcherMail(watcherMail)
            .supportedAlternativeStores(supportedAlternativeStores)
            .prod(isProd)
            .build()

        // Register threat listeners and start the SDK
        Log.i(TAG, "Registering ThreatListener and starting Talsec")
        ThreatListener(this, deviceStateListener).registerListener(this)
        Talsec.start(this, config)
        Log.i(TAG, "Talsec.start invoked")

        // Configure allowed stores for suspicious-packages pruning
        TalsecManager.setAllowedInstallerPackages(supportedAlternativeStores.asList())

        // Register activity lifecycle callbacks to observe screenshots and screen recordings
        registerActivityLifecycleCallbacks(object : ActivityLifecycleCallbacks {
            override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) {
                // Set to 'true' to block screen capture entirely
                Log.d(
                    TAG,
                    "onActivityCreated: ${'$'}{activity.localClassName} - blockScreenCapture=false"
                )
                Talsec.blockScreenCapture(activity, false)
            }

            override fun onActivityStarted(activity: Activity) {
                Log.d(TAG, "onActivityStarted: ${'$'}{activity.localClassName}")
                unregisterCallbacks()
                currentActivity = activity
                registerCallbacks(activity)
            }

            override fun onActivityResumed(activity: Activity) {}
            override fun onActivityPaused(activity: Activity) {}

            override fun onActivityStopped(activity: Activity) {
                Log.d(TAG, "onActivityStopped: ${'$'}{activity.localClassName}")
                if (activity == currentActivity) {
                    unregisterCallbacks()
                    currentActivity = null
                }
            }

            override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) {}
            override fun onActivityDestroyed(activity: Activity) {}
        })
    }

    companion object {
        private const val expectedPackageName = "com.zrelxr06.malwirus"
        private val expectedSigningCertificateHashBase64 = arrayOf(
            "81MBrkMVTXZOQvKmu4WIdHXODt5XjoEcDbPRBYVYj/4="
        )
        private const val watcherMail = "rpangilinan22-0610@cca.edu.ph" // for Alerts and Reports
        private val supportedAlternativeStores: Array<String> = arrayOf(
            "com.android.vending",
            "com.apkpure.aegon",
            "com.uptodown"
        )
        private val isProd = true

        private const val TAG = "TalsecManager"

        private const val DISABLE_SCREEN_EVENTS = true
        private const val DISABLE_SYSTEM_VPN = true
    }

    private val deviceStateListener = object : ThreatListener.DeviceState {
        override fun onUnlockedDeviceDetected() {
            TalsecNotifier.addThreat(SecurityThreat.UNLOCKED_DEVICE)
            Log.w(TAG, "onUnlockedDeviceDetected")
        }

        override fun onHardwareBackedKeystoreNotAvailableDetected() {
            TalsecNotifier.addThreat(SecurityThreat.NO_HW_KEYSTORE)
            Log.w(TAG, "onHardwareBackedKeystoreNotAvailableDetected")
        }

        override fun onDeveloperModeDetected() {
            TalsecNotifier.addThreat(SecurityThreat.DEVELOPER_MODE)
            Log.w(TAG, "onDeveloperModeDetected")
        }

        override fun onADBEnabledDetected() {
            TalsecNotifier.addThreat(SecurityThreat.ADB_ENABLED)
            Log.w(TAG, "onADBEnabledDetected")
        }

        override fun onSystemVPNDetected() {
            if (DISABLE_SYSTEM_VPN) {
                Log.i(TAG, "onSystemVPNDetected suppressed by flag")
                return
            }
            reportThreat(SecurityThreat.SYSTEM_VPN, "onSystemVPNDetected")
        }
    }

    override fun onRootDetected() {
        reportThreat(SecurityThreat.ROOT, "onRootDetected")
    }

    override fun onDebuggerDetected() {
        reportThreat(SecurityThreat.DEBUGGER, "onDebuggerDetected")
    }

    override fun onEmulatorDetected() {
        reportThreat(SecurityThreat.EMULATOR, "onEmulatorDetected")
    }

    override fun onTamperDetected() {
        reportThreat(SecurityThreat.TAMPER, "onTamperDetected")
    }

    override fun onUntrustedInstallationSourceDetected() {
        reportThreat(SecurityThreat.UNTRUSTED_SOURCE, "onUntrustedInstallationSourceDetected")
    }

    override fun onHookDetected() {
        reportThreat(SecurityThreat.HOOK, "onHookDetected")
    }

    override fun onDeviceBindingDetected() {
        reportThreat(SecurityThreat.DEVICE_BINDING, "onDeviceBindingDetected")
    }

    override fun onObfuscationIssuesDetected() {
        reportThreat(SecurityThreat.OBFUSCATION_ISSUES, "onObfuscationIssuesDetected")
    }

    override fun onMalwareDetected(p0: MutableList<SuspiciousAppInfo>?) {
        // Map SuspiciousAppInfo to package names and store them for Flutter retrieval
        val pkgs = p0?.mapNotNull { info ->
            try {
                // Prefer Kotlin property; fall back to toString if necessary
                val nameField =
                    info.javaClass.methods.firstOrNull { it.name == "getPackageName" && it.parameterCount == 0 }
                @Suppress("UNCHECKED_CAST")
                (nameField?.invoke(info) as? String) ?: run { null }
            } catch (_: Exception) {
                null
            }
        }?.filter { it.isNotBlank() } ?: emptyList()
        if (pkgs.isNotEmpty()) {
            TalsecManager.addSuspiciousPackagesByName(applicationContext, pkgs)
            Log.i(TAG, "onMalwareDetected packages=$pkgs")
        }
        reportThreat(SecurityThreat.MALWARE, "onMalwareDetected: ${'$'}{p0?.size ?: 0} items")
    }

    override fun onScreenshotDetected() {
        if (DISABLE_SCREEN_EVENTS) {
            Log.i(TAG, "onScreenshotDetected suppressed by flag")
            return
        }
        reportThreat(SecurityThreat.SCREENSHOT, "onScreenshotDetected")
    }

    override fun onScreenRecordingDetected() {
        if (DISABLE_SCREEN_EVENTS) {
            Log.i(TAG, "onScreenRecordingDetected suppressed by flag")
            return
        }
        reportThreat(SecurityThreat.SCREEN_RECORDING, "onScreenRecordingDetected")
    }

    override fun onMultiInstanceDetected() {
        TalsecNotifier.addThreat(SecurityThreat.MULTI_INSTANCE)
        Log.w(TAG, "onMultiInstanceDetected")
    }

    // Activity and screen event monitoring (Android 14/15+)
    private var currentActivity: Activity? = null
    private var screenCaptureCallback: Activity.ScreenCaptureCallback? = null
    private val screenRecordCallback: Consumer<Int> = Consumer { state ->
        if (state == SCREEN_RECORDING_STATE_VISIBLE) {
            Talsec.onScreenRecordingDetected()
        }
    }
    private var screenRecordRegistered: Boolean = false

    private fun registerCallbacks(activity: Activity) {
        if (!DISABLE_SCREEN_EVENTS && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            screenCaptureCallback = Activity.ScreenCaptureCallback {
                Log.d(TAG, "ScreenCaptureCallback.onScreenshot")
                Talsec.onScreenshotDetected()
            }
            activity.registerScreenCaptureCallback(
                baseContext.mainExecutor,
                screenCaptureCallback!!
            )
        }

        if (!DISABLE_SCREEN_EVENTS && Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            val initialState = activity.windowManager.addScreenRecordingCallback(
                mainExecutor,
                screenRecordCallback
            )
            Log.d(TAG, "addScreenRecordingCallback initialState=${'$'}initialState")
            screenRecordCallback.accept(initialState)
            screenRecordRegistered = true
        }
    }

    private fun unregisterCallbacks() {
        currentActivity?.let { activity ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE && screenCaptureCallback != null) {
                activity.unregisterScreenCaptureCallback(screenCaptureCallback!!)
                screenCaptureCallback = null
                Log.d(TAG, "unregisterScreenCaptureCallback")
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM && screenRecordRegistered) {
                try {
                    activity.windowManager.removeScreenRecordingCallback(screenRecordCallback)
                    Log.d(TAG, "removeScreenRecordingCallback")
                } catch (e: Exception) {
                    Log.w(TAG, "removeScreenRecordingCallback failed: ${'$'}{e.message}")
                } finally {
                    screenRecordRegistered = false
                }
            }
        }
    }

    private fun reportThreat(threat: SecurityThreat, logMsg: String) {
        // Gate reporting via feature flags
        if (DISABLE_SCREEN_EVENTS && (threat == SecurityThreat.SCREENSHOT || threat == SecurityThreat.SCREEN_RECORDING)) {
            Log.i(TAG, "$logMsg suppressed by flag")
            return
        }
        if (DISABLE_SYSTEM_VPN && threat == SecurityThreat.SYSTEM_VPN) {
            Log.i(TAG, "$logMsg suppressed by flag")
            return
        }
        TalsecNotifier.addThreat(threat)
        Log.w(TAG, logMsg)
    }

}