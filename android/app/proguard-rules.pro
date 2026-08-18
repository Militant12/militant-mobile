# Flutter Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Flutter methods
-dontwarn io.flutter.embedding.**

# Keep OneSignal
-keep class com.onesignal.** { *; }

# Keep LiveKit / WebRTC
-keep class io.livekit.** { *; }
-keep class org.webrtc.** { *; }
