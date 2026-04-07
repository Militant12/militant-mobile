package com.militant.militant_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput

/**
 * BroadcastReceiver pour la réponse rapide aux messages
 * depuis la notification Android (inline reply comme Signal/WhatsApp)
 */
class ReplyReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_REPLY = "com.militant.militant_flutter.REPLY_ACTION"
        const val KEY_REPLY_TEXT = "militant_reply_text"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
        const val EXTRA_SENDER_ID = "sender_id"
        const val EXTRA_GROUP_ID = "group_id"
        const val EXTRA_IS_GROUP = "is_group"
        const val EXTRA_CONVERSATION_NAME = "conversation_name"
        const val EXTRA_TOKEN = "auth_token"
        const val EXTRA_BASE_URL = "base_url"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_REPLY) return

        // Récupérer le texte saisi dans la réponse inline
        val remoteInput = RemoteInput.getResultsFromIntent(intent) ?: return
        val replyText = remoteInput.getCharSequence(KEY_REPLY_TEXT)?.toString()?.trim()
        if (replyText.isNullOrEmpty()) return

        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        val senderId = intent.getIntExtra(EXTRA_SENDER_ID, -1)
        val groupId = intent.getIntExtra(EXTRA_GROUP_ID, -1)
        val isGroup = intent.getBooleanExtra(EXTRA_IS_GROUP, false)
        val token = intent.getStringExtra(EXTRA_TOKEN) ?: return
        val baseUrl = intent.getStringExtra(EXTRA_BASE_URL) ?: return
        val conversationName = intent.getStringExtra(EXTRA_CONVERSATION_NAME) ?: ""

        // Envoyer le message en arrière-plan
        Thread {
            try {
                val endpoint = if (isGroup) {
                    "$baseUrl/v1/message_groups.php?path=$groupId/messages"
                } else {
                    "$baseUrl/v1/messages.php"
                }

                val url = java.net.URL(endpoint)
                val connection = url.openConnection() as java.net.HttpURLConnection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/json")
                connection.setRequestProperty("Authorization", "Bearer $token")
                connection.doOutput = true
                connection.connectTimeout = 10000
                connection.readTimeout = 10000

                val body = if (isGroup) {
                    // Groupe : POST $baseUrl/v1/message_groups.php?path=$groupId/messages avec {content}
                    """{"content":${org.json.JSONObject.quote(replyText)}}"""
                } else {
                    // Privé : POST $baseUrl/v1/messages.php avec {recipient_id, content}
                    """{"recipient_id":$senderId,"content":${org.json.JSONObject.quote(replyText)}}"""
                }

                val outputStream = connection.outputStream
                outputStream.write(body.toByteArray(Charsets.UTF_8))
                outputStream.flush()
                outputStream.close()

                val responseCode = connection.responseCode
                connection.disconnect()

                if (responseCode == 200 || responseCode == 201) {
                    // Succès : mettre à jour la notification pour montrer le message envoyé
                    showRepliedNotification(context, notificationId, conversationName, replyText)
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }.start()

        // Annuler la notification originale immédiatement (UX fluide)
        if (notificationId != -1) {
            NotificationManagerCompat.from(context).cancel(notificationId)
        }
    }

    private fun showRepliedNotification(
        context: Context,
        notificationId: Int,
        conversationName: String,
        replyText: String
    ) {
        // Afficher une notification "Message envoyé" temporaire
        try {
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                androidx.core.app.NotificationCompat.Builder(context, "messages")
            } else {
                @Suppress("DEPRECATION")
                androidx.core.app.NotificationCompat.Builder(context)
            }

            builder
                .setSmallIcon(R.drawable.ic_stat_militant)
                .setContentTitle(conversationName)
                .setContentText("Message envoyé : $replyText")
                .setAutoCancel(true)
                .setPriority(androidx.core.app.NotificationCompat.PRIORITY_LOW)

            NotificationManagerCompat.from(context).notify(notificationId + 10000, builder.build())
        } catch (e: SecurityException) {
            e.printStackTrace()
        }
    }
}
