package com.zrelxr06.malwirus.web_security.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import com.zrelxr06.malwirus.MainActivity
import com.zrelxr06.malwirus.web_security.dns.DnsFilter
import com.zrelxr06.malwirus.web_security.model.Counters
import com.zrelxr06.malwirus.web_security.repository.RuleRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.nio.ByteBuffer
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.File

/**
 * WebSecurityVpnService: Magaan na VPN para sa DNS filtering at per-app DNS blocking.
 * - Dinaan lang sa VPN ang traffic papunta sa configured DNS servers (addRoute /32).
 * - Kapag naka-include ang app, mafifilter ang DNS nito; ibang traffic hindi gagalawin.
 */
class WebSecurityVpnService : VpnService() {
    companion object {
        const val NOTIF_CHANNEL_ID = "web_vpn_channel"
        const val NOTIF_ID = 4201
        const val ACTION_APPLY_UPDATES = "com.zrelxr06.malwirus.web.ACTION_APPLY_UPDATES"
        const val ACTION_STOP = "com.zrelxr06.malwirus.web.ACTION_STOP"
        private const val TAG = "WebSecurityVpnService"
        // Simple in-process running flag to reflect actual service activity
        @Volatile
        var isRunning: Boolean = false

        // Upstream DNS servers; we add /32 routes so only DNS will pass via VPN.
        val DNS_SERVERS = listOf(
            InetAddress.getByName("1.1.1.1"),
            InetAddress.getByName("8.8.8.8")
        )
    }

    private var vpnInterface: ParcelFileDescriptor? = null
    private var job: Job? = null
    private val serviceScope = CoroutineScope(Dispatchers.IO)

