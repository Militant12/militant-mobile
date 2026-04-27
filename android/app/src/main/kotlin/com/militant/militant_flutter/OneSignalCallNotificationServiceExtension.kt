package com.militant.militant_flutter

import com.onesignal.notifications.INotificationReceivedEvent
import com.onesignal.notifications.INotificationServiceExtension

class OneSignalCallNotificationServiceExtension : INotificationServiceExtension {

    override fun onNotificationReceived(event: INotificationReceivedEvent) {
        val notification = event.notification
        val additionalData = notification.additionalData ?: return
        val type = additionalData.optString("type")
        val callId = additionalData.optString("call_id")

        if (type != "call" || callId.isBlank()) {
            return
        }

        event.preventDefault()

        val body = notification.body?.trim().orEmpty()
        val title = notification.title?.trim().orEmpty()
        val callerName = additionalData.optString("caller_name")
            .takeUnless { it.isBlank() }
            ?: additionalData.optString("callerName").takeUnless { it.isBlank() }
            ?: extractCallerNameFromBody(body)
            ?: title.takeUnless { it.isBlank() || it == "📞 Appel entrant" || it == "Appel entrant" }
            ?: "Appel entrant"

        val callType = additionalData.optString("call_type").takeUnless { it.isBlank() }
            ?: if (
                body.contains("vidéo", ignoreCase = true) ||
                body.contains("video", ignoreCase = true)
            ) {
                "video"
            } else {
                "audio"
            }
        val isVideo = additionalData.optString("is_video") == "true" || callType == "video"
        val isGroupCall =
            additionalData.optString("is_group_call") == "true" ||
                additionalData.optString("is_group_call") == "1" ||
                additionalData.optString("group_id").isNotBlank()

        val payload = hashMapOf<String, Any?>()
        payload["type"] = type
        payload["call_id"] = callId
        payload["caller_id"] = firstNonBlank(
            additionalData,
            "caller_id",
            "callerId",
            "user_id",
            "userId"
        )
        payload["caller_name"] = callerName
        payload["caller_avatar"] = firstNonBlank(
            additionalData,
            "caller_avatar",
            "callerAvatar",
            "avatar",
            "photo",
            "picture",
            "profile_picture",
            "profilePicture",
            "user_avatar",
            "userAvatar"
        )
        payload["call_type"] = callType
        payload["is_video"] = isVideo
        payload["offer_sdp"] = additionalData.optString("offer_sdp").takeUnless { it.isBlank() }
        payload["is_group_call"] = isGroupCall
        payload["group_id"] = additionalData.optString("group_id").takeUnless { it.isBlank() }
        payload["group_name"] = additionalData.optString("group_name").takeUnless { it.isBlank() }

        IncomingCallNotificationHelper.showIncomingCallNotification(
            event.context,
            payload
        )
    }

    private fun extractCallerNameFromBody(body: String): String? {
        if (body.isBlank()) return null
        val suffix = " vous appelle"
        return if (body.endsWith(suffix, ignoreCase = true)) {
            body.dropLast(suffix.length).trim().takeIf { it.isNotBlank() }
        } else {
            null
        }
    }

    private fun firstNonBlank(
        data: org.json.JSONObject,
        vararg keys: String
    ): String? {
        for (key in keys) {
            val value = data.optString(key).trim()
            if (value.isNotEmpty()) {
                return value
            }
        }
        return null
    }
}
