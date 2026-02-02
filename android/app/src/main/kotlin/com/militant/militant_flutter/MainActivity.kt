package com.militant.militant_flutter

import android.content.Intent
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.militant.militant_flutter/twa"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
    }

    private fun launchTrustedWebActivity(url: String) {
        val builder = CustomTabsIntent.Builder()
        val customTabsIntent = builder.build()
        customTabsIntent.intent.data = Uri.parse(url)
        customTabsIntent.intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        customTabsIntent.launchUrl(this, Uri.parse(url))
    }
}
