package com.militant.militant_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.net.HttpURLConnection
import java.net.URL

object IncomingCallNotificationHelper {
    private const val CALLS_CHANNEL_ID = "calls_v2"
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val PREF_TOKEN = "flutter.api_token"
    private const val PREF_BASE_URL = "flutter.base_url"
    private const val PREF_TOKEN_LEGACY = "api_token"
    private const val PREF_BASE_URL_LEGACY = "base_url"

    fun showIncomingCallNotification(
        context: Context,
        payload: Map<String, Any?>
    ) {
        val callId = payload["callId"]?.toString()
            ?: payload["call_id"]?.toString()
            ?: return

        ensureCallsChannel(context)

        val callerName = payload["callerName"]?.toString()
            ?: payload["caller_name"]?.toString()
            ?: "Appel entrant"
        val callerAvatar = payload["callerAvatar"]?.toString()
            ?: payload["caller_avatar"]?.toString()
        val groupId = payload["groupId"]?.toString()
            ?: payload["group_id"]?.toString()
        val groupName = payload["groupName"]?.toString()
            ?: payload["group_name"]?.toString()
        val roomToken = payload["roomToken"]?.toString()
            ?: payload["room_token"]?.toString()
        val isVideo = when (val value = payload["isVideo"] ?: payload["is_video"]) {
            is Boolean -> value
            else -> value?.toString() == "true"
        }
        val isGroupCall = when (val value = payload["is_group_call"] ?: payload["isGroupCall"]) {
            is Boolean -> value
            else -> value?.toString() == "true" || value?.toString() == "1" || !groupId.isNullOrBlank()
        }
        val notificationId = callId.hashCode()
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val token = payload["token"]?.toString().takeUnless { it.isNullOrBlank() }
            ?: readPrefValue(prefs, PREF_TOKEN, PREF_TOKEN_LEGACY)
        val baseUrl = payload["baseUrl"]?.toString().takeUnless { it.isNullOrBlank() }
            ?: readPrefValue(prefs, PREF_BASE_URL, PREF_BASE_URL_LEGACY)

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", payload["type"]?.toString() ?: "call")
            putExtra("call_id", callId)
            putExtra("caller_id", payload["callerId"]?.toString() ?: payload["caller_id"]?.toString())
            putExtra("caller_name", callerName)
            putExtra("caller_avatar", callerAvatar)
            putExtra("call_type", if (isVideo) "video" else "audio")
            putExtra("is_video", isVideo)
            putExtra("offer_sdp", payload["offerSdp"]?.toString() ?: payload["offer_sdp"]?.toString())
            putExtra("is_group_call", isGroupCall)
            putExtra("group_id", groupId)
            putExtra("group_name", groupName)
            putExtra("room_token", roomToken)
        }

        val openPendingIntent = PendingIntent.getActivity(
            context,
            notificationId,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val acceptIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("type", payload["type"]?.toString() ?: "call")
            putExtra("notification_action", "accept")
            putExtra("notification_id", notificationId)
            putExtra("call_id", callId)
            putExtra("caller_id", payload["callerId"]?.toString() ?: payload["caller_id"]?.toString())
            putExtra("caller_name", callerName)
            putExtra("caller_avatar", callerAvatar)
            putExtra("call_type", if (isVideo) "video" else "audio")
            putExtra("is_video", isVideo)
            putExtra("offer_sdp", payload["offerSdp"]?.toString() ?: payload["offer_sdp"]?.toString())
            putExtra("is_group_call", isGroupCall)
            putExtra("group_id", groupId)
            putExtra("group_name", groupName)
            putExtra("room_token", roomToken)
        }

