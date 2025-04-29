package com.zrelxr06.malwirus.sms_security.google_safebrowsing

import android.util.Log
import com.google.gson.Gson
import com.google.gson.annotations.SerializedName
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import java.util.regex.Pattern

/**
 * Client for interacting with Google's Safe Browsing API v4
 * Documentation: https://developers.google.com/safe-browsing/v4/lookup-api
 */
class SafeBrowsingClient(private val apiKey: String) {
    private val TAG = "SafeBrowsingClient"
    private val apiUrl = "https://safebrowsing.googleapis.com/v4/threatMatches:find?key=$apiKey"
    private val gson = Gson()
    private val clientId = "com.zrelxr06.malwirus"
    private val clientVersion = "1.0.0"
    
    // This client only interacts with Google's Safe Browsing API
    
    init {
        Log.d(TAG, "SafeBrowsingClient initialized with client ID: $clientId, version: $clientVersion")
        val maskedKey = apiKey.take(5) + "..." + apiKey.takeLast(5)
        Log.d(TAG, "Using API key (masked): $maskedKey")
    }

    /**
     * Checks if a URL is safe according to Google's Safe Browsing API
     * This method only interacts with Google's API and doesn't perform any local checks
     * 
     * @param url The URL to check
     * @return A SafeBrowsingResult object containing threat information if found
     */
    suspend fun checkUrl(url: String): SafeBrowsingResult = withContext(Dispatchers.IO) {
        Log.d(TAG, "checkUrl() called for URL: $url")
        
        try {
            val connection = URL(apiUrl).openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true
            
            val requestId = UUID.randomUUID().toString()
            Log.d(TAG, "Generated request ID: $requestId for URL check")
            
            val requestBody = createRequestBody(url, requestId)
            Log.d(TAG, "Request body created for URL: $url")
            
            Log.d(TAG, "Sending request to Safe Browsing API")
            
            val outputStream = OutputStreamWriter(connection.outputStream)
            outputStream.write(requestBody)
            outputStream.flush()
            Log.d(TAG, "Request sent successfully")
            
            val responseCode = connection.responseCode
            Log.d(TAG, "Received response code: $responseCode")
            
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val reader = BufferedReader(InputStreamReader(connection.inputStream))
                val response = StringBuilder()
                var line: String?
                
                while (reader.readLine().also { line = it } != null) {
                    response.append(line)
                }
                
                reader.close()
                connection.disconnect()
                
                val responseString = response.toString()
                Log.d(TAG, "Response length: ${responseString.length} characters")
                
                if (responseString.contains("\"matches\"")) {
                    Log.d(TAG, "Matches found in response - URL is UNSAFE")
                    val apiResponse = gson.fromJson(responseString, SafeBrowsingApiResponse::class.java)
                    Log.d(TAG, "Parsed ${apiResponse.matches.size} threats from response")
                    
                    // Parse threats from the response
                    val threats = apiResponse.matches.map { match ->
                        Log.d(TAG, "Threat found - Type: ${match.threatType}, Platform: ${match.platformType}")
                        ThreatInfo(
                            type = match.threatType,
                            platform = match.platformType,
                            url = match.threat.url
                        )
                    }
                    
                    SafeBrowsingResult(
                        isSafe = false,
                        threats = threats,
                        error = null
                    )
                } else {
                    Log.d(TAG, "No matches found in response - URL is SAFE")
                    SafeBrowsingResult(
                        isSafe = true,
                        threats = emptyList(),
                        error = null
                    )
                }
            } else {
                Log.e(TAG, "Error response from API: $responseCode")
                val errorStream = connection.errorStream
                val reader = BufferedReader(InputStreamReader(errorStream))
                val errorResponse = StringBuilder()
                var line: String?
                
                while (reader.readLine().also { line = it } != null) {
                    errorResponse.append(line)
                }
                
                reader.close()
                connection.disconnect()
                
                val errorResponseStr = errorResponse.toString()
                Log.e(TAG, "Error details: $errorResponseStr")
                
                SafeBrowsingResult(
                    isSafe = false,
                    error = "API Error: HTTP $responseCode - $errorResponseStr",
                    threats = emptyList()
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Exception when checking URL safety: ${e.message}", e)
            SafeBrowsingResult(
                isSafe = false,
                error = "Network Error: ${e.message}",
                threats = emptyList()
            )
        }
    }



    /**
     * Creates the JSON request body for the Safe Browsing API
     */
    private fun createRequestBody(url: String, requestId: String): String {
        Log.d(TAG, "Creating request body for URL: $url with requestId: $requestId")
        val request = SafeBrowsingRequest(
            client = ClientInfo(clientId, clientVersion),
            threatInfo = ThreatInfoRequest(
                threatTypes = listOf(
                    "MALWARE", 
                    "SOCIAL_ENGINEERING",
                    "UNWANTED_SOFTWARE",
                    "POTENTIALLY_HARMFUL_APPLICATION"
                ),
                platformTypes = listOf("ANDROID", "ANY_PLATFORM"),
                threatEntryTypes = listOf("URL"),
                threatEntries = listOf(ThreatEntry(url))
            )
        )
        
        val json = gson.toJson(request)
        Log.d(TAG, "Request body created with ${json.length} characters")
        return json
    }
    
    /**
     * Extracts URLs from an SMS message
     * 
     * @param message The SMS message to scan
     * @return List of URLs found in the message
     */
    fun extractUrlsFromMessage(message: String): List<String> {
        Log.d(TAG, "Extracting URLs from message: '${message.take(50)}${if (message.length > 50) "..." else ""}'")
        // Use the centralized URL extraction method from SuspiciousUrlPatterns
        val urls = com.zrelxr06.malwirus.data.SuspiciousUrlPatterns.extractUrls(message)
        Log.d(TAG, "Found ${urls.size} URLs in message using SuspiciousUrlPatterns: $urls")
        return urls
    }
}

/**
 * Result of a safe browsing check
 */
data class SafeBrowsingResult(
    val isSafe: Boolean,
    val threats: List<ThreatInfo>,
    val error: String? = null
)

/**
 * Information about a detected threat
 */
data class ThreatInfo(
    val type: String,
    val platform: String,
    val url: String
)

/**
 * Request model for the Safe Browsing API
 */
data class SafeBrowsingRequest(
    val client: ClientInfo,
    val threatInfo: ThreatInfoRequest
)

data class ClientInfo(
    val clientId: String,
    val clientVersion: String
)

data class ThreatInfoRequest(
    val threatTypes: List<String>,
    val platformTypes: List<String>,
    val threatEntryTypes: List<String>,
    val threatEntries: List<ThreatEntry>
)

data class ThreatEntry(
    val url: String
)

/**
 * Response model from the Safe Browsing API
 */
data class SafeBrowsingApiResponse(
    val matches: List<MatchInfo> = emptyList()
)

data class MatchInfo(
    @SerializedName("threatType")
    val threatType: String,
    
    @SerializedName("platformType")
    val platformType: String,
    
    @SerializedName("threat")
    val threat: ThreatEntryInfo
)

data class ThreatEntryInfo(
    @SerializedName("url")
    val url: String
)
