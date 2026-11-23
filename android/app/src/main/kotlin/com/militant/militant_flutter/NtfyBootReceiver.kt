package com.militant.militant_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Redémarre automatiquement le service d'écoute ntfy après redémarrage du téléphone
 * ou mise à jour de l'application si l'utilisateur a activé ntfy.
 */
class NtfyBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            NtfyForegroundService.startFromSavedPrefs(context)
        }
    }
}