        val acceptPendingIntent = PendingIntent.getActivity(
            context,
            notificationId + 1,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val declineIntent = Intent(context, CallActionReceiver::class.java).apply {
            action = CallActionReceiver.ACTION_DECLINE
            putExtra(CallActionReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra("call_id", callId)
            putExtra("is_group_call", isGroupCall)
            putExtra("group_id", groupId)
            putExtra("group_name", groupName)
            putExtra(CallActionReceiver.EXTRA_TOKEN, token)
            putExtra(CallActionReceiver.EXTRA_BASE_URL, baseUrl)
        }

        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 2,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        Thread {
            val avatarBitmap = loadBitmapFromUrl(resolveAvatarUrl(context, callerAvatar))
            val notification = NotificationCompat.Builder(context, CALLS_CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_militant)
                .setContentTitle(if (isGroupCall && !groupName.isNullOrBlank()) groupName else callerName)
                .setContentText(
                    when {
                        isGroupCall && isVideo -> callerName.ifBlank { "Appel vidéo de groupe" }
                        isGroupCall -> callerName.ifBlank { "Appel audio de groupe" }
                        isVideo -> "Appel vidéo entrant"
                        else -> "Appel audio entrant"
                    }
                )
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setOngoing(true)
                .setAutoCancel(false)
                .setContentIntent(openPendingIntent)
                .setFullScreenIntent(openPendingIntent, true)
                .setTimeoutAfter(45_000L)
                .apply {
                    if (avatarBitmap != null) {
                        setLargeIcon(avatarBitmap)
                    }
                }
                .addAction(
                    NotificationCompat.Action.Builder(
                        R.drawable.ic_stat_militant,
                        "Refuser",
                        declinePendingIntent
                    ).build()
                )
                .addAction(
                    NotificationCompat.Action.Builder(
                        R.drawable.ic_stat_militant,
                        if (isGroupCall) "Rejoindre" else "Repondre",
                        acceptPendingIntent
                    ).build()
                )
                .build()

            try {
                NotificationManagerCompat.from(context).notify(notificationId, notification)
            } catch (e: SecurityException) {
                e.printStackTrace()
            }
        }.start()
    }

    private fun ensureCallsChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
            ?: return

        val existing = manager.getNotificationChannel(CALLS_CHANNEL_ID)
        if (existing != null) return

        // Supprimer l'ancien canal sans son (si existant)
        try {
            manager.deleteNotificationChannel("calls")
        } catch (_: Exception) {
            // Ignorer si le canal n'existe pas
        }

        val channel = NotificationChannel(
            CALLS_CHANNEL_ID,
            "Appels",
            NotificationManager.IMPORTANCE_MAX
        ).apply {
            description = "Appels audio et vidéo entrants"
            enableVibration(true)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            // Activer le son d'appel (sonnerie)
            setSound(
                android.provider.Settings.System.DEFAULT_RINGTONE_URI,
                android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
        }

        manager.createNotificationChannel(channel)
    }

    private fun loadBitmapFromUrl(rawUrl: String?): Bitmap? {
        val url = rawUrl?.trim()
        if (url.isNullOrEmpty() || !url.startsWith("http")) return null

        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            connection.connectTimeout = 5000
            connection.readTimeout = 5000
            connection.instanceFollowRedirects = true
            connection.doInput = true
            connection.connect()
            connection.inputStream.use { BitmapFactory.decodeStream(it) }
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveAvatarUrl(context: Context, rawPath: String?): String? {
        val path = rawPath?.trim()
        if (path.isNullOrEmpty()) return null
        if (path.startsWith("http")) return path

        var normalizedPath = path.removePrefix("/")
        if (!normalizedPath.contains("/")) {
            normalizedPath = if (normalizedPath.startsWith("avatar_")) {
                "uploads/$normalizedPath"
            } else {
                "uploads/$normalizedPath"
            }
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val rawBaseUrl = readPrefValue(prefs, PREF_BASE_URL, PREF_BASE_URL_LEGACY)
        val normalizedBaseUrl = normalizeBaseUrl(rawBaseUrl)
        val mainSiteUrl = mainSiteUrl(normalizedBaseUrl)

        return "$mainSiteUrl/$normalizedPath"
    }

    private fun normalizeBaseUrl(input: String): String {
        var url = input.trim()
        if (url.isEmpty()) {
            return "https://api.militant.revlibertaire.com"
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            url = "https://$url"
        }
        return url.removeSuffix("/")
    }

    private fun mainSiteUrl(baseUrl: String): String {
        val uri = URL(baseUrl).toURI()
        var host = uri.host ?: "militant.revlibertaire.com"
        if (host.startsWith("api.")) {
            host = host.removePrefix("api.")
        }

        var path = uri.path ?: ""
        path = path.replace(Regex("/api(?:/v\\d+)?/?$"), "")
        if (path == "/") {
            path = ""
        }

        val portPart = if (uri.port != -1) ":${uri.port}" else ""
        return "${uri.scheme}://$host$portPart$path".removeSuffix("/")
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
}
