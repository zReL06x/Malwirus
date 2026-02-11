package com.zrelxr06.malwirus.sms_security

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtLoggingLevel
import ai.onnxruntime.OrtSession
import android.annotation.SuppressLint
import android.util.Log
import com.zrelxr06.malwirus.MainActivity

class SmsModel(private val context: Context) {
    private val TAG = "SmsModel"
    private val ortEnvironment: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val ortSession: OrtSession = createORTsession(ortEnvironment)

    // Local log helpers gated by session-scoped debug flag
    private inline fun logD(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.d(TAG, msg) }
    private inline fun logI(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.i(TAG, msg) }
    private inline fun logE(msg: String) { if (MainActivity.DEBUG_LOGS_ENABLED) Log.e(TAG, msg) }

    // Create ORT session by reading model from assets
    private fun createORTsession(ortEnv: OrtEnvironment): OrtSession {
        try {
            val modelBytes = context.assets.open("malwirus_model.onnx").readBytes()
            return ortEnv.createSession(modelBytes)
        } catch (e: Exception) {
            logE("Error creating ORT session: ${e.message}")
            throw e
        }
    }

    // Run prediction using ONNX model
    @SuppressLint("DefaultLocale")
    fun runPrediction(input: String): Array<String> {
        val inputName = ortSession.inputNames?.iterator()?.next()
            ?: throw IllegalStateException("Input name not found")

        // Encode the string into an array of strings for the input tensor
        val inputData = arrayOf(input)
        val inputTensor = OnnxTensor.createTensor(ortEnvironment, inputData, longArrayOf(1))

        val options = OrtSession.RunOptions().apply {
            logLevel = OrtLoggingLevel.ORT_LOGGING_LEVEL_VERBOSE
        }

        // Run inference
        val results = ortSession.run(mapOf(inputName to inputTensor), options)

        results.forEach { entry ->
            logI("Output Name: ${entry.key}")
            logI("Raw Output Value: ${entry.value}")
        }

        val rawLabel = results[0].value
        val rawConfidence = results[1].value

        val labelOutput = (rawLabel as? Array<String>)?.contentDeepToString() ?: "invalid format"
        val confidenceOutput = when (rawConfidence) {
            is Array<*> -> rawConfidence.contentDeepToString()
            is FloatArray -> rawConfidence.contentToString()
            else -> "Invalid data format"
        }

        val output = arrayOf(labelOutput, confidenceOutput)
        // Cleanup
        inputTensor.close()
        results.close()

        // Return the predicted value as array containing label and confidence
        logD("Model Output: $output")
        return output
    }

    fun predictMessage(message: String): Array<String> {
        return try {
            logD("Predicting message")
            runPrediction(message)
        } catch (e: Exception) {
            logE("Error predicting message: ${e.message}")
            arrayOf("[ham]", "[[0.9, 0.1]]") // Default to ham with high confidence if model fails
        }
    }

    /**
     * Detect if a message is spam
     * This is an alias for predictMessage to maintain compatibility
     */
    fun detectSpam(message: String): String {
        val result = predictMessage(message)
        return result[1] // Return the confidence values as a string
    }

    // Close the session when no longer needed
    fun close() {
        try {
            ortSession.close()
            ortEnvironment.close()
        } catch (e: Exception) {
            logE("Error closing ORT session: ${e.message}")
        }
    }
}
