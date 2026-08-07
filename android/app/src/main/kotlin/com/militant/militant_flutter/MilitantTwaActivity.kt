package com.militant.militant_flutter

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.google.androidbrowserhelper.trusted.LauncherActivity

/**
 * Custom LauncherActivity for Trusted Web Activity (TWA) support.
 * Configured for Android 15+ (API 35+) Edge-to-Edge display compatibility.
 */
class MilitantTwaActivity : LauncherActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}


