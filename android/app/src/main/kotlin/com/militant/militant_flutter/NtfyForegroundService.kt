package com.militant.militant_flutter

import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import kotlin.math.min
import kotlin.random.Random

/**
 * Service persistant Android maintenant une connexion WebSocket vers le serveur ntfy
 * auto-hébergé, même lorsque l'application est fermée ou en arrière-plan.
 */
class NtfyForegroundService : Service() {

    companion object {
        private const val TAG = "NtfyForegroundService"
        private const val PREFS_NAME = "militant_ntfy_service_prefs"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_SERVER_URL = "server_url"
        private const val KEY_TOPIC = "topic"
        private const val KEY_AUTH_TOKEN = "auth_token"
        private const val KEY_API_BASE_URL = "api_base_url"
        private const val KEY_LAST_EVENT_TIME = "last_event_time"
        private const val FOREGROUND_NOTIFICATION_ID = 42001
        private const val MAX_SEEN_IDS = 200

        fun start(
            context: Context,
            serverUrl: String,
            topic: String,
            authToken: String,
            apiBaseUrl: String
        ) {
            val cleanServer = serverUrl.trim().trimEnd('/')
            val cleanTopic = topic.trim()
            if (cleanServer.isEmpty() || cleanTopic.isEmpty()) return

            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_ENABLED, true)
                .putString(KEY_SERVER_URL, cleanServer)
                .putString(KEY_TOPIC, cleanTopic)
                .putString(KEY_AUTH_TOKEN, authToken)
                .putString(KEY_API_BASE_URL, apiBaseUrl)
                .apply()

            val intent = Intent(context, NtfyForegroundService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }

        fun startFromSavedPrefs(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            if (!prefs.getBoolean(KEY_ENABLED, false)) return
            val serverUrl = prefs.getString(KEY_SERVER_URL, "")?.trim().orEmpty()
            val topic = prefs.getString(KEY_TOPIC, "")?.trim().orEmpty()
            if (serverUrl.isEmpty() || topic.isEmpty()) return

            val intent = Intent(context, NtfyForegroundService::class.java)
            try {
                ContextCompat.startForegroundService(context, intent)
            } catch (e: Exception) {
                Log.w(TAG, "Impossible de démarrer le service au boot: ${e.message}")
            }
        }

        fun stop(context: Context) {
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                .putBoolean(KEY_ENABLED, false)
                .apply()
            context.stopService(Intent(context, NtfyForegroundService::class.java))
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val seenIds = LinkedHashSet<String>()
    private val httpClient = OkHttpClient.Builder()
        .pingInterval(30, TimeUnit.SECONDS)
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .retryOnConnectionFailure(true)
        .build()

    private var webSocket: WebSocket? = null
    private var isConnecting = false
    private var isStopping = false
    private var retryAttempt = 0
    private var currentServerUrl = ""
    private var currentTopic = ""
    private var currentAuthToken = ""
    private var currentApiBaseUrl = ""
    private var connectivityManager: ConnectivityManager? = null
    private var networkCallback: ConnectivityManager.NetworkCallback? = null

    private val reconnectRunnable = Runnable {
        if (!isStopping) {
            connectWebSocket()
        }
    }

    override fun onCreate() {
        super.onCreate()
        NotificationHelper.createNotificationChannels(this)
        registerNetworkCallback()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startAsForeground()

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val enabled = prefs.getBoolean(KEY_ENABLED, false)
        val serverUrl = prefs.getString(KEY_SERVER_URL, "")?.trim().orEmpty()
        val topic = prefs.getString(KEY_TOPIC, "")?.trim().orEmpty()

        if (!enabled || serverUrl.isEmpty() || topic.isEmpty()) {
            stopSelf()
            return START_NOT_STICKY
        }

        val authToken = prefs.getString(KEY_AUTH_TOKEN, "").orEmpty()
        val apiBaseUrl = prefs.getString(KEY_API_BASE_URL, "").orEmpty()

        val targetChanged = serverUrl != currentServerUrl || topic != currentTopic
        currentServerUrl = serverUrl
        currentTopic = topic
        currentAuthToken = authToken
        currentApiBaseUrl = apiBaseUrl
        isStopping = false

        if (targetChanged || (webSocket == null && !isConnecting)) {
            retryAttempt = 0
            mainHandler.removeCallbacks(reconnectRunnable)
            closeWebSocket()
            connectWebSocket()
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        isStopping = true
        mainHandler.removeCallbacks(reconnectRunnable)
        unregisterNetworkCallback()
        closeWebSocket()
        super.onDestroy()
    }

    private fun startAsForeground() {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, NotificationHelper.CHANNEL_NTFY_SERVICE)
            .setSmallIcon(R.drawable.ic_stat_militant)
            .setContentTitle("Militant")
            .setContentText("Réception des notifications active")
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .setShowWhen(false)
            .setContentIntent(pendingIntent)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                FOREGROUND_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_REMOTE_MESSAGING
            )
        } else {
            startForeground(FOREGROUND_NOTIFICATION_ID, notification)
        }
    }

