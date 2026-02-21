package com.militant.militant_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.random.Random

class MainActivity : FlutterActivity() {
    private val TWA_CHANNEL = "com.militant.militant_flutter/twa"
    private val NOTIF_CHANNEL = "com.militant.militant_flutter/notifications"

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
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // Canal messages (priorité haute, avec réponse rapide)
            val messagesChannel = NotificationChannel(
                "messages",
                "Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Messages privés et de groupe"
                enableVibration(true)
                setShowBadge(true)
            }

            // Canal appels (priorité maximale)
            val callsChannel = NotificationChannel(
                "calls",
                "Appels",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Appels audio et vidéo entrants"
                enableVibration(true)
                setShowBadge(false)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
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
            R.mipmap.ic_launcher,
            "Répondre",
            replyPendingIntent
        ).addRemoteInput(remoteInput).build()

        // Construire la notification
        val notification = NotificationCompat.Builder(this, "messages")
            .setSmallIcon(R.mipmap.ic_launcher)
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
}
