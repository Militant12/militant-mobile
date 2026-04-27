package com.militant.militant_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

/**
 * Actions Android pour les notifications d'appel entrant.
 * - Repondre : ouvre l'app directement sur l'appel
 * - Refuser : annule la notif et synchronise le rejet avec l'API
 */
class CallActionReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_ACCEPT = "com.militant.militant_flutter.CALL_ACCEPT"
        const val ACTION_DECLINE = "com.militant.militant_flutter.CALL_DECLINE"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_TOKEN = "auth_token"
        const val EXTRA_BASE_URL = "base_url"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val PREF_TOKEN = "flutter.api_token"
        private const val PREF_BASE_URL = "flutter.base_url"
        private const val PREF_TOKEN_LEGACY = "api_token"
        private const val PREF_BASE_URL_LEGACY = "base_url"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        if (notificationId != -1) {
            NotificationManagerCompat.from(context).cancel(notificationId)
        }

        when (intent.action) {
            ACTION_ACCEPT -> handleAccept(context, intent)
            ACTION_DECLINE -> {
                val pendingResult = goAsync()
                handleDecline(context, intent, pendingResult)
            }
        }
    }

    private fun handleAccept(context: Context, intent: Intent) {
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP

            putExtra("type", intent.getStringExtra("type") ?: "call")
            putExtra("notification_action", "accept")
            putExtra("call_id", intent.getStringExtra("call_id"))
            putExtra("caller_id", intent.getStringExtra("caller_id"))
            putExtra("caller_name", intent.getStringExtra("caller_name"))
            putExtra("caller_avatar", intent.getStringExtra("caller_avatar"))
            putExtra("call_type", intent.getStringExtra("call_type"))
            putExtra("is_video", intent.getBooleanExtra("is_video", false))
            putExtra("offer_sdp", intent.getStringExtra("offer_sdp"))
            putExtra("is_group_call", intent.getBooleanExtra("is_group_call", false))
            putExtra("group_id", intent.getStringExtra("group_id"))
            putExtra("group_name", intent.getStringExtra("group_name"))
            putExtra("room_token", intent.getStringExtra("room_token"))
        }

        context.startActivity(openIntent)
    }

    private fun handleDecline(
        context: Context,
        intent: Intent,
        pendingResult: BroadcastReceiver.PendingResult
    ) {
        val callId = intent.getStringExtra("call_id")
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = intent.getStringExtra(EXTRA_TOKEN)
            ?.takeIf { it.isNotBlank() }
            ?: readPrefValue(prefs, PREF_TOKEN, PREF_TOKEN_LEGACY)
        val baseUrl = intent.getStringExtra(EXTRA_BASE_URL)
            ?.takeIf { it.isNotBlank() }
            ?: readPrefValue(prefs, PREF_BASE_URL, PREF_BASE_URL_LEGACY)
        if (callId.isNullOrBlank() || token.isNullOrBlank() || baseUrl.isNullOrBlank()) {
            pendingResult.finish()
            return
        }

        Thread {
            try {
                val normalizedBaseUrl = normalizeBaseUrl(baseUrl)
                val url = java.net.URL("$normalizedBaseUrl/v1/calls.php?action=reject")
                val connection = url.openConnection() as java.net.HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Accept", "application/json")
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.doOutput = true
                connection.connectTimeout = 10000
                connection.readTimeout = 10000

                val body = """{"call_id":${org.json.JSONObject.quote(callId)}}"""
                connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
                connection.responseCode
                connection.disconnect()
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                pendingResult.finish()
            }
        }.start()
    }

    private fun readPrefValue(
        prefs: android.content.SharedPreferences,
        primaryKey: String,
        fallbackKey: String
    ): String {
        return prefs.getString(primaryKey, null)
            ?.takeIf { it.isNotBlank() }
            ?: prefs.getString(fallbackKey, "").orEmpty()
    }

    private fun normalizeBaseUrl(input: String): String {
        var url = input.trim()
        if (url.isEmpty()) {
            return ""
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            url = "https://$url"
        }
        return url.removeSuffix("/")
    }
}
