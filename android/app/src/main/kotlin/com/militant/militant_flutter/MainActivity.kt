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
    private var notifChannel: MethodChannel? = null
    private var pendingIncomingCallPayload: HashMap<String, Any?>? = null
    private var pendingMessageNotificationPayload: HashMap<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Enforce edge-to-edge for Android 15+ (API 35+)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        super.onCreate(savedInstanceState)
        pendingIncomingCallPayload = extractIncomingCallPayload(intent)
        pendingMessageNotificationPayload = extractMessageNotificationPayload(intent)
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

        // Canal Notifications (réponse rapide & clics sur notification)
        notifChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
        notifChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialMessageNotification" -> {
                    val payload = pendingMessageNotificationPayload ?: extractMessageNotificationPayload(intent)
                    pendingMessageNotificationPayload = null
                    result.success(payload)
                }
                "showReplyNotification" -> {
                    val title = call.argument<String>("title") ?: "Nouveau message"
                    val body = call.argument<String>("body") ?: ""
                    val senderId = call.argument<Int>("senderId") ?: -1
                    val groupId = call.argument<Int>("groupId") ?: -1
                    val isGroup = call.argument<Boolean>("isGroup") ?: false
                    val conversationName = call.argument<String>("conversationName") ?: title
                    val avatar = call.argument<String>("avatar")
                    val token = call.argument<String>("token") ?: ""
                    val baseUrl = call.argument<String>("baseUrl") ?: ""

                    showReplyableNotification(
                        title = title,
                        body = body,
                        senderId = senderId,
                        groupId = groupId,
                        isGroup = isGroup,
                        conversationName = conversationName,
                        avatar = avatar,
                        token = token,
                        baseUrl = baseUrl
                    )
                    result.success(null)
                }
                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: Random.nextInt(100000)
                    val title = call.argument<String>("title") ?: "Militant"
                    val body = call.argument<String>("body") ?: ""
                    val channelId = call.argument<String>("channelId") ?: "messages_v2"
                    val rawPayload = call.argument<Map<*, *>>("payload")
                    val payload = rawPayload?.entries?.associate { (k, v) ->
                        k.toString() to v
                    } ?: emptyMap()

                    showGeneralNotification(id, title, body, channelId, payload)
                    result.success(null)
                }
                "startNtfyService" -> {
                    val serverUrl = call.argument<String>("serverUrl") ?: ""
                    val topic = call.argument<String>("topic") ?: ""
                    val token = call.argument<String>("token") ?: ""
                    val baseUrl = call.argument<String>("baseUrl") ?: ""
                    NtfyForegroundService.start(this, serverUrl, topic, token, baseUrl)
                    result.success(null)
                }
                "stopNtfyService" -> {
                    NtfyForegroundService.stop(this)
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

        // An incoming-call intent also contains generic notification fields such
        // as `type` and `group_id`. Route calls before messages, otherwise the
        // message bridge consumes the Accept/Join action and Flutter never opens
        // the call screen.
        val callPayload = extractIncomingCallPayload(intent)
        if (callPayload != null) {
            cancelIncomingCallNotification(intent)
            pendingIncomingCallPayload = callPayload
            applyIncomingCallWindowFlags(callPayload)
            callsChannel?.invokeMethod("incomingCallIntent", callPayload)
            return
        }

        val messagePayload = extractMessageNotificationPayload(intent) ?: return
        pendingMessageNotificationPayload = messagePayload
        notifChannel?.invokeMethod("messageNotificationClicked", messagePayload)
    }

    private fun createNotificationChannels() {
        NotificationHelper.createNotificationChannels(this)
    }

    private fun showReplyableNotification(
        title: String,
        body: String,
        senderId: Int,
        groupId: Int,
        isGroup: Boolean,
        conversationName: String,
        avatar: String? = null,
        token: String,
        baseUrl: String
    ) {
        NotificationHelper.showReplyableNotification(
            context = this,
            title = title,
            body = body,
            senderId = senderId,
            groupId = groupId,
            isGroup = isGroup,
            conversationName = conversationName,
            avatar = avatar,
            token = token,
            baseUrl = baseUrl
        )
    }

    private fun showGeneralNotification(
        notificationId: Int,
        title: String,
        body: String,
        channelId: String,
        payload: Map<String, Any?>
    ) {
        NotificationHelper.showGeneralNotification(
            context = this,
            notificationId = notificationId,
            title = title,
            body = body,
            channelId = channelId,
            payload = payload
        )
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

    private fun extractMessageNotificationPayload(intent: Intent?): HashMap<String, Any?>? {
        val extras = intent?.extras ?: return null
        val payload = hashMapOf<String, Any?>()

        for (key in extras.keySet()) {
            val value = extras.get(key)
            if (value != null) {
                payload[key] = normalizeIntentValue(value)
            }
            if (value is String && (key == "onesignalData" || key == "custom")) {
                mergeCallPayloadFromJson(value, payload)
            }
        }

        val senderId = extras.getInt("senderId", -1)
        val groupId = extras.getInt("groupId", -1)
        val isGroup = extras.getBoolean("isGroup", false)
        val conversationName = extras.getString("conversationName")

        if (senderId != -1) {
            payload["sender_id"] = senderId.toString()
        }
        if (groupId != -1) {
            payload["group_id"] = groupId.toString()
        }
        if (isGroup) {
            payload["type"] = "group_message"
        }
        if (!conversationName.isNullOrBlank()) {
            payload["conversationName"] = conversationName
        }

        // Call intents must only be handled by the calls MethodChannel. Without
        // this guard, their `type`/`group_id` fields make them look like message
        // notifications and the Join/Accept action appears to do nothing.
        val type = payload["type"]?.toString()
        val isIncomingCall =
            type == "call" ||
                type == "talk_invite" ||
                payload.containsKey("call_id") ||
                payload.containsKey("room_token")
        if (isIncomingCall) {
            return null
        }

        val hasType = payload.containsKey("type")
        val hasPost = payload.containsKey("post_id") || payload.containsKey("postId")
        val hasSender = payload.containsKey("sender_id") || payload.containsKey("senderId") || payload.containsKey("user_id")
        val hasGroup = payload.containsKey("group_id") || payload.containsKey("groupId")
        val hasLink = payload.containsKey("link") || payload.containsKey("url")

        if (hasType || hasPost || hasSender || hasGroup || hasLink) {
            return payload
        }

        return null
    }
}
