package com.zrelxr06.malwirus.history

import android.content.Context
import android.util.Log
import com.google.gson.Gson

class HistoryHandler(private val context: Context) {
    private val TAG = "HistoryManager"
    private val HISTORY_KEY = "sms_history"
    private val gson = Gson()

    fun getHistory(): List<SmsHistoryEntry> {
        val prefs = context.getSharedPreferences("sms_security_history", Context.MODE_PRIVATE)
        val json = prefs.getString(HISTORY_KEY, "[]")
        return try {
            val arr = gson.fromJson(json, Array<SmsHistoryEntry>::class.java)
            arr?.toList() ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Error getting history: ${e.message}")
            emptyList()
        }
    }

    fun addEntry(entry: SmsHistoryEntry) {
        try {
            val history = getHistory().toMutableList()

            // Check if an entry with the same ID already exists
            val existingIndex = history.indexOfFirst { it.id == entry.id }
            if (existingIndex >= 0) {
                // Replace existing entry
                history[existingIndex] = entry
            } else {
                // Add new entry
                history.add(0, entry) // Add at the beginning for newest first

                // Limit history size to prevent excessive storage use
                if (history.size > 100) {
                    history.removeAt(history.size - 1)
                }
            }

            // Save updated history
            saveHistory(history)
        } catch (e: Exception) {
            Log.e(TAG, "Error adding history entry: ${e.message}")
        }
    }

    fun clearHistory() {
        saveHistory(emptyList())
    }

    private fun saveHistory(history: List<SmsHistoryEntry>) {
        try {
            val json = gson.toJson(history)
            val prefs = context.getSharedPreferences("sms_security_history", Context.MODE_PRIVATE)
            prefs.edit().putString(HISTORY_KEY, json).apply()
        } catch (e: Exception) {
            Log.e(TAG, "Error saving history: ${e.message}")
        }
    }
}
