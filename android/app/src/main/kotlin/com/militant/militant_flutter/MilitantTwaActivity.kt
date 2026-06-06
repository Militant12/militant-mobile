package com.militant.militant_flutter

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import com.google.androidbrowserhelper.trusted.LauncherActivity

/**
 * Custom LauncherActivity for Trusted Web Activity (TWA) support.
 * Updated to support Android 15 Edge-to-Edge requirement and fix deprecation warnings.
 * 
 * Note: This activity extends LauncherActivity from androidbrowserhelper library.
 * The library may internally use deprecated APIs (setStatusBarColor, setNavigationBarColor,
 * setNavigationBarDividerColor), but we override the behavior here to use the modern
 * edge-to-edge approach required by Android 15+ (SDK 35+).
 */
class MilitantTwaActivity : LauncherActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enforce edge-to-edge for Android 15+ compatibility
        // This must be called before super.onCreate to ensure proper window setup
        WindowCompat.setDecorFitsSystemWindows(window, false)
        
        // Configuration optionnelle des barres système pour Android 15+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            // Android 15+ : Les couleurs de barres système sont gérées automatiquement
            // avec l'affichage bord à bord. Cette approche remplace les APIs obsolètes :
            // - window.setStatusBarColor() ❌ (obsolète)
            // - window.setNavigationBarColor() ❌ (obsolète)
            // - window.setNavigationBarDividerColor() ❌ (obsolète)
            val windowInsetsController = WindowCompat.getInsetsController(window, window.decorView)
            windowInsetsController?.apply {
                // Ajuster l'apparence des icônes selon le thème (clair ou foncé)
                isAppearanceLightStatusBars = false
                isAppearanceLightNavigationBars = false
            }
        }
        
        super.onCreate(savedInstanceState)
    }
}
