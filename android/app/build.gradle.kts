import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Lire le dart-define FDROID_BUILD injecté par `flutter build/run --dart-define=FDROID_BUILD=true`
// pour différencier l'applicationId des deux variantes (coexistence sur le même appareil de test).
fun dartDefine(name: String, default: String = ""): String {
    val encoded = project.findProperty("dart-defines") as String? ?: return default
    return encoded.split(",")
        .mapNotNull { runCatching { String(Base64.getDecoder().decode(it)) }.getOrNull() }
        .firstOrNull { it.startsWith("$name=") }
        ?.removePrefix("$name=")
        ?: default
}
val isFdroidBuild = dartDefine("FDROID_BUILD") == "true"
val appIdSuffix   = dartDefine("APP_ID_SUFFIX", "")

// Le plugin google-services (Firebase/OneSignal) n'est utile que pour la version Play Store.
// La version F-Droid utilise uniquement ntfy et n'a pas de firebase.
if (!isFdroidBuild) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.militant.militant_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.0.13004108"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // applicationId varie selon la variante :
        //   Play Store → com.militant.militant_flutter
        //   F-Droid    → com.militant.militant_flutter.fdroid
        applicationId = "com.militant.militant_flutter$appIdSuffix"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // La variante F-Droid ne compile pas l'extension Android OneSignal.
    // Le SDK Flutter est remplacé par un adaptateur Dart sans dépendance native
    // dans scripts/build_fdroid.sh.
    if (isFdroidBuild) {
        sourceSets.getByName("main").java.exclude(
            "**/OneSignalCallNotificationServiceExtension.kt",
        )
    }
}

configurations.all {
    resolutionStrategy {
        force("androidx.datastore:datastore-core:1.1.3")
        force("androidx.datastore:datastore-core-android:1.1.3")
        force("androidx.datastore:datastore-preferences:1.1.3")
        force("androidx.datastore:datastore-preferences-core:1.1.3")
        force("androidx.datastore:datastore-preferences-android:1.1.3")
    }
}

// Kotlin's source set is distinct from Android's Java source set. Exclude the
// OneSignal notification extension explicitly for the F-Droid build.
if (isFdroidBuild) {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        exclude("**/OneSignalCallNotificationServiceExtension.kt")
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Trusted Web Activity support
    implementation("com.google.androidbrowserhelper:androidbrowserhelper:2.5.0")

    if (!isFdroidBuild) {
        // Expose OneSignal native notification extension interfaces to the app module (Play Store only)
        implementation("com.onesignal:core:5.6.1")
    }
    
    // Core activity components for Edge-to-Edge (Android 15+)
    implementation("androidx.activity:activity-ktx:1.10.0")

    // Image loading with downsampling and caching (recommended by Google Play)
    implementation("io.coil-kt:coil:2.7.0")

    // WebSocket client for persistent ntfy background service
    implementation("com.squareup.okhttp3:okhttp:4.12.0")


    // Force Datastore 1.1.3 with 16 KB page size alignment fix for libdatastore_shared_counter.so
    constraints {
        implementation("androidx.datastore:datastore-core:1.1.3") {
            because("16 KB page size alignment fix for libdatastore_shared_counter.so")
        }
        implementation("androidx.datastore:datastore-core-android:1.1.3") {
            because("16 KB page size alignment fix for libdatastore_shared_counter.so")
        }
        implementation("androidx.datastore:datastore-preferences:1.1.3") {
            because("16 KB page size alignment fix for libdatastore_shared_counter.so")
        }
        implementation("androidx.datastore:datastore-preferences-android:1.1.3") {
            because("16 KB page size alignment fix for libdatastore_shared_counter.so")
        }
    }
}
