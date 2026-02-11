package com.zrelxr06.malwirus.preference

import android.content.Context
import android.util.Log

/**
 * Manages app preferences in native code
 */
class PreferenceHandler(private val context: Context) {
    private val TAG = "PreferenceManager"

    /**
     * Get a boolean preference value
     */
    fun getBoolean(key: String, defaultValue: Boolean): Boolean {
        val prefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
        return prefs.getBoolean(key, defaultValue)
    }

    /**
     * Set a boolean preference value
     */
    fun setBoolean(key: String, value: Boolean) {
        val prefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
        prefs.edit().putBoolean(key, value).apply()
    }

    /**
     * Get a string preference value
     */
    fun getString(key: String, defaultValue: String): String {
        val prefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
        return prefs.getString(key, defaultValue) ?: defaultValue
    }

    /**
     * Set a string preference value
     */
    fun saveString(key: String, value: String) {
        val prefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
        prefs.edit().putString(key, value).apply()
    }

    /**
     * Get an integer preference value
     */
    fun getInt(key: String, defaultValue: Int): Int {
        val prefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
        return prefs.getInt(key, defaultValue)
    }

    /**
     * Set an integer preference value
     */
    fun setInt(key: String, value: Int) {
        val prefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
        prefs.edit().putInt(key, value).apply()
    }

    /**
     * Clear all preferences
     */
    fun clearAll() {
        val prefs = context.getSharedPreferences("app_preferences", Context.MODE_PRIVATE)
        prefs.edit().clear().apply()
        Log.d(TAG, "All preferences cleared")
    }
}