    private fun buildWebSocketUrl(): String {
        val wsBase = when {
            currentServerUrl.startsWith("https://") ->
                "wss://" + currentServerUrl.removePrefix("https://")
            currentServerUrl.startsWith("http://") ->
                "ws://" + currentServerUrl.removePrefix("http://")
            else -> "wss://$currentServerUrl"
        }.trimEnd('/')

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val lastEventTime = prefs.getLong(KEY_LAST_EVENT_TIME, 0L)
        return if (lastEventTime > 0L) {
            "$wsBase/$currentTopic/ws?since=$lastEventTime"
        } else {
            "$wsBase/$currentTopic/ws"
        }
    }

    private fun connectWebSocket() {
        if (isStopping || isConnecting || currentServerUrl.isEmpty() || currentTopic.isEmpty()) {
            return
        }

        isConnecting = true
        val url = buildWebSocketUrl()
        Log.d(TAG, "Connexion WebSocket ntfy: $url")

        val request = Request.Builder()
            .url(url)
            .header("User-Agent", "Militant-Android-Service/1.0")
            .build()

        webSocket = httpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                isConnecting = false
                retryAttempt = 0
                Log.d(TAG, "WebSocket ntfy connecté ($currentTopic)")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleEventLine(text)
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                isConnecting = false
                this@NtfyForegroundService.webSocket = null
                if (!isStopping) {
                    scheduleReconnect()
                }
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                isConnecting = false
                this@NtfyForegroundService.webSocket = null
                Log.w(TAG, "Erreur WebSocket ntfy: ${t.message}")
                if (!isStopping) {
                    scheduleReconnect()
                }
            }
        })
    }

    private fun closeWebSocket() {
        isConnecting = false
        try {
            webSocket?.close(1000, "Service stopped")
        } catch (_: Exception) {
        }
        webSocket = null
    }

    private fun scheduleReconnect() {
        if (isStopping) return
        retryAttempt++
        val delaySec = min(retryAttempt * 2, 30)
        mainHandler.removeCallbacks(reconnectRunnable)
        mainHandler.postDelayed(reconnectRunnable, delaySec * 1000L)
    }

    private fun handleEventLine(rawText: String) {
        val trimmed = rawText.trim()
        if (trimmed.isEmpty()) return

        try {
            val json = JSONObject(trimmed)
            val eventTime = json.optLong("time", 0L)
            if (eventTime > 0L) {
                getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
                    .putLong(KEY_LAST_EVENT_TIME, eventTime)
                    .apply()
            }

            val event = json.optString("event", "")
            if (event != "message") return

            val id = json.optString("id", "")
            if (id.isNotEmpty()) {
                synchronized(seenIds) {
                    if (seenIds.contains(id)) return
                    seenIds.add(id)
                    if (seenIds.size > MAX_SEEN_IDS) {
                        val it = seenIds.iterator()
                        if (it.hasNext()) {
                            it.next()
                            it.remove()
                        }
                    }
                }
            }

            dispatchNtfyMessage(json)
        } catch (e: Exception) {
            Log.w(TAG, "Erreur décodage événement ntfy: ${e.message}")
        }
    }

    private fun dispatchNtfyMessage(rawEvent: JSONObject) {
        val title = rawEvent.optString("title", "Militant").ifBlank { "Militant" }
        val message = rawEvent.optString("message", "")
        val priority = rawEvent.optInt("priority", 3)

        val data = extractPayloadData(rawEvent, message)
        val type = data["type"]?.toString()?.trim().orEmpty()

        // Appels entrants audio / vidéo
        if (type == "call" || (priority == 5 && data.containsKey("call_id"))) {
            if (type == "call" || data.containsKey("call_id")) {
                IncomingCallNotificationHelper.showIncomingCallNotification(this, data)
                return
            }
        }

        // Messages privés et de groupe (avec réponse rapide inline)
        if (type == "message" || type == "group_message") {
            val isGroup = type == "group_message"
            val senderId = data["sender_id"]?.toString()?.toIntOrNull() ?: -1
            val groupId = data["group_id"]?.toString()?.toIntOrNull() ?: -1
            val senderName = data["username"]?.toString()?.takeIf { it.isNotBlank() } ?: title
            val groupName = data["group_name"]?.toString()?.takeIf { it.isNotBlank() } ?: title
            val conversationName = if (isGroup) groupName else senderName
            val avatar = data["avatar"]?.toString()
            val preview = data["message_preview"]?.toString()?.takeIf { it.isNotBlank() } ?: message

            val notifTitle = if (isGroup) "$groupName • $senderName" else senderName

            NotificationHelper.showReplyableNotification(
                context = this,
                title = notifTitle,
                body = preview,
                senderId = senderId,
                groupId = groupId,
                isGroup = isGroup,
                conversationName = conversationName,
                avatar = avatar,
                token = currentAuthToken,
                baseUrl = currentApiBaseUrl
            )
            return
        }

        // Autres notifications sociales (réactions, mentions, système...)
        NotificationHelper.showGeneralNotification(
            context = this,
            notificationId = Random.nextInt(100000),
            title = title,
            body = message,
            channelId = NotificationHelper.CHANNEL_MESSAGES,
            payload = data
        )
    }

    private fun extractPayloadData(rawEvent: JSONObject, message: String): HashMap<String, Any?> {
        val data = hashMapOf<String, Any?>()

        val actions = rawEvent.optJSONArray("actions")
        if (actions != null && actions.length() > 0) {
            val firstAction = actions.optJSONObject(0)
            val extras = firstAction?.optJSONObject("extras")
            if (extras != null) {
                copyJsonToMap(extras, data)
            }
        }

        if (data.isEmpty()) {
            val nestedData = rawEvent.optJSONObject("data")
            if (nestedData != null) {
                copyJsonToMap(nestedData, data)
            }
        }

        if (data.isEmpty() && message.startsWith("{") && message.endsWith("}")) {
            try {
                copyJsonToMap(JSONObject(message), data)
            } catch (_: Exception) {
            }
        }

        return data
    }

    private fun copyJsonToMap(source: JSONObject, target: HashMap<String, Any?>) {
        val keys = source.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            val value = source.opt(key)
            target[key] = if (value == JSONObject.NULL) null else value
        }
    }

    private fun registerNetworkCallback() {
        try {
            val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return
            connectivityManager = cm
            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    if (!isStopping && webSocket == null && !isConnecting) {
                        retryAttempt = 0
                        mainHandler.removeCallbacks(reconnectRunnable)
                        mainHandler.post { connectWebSocket() }
                    }
                }
            }
            val request = NetworkRequest.Builder()
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()
            cm.registerNetworkCallback(request, callback)
            networkCallback = callback
        } catch (e: Exception) {
            Log.w(TAG, "Impossible d'enregistrer NetworkCallback: ${e.message}")
        }
    }

    private fun unregisterNetworkCallback() {
        try {
            val cb = networkCallback ?: return
            connectivityManager?.unregisterNetworkCallback(cb)
            networkCallback = null
        } catch (_: Exception) {
        }
    }
}
