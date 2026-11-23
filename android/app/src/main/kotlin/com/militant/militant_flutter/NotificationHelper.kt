package com.militant.militant_flutter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput
import kotlin.random.Random

/**
 * Helper partagé pour la création des canaux et l'affichage des notifications Android
 * (utilisé par MainActivity et par NtfyForegroundService).
 */
object NotificationHelper {
    const val CHANNEL_MESSAGES = "messages_v2"
    const val CHANNEL_CALLS = "calls_v2"
    const val CHANNEL_NTFY_SERVICE = "ntfy_service_v1"

    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Supprimer les anciens canaux sans son (si existants)
        try {
            notificationManager.deleteNotificationChannel("messages")
            notificationManager.deleteNotificationChannel("calls")
        } catch (_: Exception) {
        }

        val messagesChannel = NotificationChannel(
            CHANNEL_MESSAGES,
            "Messages",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Messages privés et de groupe"
            enableVibration(true)
            setShowBadge(true)
            setSound(
                Settings.System.DEFAULT_NOTIFICATION_URI,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
        }

        val callsChannel = NotificationChannel(
            CHANNEL_CALLS,
            "Appels",
            NotificationManager.IMPORTANCE_MAX
        ).apply {
            description = "Appels audio et vidéo entrants"
            enableVibration(true)
            setShowBadge(false)
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setSound(
                Settings.System.DEFAULT_RINGTONE_URI,
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
        }

        val serviceChannel = NotificationChannel(
            CHANNEL_NTFY_SERVICE,
            "Service de notifications",
            NotificationManager.IMPORTANCE_MIN
        ).apply {
            description = "Maintient la réception des notifications en arrière-plan"
            enableVibration(false)
            setShowBadge(false)
            setSound(null, null)
        }

        notificationManager.createNotificationChannel(messagesChannel)
        notificationManager.createNotificationChannel(callsChannel)
        notificationManager.createNotificationChannel(serviceChannel)
    }

    fun showReplyableNotification(
        context: Context,
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
        createNotificationChannels(context)
        val notificationId = if (isGroup) groupId + 5000 else senderId + 1000
        val requestCode = Random.nextInt(100000)

        val remoteInput = RemoteInput.Builder(ReplyReceiver.KEY_REPLY_TEXT)
            .setLabel("Répondre à $conversationName...")
            .build()

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("senderId", senderId)
            putExtra("groupId", groupId)
            putExtra("isGroup", isGroup)
            putExtra("conversationName", conversationName)
            if (!avatar.isNullOrBlank()) {
                putExtra("avatar", avatar)
            }
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val replyIntent = Intent(context, ReplyReceiver::class.java).apply {
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
            context,
            requestCode + 1,
            replyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        val replyAction = NotificationCompat.Action.Builder(
            R.drawable.ic_stat_militant,
            "Répondre",
            replyPendingIntent
        ).addRemoteInput(remoteInput).build()

        val notification = NotificationCompat.Builder(context, CHANNEL_MESSAGES)
            .setSmallIcon(R.drawable.ic_stat_militant)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .addAction(replyAction)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }

    fun showGeneralNotification(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
        channelId: String = CHANNEL_MESSAGES,
        payload: Map<String, Any?> = emptyMap()
    ) {
        createNotificationChannels(context)
        val requestCode = Random.nextInt(100000)
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            for ((key, value) in payload) {
                when (value) {
                    is Int -> putExtra(key, value)
                    is Long -> putExtra(key, value)
                    is Boolean -> putExtra(key, value)
                    is Double -> putExtra(key, value)
                    else -> putExtra(key, value?.toString())
                }
            }
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            requestCode,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_stat_militant)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(openPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        try {
            NotificationManagerCompat.from(context).notify(notificationId, notification)
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }
}
