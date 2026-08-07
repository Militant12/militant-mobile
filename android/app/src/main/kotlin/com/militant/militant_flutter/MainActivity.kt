package com.militant.militant_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import kotlin.random.Random

class MainActivity : FlutterActivity() {
    private val TWA_CHANNEL = "com.militant.militant_flutter/twa"
    private val NOTIF_CHANNEL = "com.militant.militant_flutter/notifications"
    private val CALLS_CHANNEL = "com.militant.militant_flutter/calls"
    private var callsChannel: MethodChannel? = null
    private var pendingIncomingCallPayload: HashMap<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Enforce edge-to-edge for Android 15+ (API 35+)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        super.onCreate(savedInstanceState)
        pendingIncomingCallPayload = extractIncomingCallPayload(intent)
        cancelIncomingCallNotification(intent)
        applyIncomingCallWindowFlags(pendingIncomingCallPayload)
    }



    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Créer les canaux de notification Android
        createNotificationChannels()

        // Canal TWA
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TWA_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "launchTWA") {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        launchTrustedWebActivity(url)
                        result.success(null)
                    } else {
                        result.error("INVALID_URL", "URL is required", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Canal Notifications (réponse rapide)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "showReplyNotification" -> {
                        val title = call.argument<String>("title") ?: "Nouveau message"
                        val body = call.argument<String>("body") ?: ""
                        val senderId = call.argument<Int>("senderId") ?: -1
                        val groupId = call.argument<Int>("groupId") ?: -1
                        val isGroup = call.argument<Boolean>("isGroup") ?: false
                        val conversationName = call.argument<String>("conversationName") ?: title
                        val token = call.argument<String>("token") ?: ""
                        val baseUrl = call.argument<String>("baseUrl") ?: ""

                        showReplyableNotification(
                            title = title,
                            body = body,
                            senderId = senderId,
                            groupId = groupId,
                            isGroup = isGroup,
                            conversationName = conversationName,
                            token = token,
                            baseUrl = baseUrl
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        callsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CALLS_CHANNEL)
        callsChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "showIncomingCall" -> {
                    val rawPayload = call.arguments as? Map<*, *>
                    val payload = rawPayload?.entries?.associate { (key, value) ->
                        key.toString() to value
                    }?.let { HashMap(it) }
                    if (payload != null) {
                        showIncomingCallNotification(payload)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Incoming call payload is required", null)
                    }
                }
                "endCall" -> {
                    val callId = call.argument<String>("callId")
                    if (!callId.isNullOrBlank()) {
                        NotificationManagerCompat.from(this).cancel(callId.hashCode())
                    }
                    result.success(null)
                }
                "endAllCalls" -> {
                    NotificationManagerCompat.from(this).cancelAll()
                    result.success(null)
                }
                "getInitialIncomingCallIntent" -> {
                    val payload = pendingIncomingCallPayload ?: extractIncomingCallPayload(intent)
                    pendingIncomingCallPayload = null
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        val payload = extractIncomingCallPayload(intent) ?: return
        cancelIncomingCallNotification(intent)
        pendingIncomingCallPayload = payload
        applyIncomingCallWindowFlags(payload)
        callsChannel?.invokeMethod("incomingCallIntent", payload)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // IMPORTANT : Les canaux ont été renommés pour forcer la recréation avec le son activé
            // Ancien canal "messages" -> nouveau "messages_v2"
            // Ancien canal "calls" -> nouveau "calls_v2"
            
            // Supprimer les anciens canaux sans son (si existants)
            try {
                notificationManager.deleteNotificationChannel("messages")
                notificationManager.deleteNotificationChannel("calls")
            } catch (_: Exception) {
                // Ignorer si les canaux n'existent pas
            }

            // Canal messages (priorité haute, avec réponse rapide) - VERSION 2 avec son
            val messagesChannel = NotificationChannel(
                "messages_v2",
                "Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Messages privés et de groupe"
                enableVibration(true)
                setShowBadge(true)
                // Activer le son par défaut
                setSound(
                    android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }

            // Canal appels (priorité maximale) - VERSION 2 avec son
            val callsChannel = NotificationChannel(
                "calls_v2",
                "Appels",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Appels audio et vidéo entrants"
                enableVibration(true)
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                // Activer le son d'appel (sonnerie)
                setSound(
                    android.provider.Settings.System.DEFAULT_RINGTONE_URI,
                    android.media.AudioAttributes.Builder()
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }

            notificationManager.createNotificationChannel(messagesChannel)
            notificationManager.createNotificationChannel(callsChannel)
        }
    }

    private fun showReplyableNotification(
        title: String,
        body: String,
        senderId: Int,
        groupId: Int,
        isGroup: Boolean,
        conversationName: String,
        token: String,
        baseUrl: String
    ) {
        val notificationId = if (isGroup) groupId + 5000 else senderId + 1000
        val requestCode = Random.nextInt(100000)

        // RemoteInput pour la réponse inline
        val remoteInput = RemoteInput.Builder(ReplyReceiver.KEY_REPLY_TEXT)
            .setLabel("Répondre à $conversationName...")
            .build()

        // Intent pour ouvrir l'app au clic
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("senderId", senderId)
            putExtra("groupId", groupId)
            putExtra("isGroup", isGroup)
        }
        val openPendingIntent = PendingIntent.getActivity(
            this,
            requestCode,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Intent pour la réponse rapide (BroadcastReceiver)
        val replyIntent = Intent(this, ReplyReceiver::class.java).apply {
            action = ReplyReceiver.ACTION_REPLY
            putExtra(ReplyReceiver.EXTRA_NOTIFICATION_ID, notificationId)
            putExtra(ReplyReceiver.EXTRA_SENDER_ID, senderId)
            putExtra(ReplyReceiver.EXTRA_GROUP_ID, groupId)
            putExtra(ReplyReceiver.EXTRA_IS_GROUP, isGroup)
            putExtra(ReplyReceiver.EXTRA_CONVERSATION_NAME, conversationName)
            putExtra(ReplyReceiver.EXTRA_TOKEN, token)
            putExtra(ReplyReceiver.EXTRA_BASE_URL, baseUrl)
        }
        val replyPendingIntent = PendingIntent.getBroadcast(
            this,
            requestCode + 1,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        // Action "Répondre"
        val replyAction = NotificationCompat.Action.Builder(
            R.drawable.ic_stat_militant,
            "Répondre",
            replyPendingIntent
        ).addRemoteInput(remoteInput).build()

        // Construire la notification
        val notification = NotificationCompat.Builder(this, "messages_v2")
            .setSmallIcon(R.drawable.ic_stat_militant)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .addAction(replyAction)           // ← Bouton "Répondre" inline
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .build()

        try {
            NotificationManagerCompat.from(this).notify(notificationId, notification)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    private fun launchTrustedWebActivity(url: String) {
        val builder = CustomTabsIntent.Builder()
        val customTabsIntent = builder.build()
        customTabsIntent.intent.data = Uri.parse(url)
        customTabsIntent.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        customTabsIntent.launchUrl(this, Uri.parse(url))
    }

    private fun showIncomingCallNotification(payload: HashMap<String, Any?>) {
        IncomingCallNotificationHelper.showIncomingCallNotification(this, payload)
    }

    private fun applyIncomingCallWindowFlags(payload: Map<String, Any?>?) {
        if (payload == null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }

    private fun extractIncomingCallPayload(intent: Intent?): HashMap<String, Any?>? {
        val extras = intent?.extras ?: return null
        val payload = hashMapOf<String, Any?>()

        val interestingKeys = setOf(
            "type",
            "notification_action",
            "notification_id",
            "call_id",
            "caller_id",
            "caller_name",
            "caller_avatar",
            "call_type",
            "is_video",
            "offer_sdp",
            "is_group_call",
            "group_id",
            "room_token",
            "group_name"
        )

        for (key in extras.keySet()) {
            val value = extras.get(key)
            if (interestingKeys.contains(key)) {
                payload[key] = normalizeIntentValue(value)
            }

            if (value is String && (key == "onesignalData" || key == "custom")) {
                mergeCallPayloadFromJson(value, payload)
            }
        }

        val type = payload["type"]?.toString()
        val hasCallId = !payload["call_id"]?.toString().isNullOrBlank()
        val hasRoomToken = !payload["room_token"]?.toString().isNullOrBlank()

        return if (type == "call" || type == "talk_invite" || hasCallId || hasRoomToken) {
            payload
        } else {
            null
        }
    }

    private fun mergeCallPayloadFromJson(rawJson: String, target: HashMap<String, Any?>) {
        try {
            flattenJsonObject(JSONObject(rawJson), target)
        } catch (_: Exception) {
        }
    }

    private fun flattenJsonObject(json: JSONObject, target: HashMap<String, Any?>) {
        val iterator = json.keys()
        while (iterator.hasNext()) {
            val key = iterator.next()
            val value = json.opt(key)
            when (value) {
                is JSONObject -> flattenJsonObject(value, target)
                is JSONArray -> {
                    // Ignore arrays for incoming-call routing.
                }
                else -> {
                    if (!target.containsKey(key)) {
                        target[key] = normalizeIntentValue(value)
                    }
                }
            }
        }
    }

    private fun normalizeIntentValue(value: Any?): Any? {
        return when (value) {
            is Boolean, is Int, is Long, is Double -> value
            else -> value?.toString()
        }
    }

    private fun cancelIncomingCallNotification(intent: Intent?) {
        val notificationId = intent?.getIntExtra("notification_id", -1) ?: -1
        if (notificationId == -1) return
        NotificationManagerCompat.from(this).cancel(notificationId)
    }
}
