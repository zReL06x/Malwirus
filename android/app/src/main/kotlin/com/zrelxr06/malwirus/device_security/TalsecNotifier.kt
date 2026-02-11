package com.zrelxr06.malwirus.device_security

import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import android.util.Log
import com.zrelxr06.malwirus.MainActivity

/**
 * SecurityThreat: Mga banta na nirereport ng Talsec freeRASP.
 * Pwede mong i-adjust/i-extend depende sa policy/UI ng app mo.
 */
enum class SecurityThreat {
    ROOT,
    DEBUGGER,
    EMULATOR,
    TAMPER,
    UNTRUSTED_SOURCE,
    HOOK,
    DEVICE_BINDING,
    OBFUSCATION_ISSUES,
    MALWARE,
    SCREENSHOT,
    SCREEN_RECORDING,
    MULTI_INSTANCE,

    // Device state
    UNLOCKED_DEVICE,
    NO_HW_KEYSTORE,
    DEVELOPER_MODE,
    ADB_ENABLED,
    SYSTEM_VPN,
}

/**
 * TalsecNotifier: Singleton na nagtatago ng kasalukuyang active threats (in-memory)
 * at ine-expose ito bilang LiveData.
 * Note: Walang "threat removed" event ang SDK, kaya ang consumers ang tatawag ng
 * [clearThreat] o [clearAllThreats] kapag kailangan (hal. matapos i-acknowledge ng user ang warning UI).
 */
object TalsecNotifier {

    private val lock = Any()
    private val currentThreats = LinkedHashSet<SecurityThreat>()

    private val _threatsLiveData = MutableLiveData<Set<SecurityThreat>>(emptySet())
    val threatsLiveData: LiveData<Set<SecurityThreat>> = _threatsLiveData

    // Local log helper: naka-gate sa session-scoped debug flag
    private inline fun logD(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.d(TAG, msg) }

    /** Magdagdag/mag-update ng threat at i-notify ang observers ng bagong snapshot. */
    fun addThreat(threat: SecurityThreat) {
        val snapshot: Set<SecurityThreat>
        synchronized(lock) {
            currentThreats.add(threat)
            snapshot = currentThreats.toSet()
        }
        logD("addThreat: ${'$'}threat -> size=${'$'}{snapshot.size}")
        _threatsLiveData.postValue(snapshot)
    }

    /** Magdagdag ng maraming threats sabay at i-notify ang observers. */
    fun addThreats(threats: Collection<SecurityThreat>) {
        val snapshot: Set<SecurityThreat>
        synchronized(lock) {
            currentThreats.addAll(threats)
            snapshot = currentThreats.toSet()
        }
        logD("addThreats: +${'$'}{threats.size} -> size=${'$'}{snapshot.size}")
        _threatsLiveData.postValue(snapshot)
    }

    /** I-clear ang isang threat at i-notify ang observers. Kapag naubos, clean state ang makikita. */
    fun clearThreat(threat: SecurityThreat) {
        val snapshot: Set<SecurityThreat>
        synchronized(lock) {
            currentThreats.remove(threat)
            snapshot = currentThreats.toSet()
        }
        logD("clearThreat: ${'$'}threat -> size=${'$'}{snapshot.size}")
        _threatsLiveData.postValue(snapshot)
    }

    /** I-clear lahat ng threats at i-notify ang observers na empty set (clean state). */
    fun clearAllThreats() {
        synchronized(lock) {
            if (currentThreats.isEmpty()) {
                // Avoid redundant posts when already clean
                logD("clearAllThreats: already empty")
                _threatsLiveData.postValue(emptySet())
                return
            }
            currentThreats.clear()
        }
        logD("clearAllThreats: size=0")
        _threatsLiveData.postValue(emptySet())
    }

    /** Ibalik ang kasalukuyang snapshot (synchronous). */
    fun current(): Set<SecurityThreat> = synchronized(lock) { currentThreats.toSet() }

    private const val TAG = "TalsecNotifier"
}
