plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

import java.util.Properties
import java.io.FileInputStream

// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.militant.militant_flutter"
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
        }
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

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // Trusted Web Activity support
    implementation("com.google.androidbrowserhelper:androidbrowserhelper:2.5.0")

    // Expose OneSignal native notification extension interfaces to the app module
    implementation("com.onesignal:core:5.6.1")
    
    // Core activity components for Edge-to-Edge (Android 15+)
    implementation("androidx.activity:activity-ktx:1.10.0")


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