    /**
     * Entry para simulan/itrigger ang service.
     * - ACTION_APPLY_UPDATES: i-rebuild ang tunnel para ma-apply ang bagong rules.
     * - ACTION_STOP: graceful stop + mark vpn_active=false sa prefs.
     */
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "onStartCommand action=${intent?.action}")
        if (intent?.action == ACTION_APPLY_UPDATES) {
            Log.d(TAG, "Applying live updates to VPN tunnel")
            rebuildTunnel()
            return START_NOT_STICKY
        }
        if (intent?.action == ACTION_STOP) {
            Log.i(TAG, "Stopping service by request")
            try {
                vpnInterface?.close()
            } catch (_: Exception) {
            }
            vpnInterface = null
            job?.cancel()
            stopForeground(true)
            try {
                getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE).edit()
                    .putBoolean("vpn_active", false).apply()
            } catch (_: Exception) {
            }
            isRunning = false
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE).edit()
                .putBoolean("vpn_active", true).apply()
        } catch (_: Exception) {
        }
        isRunning = true
        rebuildTunnel()
        return START_NOT_STICKY
    }

    /**
     * Cleanup ng resources (jobs/tunnel/flags) kapag nade-destroy ang service.
     */
    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "Service destroyed; cancelling jobs and closing interface")
        job?.cancel()
        serviceScope.cancel()
        try {
            vpnInterface?.close()
        } catch (_: Exception) {
        }
        vpnInterface = null
        try {
            stopForeground(true)
        } catch (_: Exception) {
        }
        try {
            getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE).edit()
                .putBoolean("vpn_active", false).apply()
        } catch (_: Exception) {
        }
        isRunning = false
    }

    /**
     * I-setup muli ang VPN tunnel:
     * - Session/MTU/address at DNS routes (/32) para DNS-only via VPN.
     * - Per-app allowlist (o capture-all except self) batay sa prefs.
     * - Initialize DNS blocklist at i-activate ang DnsFilter.
     */
    private fun rebuildTunnel() {
        Log.i(TAG, "Rebuilding VPN tunnel")
        job?.cancel()
        vpnInterface?.close()
        vpnInterface = null

        val builder = Builder()
            .setSession("Malwirus Web Security")
            .setBlocking(true)
            .setMtu(1500)
            .addAddress("10.0.0.2", 32)

        // Route only DNS servers so non-DNS traffic stays on normal network.
        for (server in DNS_SERVERS) {
            builder.addDnsServer(server)
            builder.addRoute(server.hostAddress, 32)
        }

        // Apply per-app rules: include only targeted packages in VPN (effectively filters their DNS)
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        // Debug: Log all SharedPreferences keys and values
        Log.d(TAG, "All SharedPreferences keys: ${prefs.all.keys}")
        val jsonString = prefs.getString("flutter.web_vpn_blocked_packages", null)
        Log.d(TAG, "Raw blocked packages value: '$jsonString'")

        val packagesList = try {
            if (jsonString != null && jsonString.isNotEmpty()) {
                // Flutter format: "base64prefix!["item1","item2"]"
                val jsonPart = if (jsonString.contains("!")) {
                    jsonString.substringAfter("!")
                } else {
                    jsonString
                }

                Log.d(TAG, "Extracted JSON part: '$jsonPart'")

                if (jsonPart.startsWith("[") && jsonPart.endsWith("]")) {
                    // Parse JSON array: ["com.android.chrome", "org.mozilla.firefox"]
                    jsonPart.removeSurrounding("[", "]")
                        .split(",")
                        .map { it.trim().removeSurrounding("\"") }
                        .filter { it.isNotEmpty() }
                } else {
                    Log.w(TAG, "Unexpected JSON format: $jsonPart")
                    emptyList()
                }
            } else {
                Log.d(TAG, "No blocked packages found in SharedPreferences")
                emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse blocked packages: ${e.message}", e)
            emptyList()
        }
        val set = packagesList.toSet()
        Log.d(TAG, "Applying per-app capture for ${set.size} packages: $set")

        // Re-enable per-app filtering
        if (set.isNotEmpty()) {
            // Only the selected apps use the VPN
            for (pkg in set) {
                try {
                    builder.addAllowedApplication(pkg)
                    Log.d(TAG, "Allowed app on VPN: $pkg")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to allow app on VPN: $pkg - ${e.message}")
                }
            }
            // Always exclude our own app from the VPN
            try {
                builder.addDisallowedApplication(packageName)
            } catch (_: Exception) {
            }
        } else {
            // No apps configured: capture all traffic except our own app
            Log.d(TAG, "No specific apps configured; capturing all traffic except Malwirus")
            try {
                builder.addDisallowedApplication(packageName)
            } catch (_: Exception) {
            }
        }

        // Initialize DNS blocklist from prefs so service has it on cold start
        val domainsJsonString = prefs.getString("flutter.web_vpn_dns_blocklist", null)
        Log.d(TAG, "Raw DNS blocklist value: '$domainsJsonString'")

        val domainsList = try {
            if (domainsJsonString != null && domainsJsonString.isNotEmpty()) {
                // Flutter format: "base64prefix!["item1","item2"]"
                val jsonPart = if (domainsJsonString.contains("!")) {
                    domainsJsonString.substringAfter("!")
                } else {
                    domainsJsonString
                }

                Log.d(TAG, "Extracted DNS JSON part: '$jsonPart'")

                if (jsonPart.startsWith("[") && jsonPart.endsWith("]")) {
                    // Parse JSON array: ["hentai20.io", "hanime.tv"]
                    jsonPart.removeSurrounding("[", "]")
                        .split(",")
                        .map { it.trim().removeSurrounding("\"") }
                        .filter { it.isNotEmpty() }
                } else {
                    Log.w(TAG, "Unexpected DNS JSON format: $jsonPart")
                    emptyList()
                }
            } else {
                Log.d(TAG, "No DNS blocklist found in SharedPreferences")
                emptyList()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse DNS blocklist: ${e.message}", e)
            emptyList()
        }
        val domains = domainsList.toSet()
        if (domains.isNotEmpty()) {
            Log.d(
                TAG,
                "Initializing DNS blocklist with ${domains.size} domains: ${domains.joinToString(", ")}"
            )
            DnsFilter.set(domains)
        } else {
            Log.w(TAG, "DNS blocklist is empty!")
        }
        // The DNS filter should be active whenever the VPN is active.
        // The 'dns_universal_enabled' flag controls routing scope (all apps vs per-app),
        // NOT whether DNS filtering logic is enabled.
        try {
            val vpnPrefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
            val universal = vpnPrefs.getBoolean("dns_universal_enabled", true)
            DnsFilter.setEnabled(true)
            Log.d(
                TAG,
                "Universal DNS filtering (routing scope) enabled=$universal; DNS filter active=true"
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to read universal DNS state: ${e.message}")
            DnsFilter.setEnabled(true)
        }

        // Ensure pre-listed Bloom filter is built/loaded and apply its enabled toggle
        ensurePrelistedBloom()

        try {
            vpnInterface = builder.establish()
            Log.i(TAG, "VPN interface established")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish VPN interface: ${e.message}", e)
            return
        }

        job = serviceScope.launch { runTunLoop() }
    }

    /**
     * Main TUN loop: nagbabasa ng packets at nagha-handle ng UDP:53 (DNS).
     * - Parse minimal DNS query, i-check sa pre-listed Bloom at user blocklist.
     * - Kapag blocked: drop. Kapag allowed: i-relay sa upstream at i-craft ang response.
     */
    private suspend fun runTunLoop() {
        val iface = vpnInterface ?: return
        val input = FileInputStream(iface.fileDescriptor)
        val output = FileOutputStream(iface.fileDescriptor)
        val packet = ByteArray(32767)

        val upstream = DNS_SERVERS.first()
        val upstreamAddr = upstream

        val socket = DatagramSocket()
        Log.d(TAG, "TUN loop started; upstream DNS=${upstreamAddr.hostAddress}")

        while (true) {
            val length = try {
                input.read(packet)
            } catch (e: Exception) {
                Log.w(TAG, "Read from TUN failed: ${e.message}"); break
            }
            if (length <= 0) continue
            Counters.incBytesIn(length.toLong())

            // Handle minimal IPv4/UDP/DNS parsing
            if (length > 28 && (packet[9].toInt() and 0xFF) == 17 /* UDP */) {
                val ipHeaderLen = (packet[0].toInt() and 0x0F) * 4
                val udpOffset = ipHeaderLen
                val srcPort =
                    ((packet[udpOffset].toInt() and 0xFF) shl 8) or (packet[udpOffset + 1].toInt() and 0xFF)
                val dstPort =
                    ((packet[udpOffset + 2].toInt() and 0xFF) shl 8) or (packet[udpOffset + 3].toInt() and 0xFF)
                if (dstPort == 53) {
                    Counters.incDnsQueries()
                    // Very basic DNS question parse: first QNAME in question section
                    val dnsOffset = udpOffset + 8
                    val qname = try {
                        parseDnsQName(packet, dnsOffset + 12, length)
                    } catch (e: Exception) {
                        Log.w(TAG, "DNS parse error: ${e.message}"); null
                    }
                    if (qname != null) {
                        // Step 1: Pre-listed Bloom
                        if (DnsFilter.isPrelistedMatch(qname)) {
                            Counters.incDnsBlocked()
                            Log.i(TAG, "Blocked DNS (pre-listed): $qname")
                            // Drop the DNS query
                            continue
                        }
                        // Step 2: User suffix list
                        if (DnsFilter.isUserBlocked(qname)) {
                            Counters.incDnsBlocked()
                            Log.i(TAG, "Blocked DNS (user list): $qname")
                            // Drop the DNS query by not forwarding; optionally could synthesize NXDOMAIN
                            continue
                        }
                    } else {
                        Log.w(TAG, "Failed to parse DNS query name")
                    }
                    // Relay to upstream and return response
                    try {
                        val dnsLen = length - dnsOffset
                        val sendBytes = packet.copyOfRange(dnsOffset, dnsOffset + dnsLen)
                        val req = DatagramPacket(sendBytes, sendBytes.size, upstreamAddr, 53)
                        socket.send(req)
                        val respBuf = ByteArray(1500)
                        val resp = DatagramPacket(respBuf, respBuf.size)
                        socket.soTimeout = 2000
                        socket.receive(resp)

                        // Craft response packet with proper IP/UDP headers
                        val responsePacket = craftDnsResponse(
                            packet,
                            length,
                            resp.data,
                            resp.length,
                            ipHeaderLen,
                            udpOffset,
                            srcPort
                        )
                        if (responsePacket != null) {
                            output.write(responsePacket)
                            Counters.incBytesOut(responsePacket.size.toLong())
                        } else {
                            Log.w(TAG, "Failed to craft DNS response packet")
                        }
                    } catch (e: Exception) {
                        Log.w(TAG, "Upstream DNS relay failed: ${e.message}")
                    }
                    continue
                }
            }
            // For non-DNS traffic or when we can't handle response, just drop
        }

        try {
            socket.close()
        } catch (_: Exception) {
        }
        try {
            input.close()
        } catch (_: Exception) {
        }
        try {
            output.close()
        } catch (_: Exception) {
        }
        Log.d(TAG, "TUN loop ended")
    }

    /**
     * Siguruhin na loaded ang pre-listed Bloom filter:
     * - Subukang i-load mula filesDir/bloom/prelisted.bloom; kapag wala, i-build mula assets.
     * - I-persist ang approx count para sa UI queries; i-apply ang enabled toggle.
     */
    private fun ensurePrelistedBloom() {
        try {
            val prefs = getSharedPreferences("web_vpn_prefs", Context.MODE_PRIVATE)
            val enabled = prefs.getBoolean("prelisted_enabled", true)
            DnsFilter.setPrelistedEnabled(enabled)

            val outDir = File(filesDir, "bloom")
            if (!outDir.exists()) outDir.mkdirs()
            val bloomFile = File(outDir, "prelisted.bloom")

            Log.d(TAG, "Pre-listed enabled=$enabled; bloomFile=${bloomFile.absolutePath} exists=${bloomFile.exists()}")
            var loaded = DnsFilter.loadPrelistedFrom(bloomFile)
            if (!loaded) {
                Log.i(TAG, "Pre-listed Bloom file missing. Building from assets…")
                val countApprox = 322_506
                val input = assets.open("pre_listed_domains/domains.txt")
                val t0 = System.currentTimeMillis()
                BufferedReader(InputStreamReader(input)).use { br ->
                    val seq = generateSequence { br.readLine() }
                    val ok = DnsFilter.buildPrelisted(
                        this,
                        bloomFile,
                        seq,
                        countApprox,
                        onProgress = { processed ->
                            Log.d(TAG, "Bloom build progress: processed=$processed")
                        }
                    )
                    val t1 = System.currentTimeMillis()
                    Log.i(TAG, "Bloom build completed ok=$ok in ${t1 - t0} ms")
                    if (ok) {
                        loaded = DnsFilter.loadPrelistedFrom(bloomFile)
                    }
                }
            }
            // Persist approx count for UI queries
            prefs.edit().putInt("prelisted_count", DnsFilter.prelistedApproxCount.value).apply()
            Log.i(TAG, "Pre-listed Bloom status: loaded=$loaded enabled=$enabled approxCount=${DnsFilter.prelistedApproxCount.value}")
        } catch (e: Exception) {
            Log.w(TAG, "ensurePrelistedBloom failed: ${e.message}")
        }
    }

    /**
     * I-parse ang unang QNAME sa DNS question section.
     * Note: Hindi sinusuportahan ang compression pointers dito; magre-return ng null.
     */
    private fun parseDnsQName(data: ByteArray, start: Int, totalLen: Int): String? {
        var i = start
        val labels = mutableListOf<String>()
        while (i < totalLen) {
            val len = data[i].toInt() and 0xFF
            if (len == 0) {
                i++
                break
            }
            if (len and 0xC0 == 0xC0) { // pointer; not handled
                return null
            }
            i++
            if (i + len > totalLen) return null
            val label = String(data, i, len)
            labels.add(label)
            i += len
        }
        return if (labels.isEmpty()) null else labels.joinToString(".")
    }

    /**
     * Gumawa ng IPv4/UDP packet na may DNS response payload.
     * - Swap ng IP at ports mula sa original request; i-calc ang IP checksum.
     */
    private fun craftDnsResponse(
        originalPacket: ByteArray,
        originalLength: Int,
        dnsResponse: ByteArray,
        dnsResponseLength: Int,
        ipHeaderLen: Int,
        udpOffset: Int,
        originalSrcPort: Int
    ): ByteArray? {
        try {
            // Extract original IP header info
            val srcIp = ByteArray(4)
            val dstIp = ByteArray(4)
            System.arraycopy(originalPacket, 12, srcIp, 0, 4) // Original source becomes destination
            System.arraycopy(originalPacket, 16, dstIp, 0, 4) // Original destination becomes source

            // Calculate new packet size
            val newUdpLen = 8 + dnsResponseLength
            val newIpLen = ipHeaderLen + newUdpLen
            val responsePacket = ByteArray(newIpLen)

            // Build IP header (swap src/dst)
            responsePacket[0] = 0x45.toByte() // Version 4, Header length 5*4=20
            responsePacket[1] = 0x00.toByte() // Type of service
            responsePacket[2] = (newIpLen shr 8).toByte() // Total length high
            responsePacket[3] = (newIpLen and 0xFF).toByte() // Total length low
            responsePacket[4] = 0x00.toByte() // Identification high
            responsePacket[5] = 0x00.toByte() // Identification low
            responsePacket[6] = 0x40.toByte() // Flags: Don't fragment
            responsePacket[7] = 0x00.toByte() // Fragment offset
            responsePacket[8] = 0x40.toByte() // TTL
            responsePacket[9] = 0x11.toByte() // Protocol: UDP
            responsePacket[10] = 0x00.toByte() // Checksum high (will calculate)
            responsePacket[11] = 0x00.toByte() // Checksum low
            System.arraycopy(dstIp, 0, responsePacket, 12, 4) // Source IP (swapped)
            System.arraycopy(srcIp, 0, responsePacket, 16, 4) // Destination IP (swapped)

            // Calculate IP header checksum
            val ipChecksum = calculateChecksum(responsePacket, 0, ipHeaderLen)
            responsePacket[10] = (ipChecksum shr 8).toByte()
            responsePacket[11] = (ipChecksum and 0xFF).toByte()

            // Build UDP header (swap ports)
            val udpStart = ipHeaderLen
            responsePacket[udpStart] = 0x00.toByte() // Source port high (53)
            responsePacket[udpStart + 1] = 0x35.toByte() // Source port low (53)
            responsePacket[udpStart + 2] = (originalSrcPort shr 8).toByte() // Dest port high
            responsePacket[udpStart + 3] = (originalSrcPort and 0xFF).toByte() // Dest port low
            responsePacket[udpStart + 4] = (newUdpLen shr 8).toByte() // UDP length high
            responsePacket[udpStart + 5] = (newUdpLen and 0xFF).toByte() // UDP length low
            responsePacket[udpStart + 6] = 0x00.toByte() // Checksum high (optional for IPv4)
            responsePacket[udpStart + 7] = 0x00.toByte() // Checksum low

            // Copy DNS response data
            System.arraycopy(dnsResponse, 0, responsePacket, udpStart + 8, dnsResponseLength)

            return responsePacket
        } catch (e: Exception) {
            Log.e(TAG, "Error crafting DNS response: ${e.message}", e)
            return null
        }
    }

    /**
     * Compute ng IPv4 header checksum (one's complement sum).
     */
    private fun calculateChecksum(data: ByteArray, start: Int, length: Int): Int {
        var sum = 0L
        var i = start
        while (i < start + length - 1) {
            sum += ((data[i].toInt() and 0xFF) shl 8) + (data[i + 1].toInt() and 0xFF)
            i += 2
        }
        if (i < start + length) {
            sum += (data[i].toInt() and 0xFF) shl 8
        }
        while (sum shr 16 != 0L) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        return (sum.inv() and 0xFFFF).toInt()
    }
}
