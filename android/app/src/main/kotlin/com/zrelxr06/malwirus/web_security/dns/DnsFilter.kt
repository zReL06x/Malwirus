package com.zrelxr06.malwirus.web_security.dns

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import android.util.Log
import android.content.Context
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.security.MessageDigest

/**
 * Simple DNS filter list holder. Matching is done via suffix match.
 */
object DnsFilter {
    private const val TAG = "DnsFilter"
    private val _enabled = MutableStateFlow(true)
    private val _blocklist = MutableStateFlow<Set<String>>(emptySet())
    val blocklist: StateFlow<Set<String>> = _blocklist.asStateFlow()
    val enabled: StateFlow<Boolean> = _enabled.asStateFlow()

    // Pre-listed (Bloom filter) toggle and approx count
    private val _prelistedEnabled = MutableStateFlow(true)
    private val _prelistedApproxCount = MutableStateFlow(0)
    val prelistedEnabled: StateFlow<Boolean> = _prelistedEnabled.asStateFlow()
    val prelistedApproxCount: StateFlow<Int> = _prelistedApproxCount.asStateFlow()

    // Simple Bloom filter storage
    // File format: int mBits, int kHashes, int nApprox, then byte[mBits/8] bit array
    private var mBits: Int = 0
    private var kHashes: Int = 0
    private var bits: ByteArray? = null

    fun set(domains: Set<String>) {
        _blocklist.value = domains.map { it.trim('.').lowercase() }.toSet()
        Log.i(TAG, "Set blocklist size=${_blocklist.value.size}")
    }
    fun add(domain: String) {
        val norm = domain.trim('.').lowercase()
        _blocklist.value = _blocklist.value + norm
        Log.d(TAG, "Added domain to blocklist: $norm (size=${_blocklist.value.size})")
    }
    fun remove(domain: String) {
        val norm = domain.trim('.').lowercase()
        _blocklist.value = _blocklist.value - norm
        Log.d(TAG, "Removed domain from blocklist: $norm (size=${_blocklist.value.size})")
    }

    fun setEnabled(value: Boolean) {
        _enabled.value = value
        Log.i(TAG, "DNS filtering enabled=$value")
    }

    fun setPrelistedEnabled(value: Boolean) {
        _prelistedEnabled.value = value
        Log.i(TAG, "Pre-listed (Bloom) filtering enabled=$value")
    }

    fun setPrelistedApproxCount(value: Int) {
        _prelistedApproxCount.value = value
    }

    // Step 1: Check pre-listed Bloom filter
    fun isPrelistedMatch(host: String): Boolean {
        if (!_enabled.value || !_prelistedEnabled.value) return false
        val arr = bits ?: return false
        if (mBits <= 0 || kHashes <= 0) return false
        val h = host.trim('.').lowercase()
        if (h.isEmpty()) return false
        val hashes = hashPair(h)
        for (i in 0 until kHashes) {
            val idx = ((hashes.first + i * hashes.second) % mBits + mBits) % mBits
            if (!getBit(arr, idx)) return false
        }
        // Log cautiously on Bloom hit
        Log.d(TAG, "Bloom HIT: $h")
        return true
    }

    // Step 2: Check user suffix list
    fun isUserBlocked(host: String): Boolean {
        if (!_enabled.value) return false
        val h = host.trim('.').lowercase()
        for (d in _blocklist.value) {
            if (h == d || h.endsWith(".$d")) return true
        }
        return false
    }

    // Load Bloom filter from file
    fun loadPrelistedFrom(file: File): Boolean {
        return try {
            if (!file.exists()) return false
            DataInputStream(FileInputStream(file)).use { dis ->
                val m = dis.readInt()
                val k = dis.readInt()
                val n = dis.readInt()
                val byteLen = (m + 7) / 8
                val data = ByteArray(byteLen)
                dis.readFully(data)
                mBits = m
                kHashes = k
                bits = data
                _prelistedApproxCount.value = n
                Log.i(TAG, "Loaded Bloom from ${file.absolutePath}: m=$mBits k=$kHashes n~$n bytes=${data.size}")
                true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to load Bloom: ${e.message}", e)
            mBits = 0
            kHashes = 0
            bits = null
            false
        }
    }

    // Build Bloom filter from a domains sequence and save
    fun buildPrelisted(
        context: Context,
        outFile: File,
        domains: Sequence<String>,
        nApprox: Int,
        mBitsDesired: Int? = null,
        kDesired: Int? = null,
        onProgress: ((Int) -> Unit)? = null
    ): Boolean {
        return try {
            val n = if (nApprox > 0) nApprox else 322_506 // fallback to provided size
            val m = mBitsDesired ?: (n * 10) // ~ target 1% FP -> ~9.6 bits per item
            val k = kDesired ?: 7
            val byteLen = (m + 7) / 8
            val data = ByteArray(byteLen)
            var processed = 0
            for (raw in domains) {
                val d = raw.trim().trim('.').lowercase()
                if (d.isEmpty()) continue
                val (h1, h2) = hashPair(d)
                for (i in 0 until k) {
                    val idx = ((h1 + i * h2) % m + m) % m
                    setBit(data, idx)
                }
                processed++
                if (onProgress != null && processed % 50_000 == 0) {
                    onProgress.invoke(processed)
                }
            }
            // persist
            DataOutputStream(FileOutputStream(outFile)).use { dos ->
                dos.writeInt(m)
                dos.writeInt(k)
                dos.writeInt(n)
                dos.write(data)
            }
            // load into memory
            mBits = m
            kHashes = k
            bits = data
            _prelistedApproxCount.value = n
            Log.i(TAG, "Built Bloom: m=$mBits k=$kHashes n~$n bytes=${data.size} -> ${outFile.absolutePath}")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to build Bloom: ${e.message}", e)
            false
        }
    }

    private fun getBit(arr: ByteArray, idx: Int): Boolean {
        val byteIndex = idx ushr 3
        val bitIndex = idx and 7
        val b = arr[byteIndex].toInt()
        return (b and (1 shl bitIndex)) != 0
    }

    private fun setBit(arr: ByteArray, idx: Int) {
        val byteIndex = idx ushr 3
        val bitIndex = idx and 7
        arr[byteIndex] = (arr[byteIndex].toInt() or (1 shl bitIndex)).toByte()
    }

    private fun hashPair(s: String): Pair<Int, Int> {
        // Use SHA-256 to derive two 32-bit hashes
        val md = MessageDigest.getInstance("SHA-256")
        val bytes = md.digest(s.toByteArray())
        fun toInt(off: Int): Int {
            return ((bytes[off].toInt() and 0xFF) shl 24) or
                ((bytes[off + 1].toInt() and 0xFF) shl 16) or
                ((bytes[off + 2].toInt() and 0xFF) shl 8) or
                (bytes[off + 3].toInt() and 0xFF)
        }
        val h1 = toInt(0)
        val h2 = toInt(4)
        return Pair(h1, if (h2 == 0) 0x9e3779b9.toInt() else h2)
    }
}

