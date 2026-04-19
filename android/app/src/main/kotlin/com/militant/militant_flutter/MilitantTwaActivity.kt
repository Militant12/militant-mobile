package com.militant.militant_flutter

import android.os.Bundle
import androidx.core.view.WindowCompat
import com.google.androidbrowserhelper.trusted.LauncherActivity

/**
 * Custom LauncherActivity for Trusted Web Activity (TWA) support.
 * Updated to support Android 15 Edge-to-Edge requirement and fix deprecation warnings.
 */
class MilitantTwaActivity : LauncherActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enforce edge-to-edge for Android 15+ compatibility
        // This must be called before super.onCreate if we want it to apply to the window
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}
